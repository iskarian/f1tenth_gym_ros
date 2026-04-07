ARG FROM_IMAGE=ros:humble
ARG OVERLAY_WS=/opt/ros/f1tenth_overlay
# TODO make headless fixes optional
# ARG HEADLESS=-headless

# === CACHE STAGE ===
FROM $FROM_IMAGE AS cacher
ARG OVERLAY_WS

# Keep the apt cache, as we're actually using it via cache mounts
RUN rosdep update --rosdistro $ROS_DISTRO && \
    cat <<EOF > /etc/apt/apt.conf.d/docker-clean && apt-get update && apt-get install -y python3-pip
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

# Copy source to image
WORKDIR /tmp/src/f1tenth_gym_ros
COPY ./ ./

# Patch f1tenth_gym_ros to remove dependency on rviz2 since this is headless
RUN sed --in-place -e '/rviz2/d' package.xml

# Patch f1tenth_gym to remove graphical dependencies since this is headless
# opencv-python -> opencv-python-headless
# remove pyqt6, pyqtgraph
# remove PyOpenGL, PyOpenGL-accelerate
RUN sed --in-place \
    -e 's/opencv-python/opencv-python-headless/' \
    -e '/pyqt/d' \
    -e '/pyopengl/Id' \
    f1tenth_gym/pyproject.toml

# Derive build/exec dependencies
RUN bash -e <<'EOF'
declare -A types=(
  [exec]="--dependency-types=exec"
  [build]="")
for type in "${!types[@]}"; do
  rosdep install -y \
    --from-paths . \
    --ignore-src \
    --reinstall \
    --simulate \
    ${types[$type]} \
    | grep 'apt-get install' \
    | awk '{gsub(/'\''/,"",$4); print $4}' \
    | sort -u > /tmp/${type}_debs.txt
done
EOF

# === BUILD STAGE ===
FROM $FROM_IMAGE AS builder
ARG OVERLAY_WS

# Install build dependencies
COPY --from=cacher /tmp/build_debs.txt /tmp/build_debs.txt
RUN --mount=type=cache,target=/etc/apt/apt.conf.d,from=cacher,source=/etc/apt/apt.conf.d \
    --mount=type=cache,target=/var/lib/apt/lists,from=cacher,source=/var/lib/apt/lists \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    < /tmp/build_debs.txt xargs apt-get install -y python3-pip python3-venv

# Build overlay source
WORKDIR /tmp/src
COPY --from=cacher /tmp/src .

# Build f1tenth_gym and install to a new venv in the overlay
# Note - may need to install `uv-build` and `build` on humble
# Note - it seems that colcon-common-extensions is required for the venv to properly run colcon
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m venv $OVERLAY_WS --system-site-packages && \
    . $OVERLAY_WS/bin/activate && \
    pip install -U colcon-common-extensions f1tenth_gym_ros/f1tenth_gym 

# Build f1tenth_gym_ros and install to overlay
RUN . $OVERLAY_WS/bin/activate && \
    python3 -m colcon build \
      --merge-install \
      --install-base $OVERLAY_WS \
      --packages-select \
        f1tenth_gym_ros \
      --mixin release

# === RUNNER STAGE===
FROM $FROM_IMAGE-ros-core AS runner
ARG OVERLAY_WS

# Install exec dependencies
COPY --from=cacher /tmp/exec_debs.txt /tmp/exec_debs.txt
RUN --mount=type=cache,target=/etc/apt/apt.conf.d,from=cacher,source=/etc/apt/apt.conf.d \
    --mount=type=cache,target=/var/lib/apt/lists,from=cacher,source=/var/lib/apt/lists \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    < /tmp/exec_debs.txt xargs apt-get install -y  

# Setup overlay entrypoint
COPY --from=builder $OVERLAY_WS $OVERLAY_WS
ENV OVERLAY_WS=$OVERLAY_WS
RUN sed --in-place --expression \
     '$isource $OVERLAY_WS/bin/activate && source "$OVERLAY_WS/setup.bash" --' \
      /ros_entrypoint.sh

# Set launch file as default command
# Note - there is no simple way to open foxglove automatically since this is in a Docker container
# and the built-in functionality uses `xdg-open`. However, we know which port it will run on, so
# we should be able to invoke `xdg-open` on the host as part of our tooling.
# TODO set launch arguments via environment variables
# TODO modify launch file to take path to sim.yaml
CMD ["ros2", "launch", "f1tenth_gym_ros", "gym_bridge_launch.py", "open_foxglove:=false"]

# The default foxglove port
EXPOSE 8765

# Set a healthcheck so dependent services can wait on us to start.
# Using grep here is absolutely a cludge; find a way to query via ROS or the foxglove bridge?
HEALTHCHECK --interval=1s --timeout=1s --start-period=30s \
  CMD grep -r "Running in asynchronous mode." "/root/.ros/log"

