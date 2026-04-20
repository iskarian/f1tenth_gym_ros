{
  lib,
  # buildPythonPackage,
  fetchFromGitHub,
  python3Packages,
  # uv-build,
  # coverage,
  # gymnasium,
  # numba,
  # numpy,
  # opencv-python,
  # pandas,
  # pillow,
  # pyopengl,
  # pyopengl-accelerate,
  # pyqt6,
  # pyqtgraph,
  # pyyaml,
  # requests,
  # scipy,
}:

python3Packages.buildPythonPackage {
  pname = "f1tenth-gym";
  version = "0-dev-humble-2026-01-31";
  pyproject = true;

  src = ././f1tenth_gym;

  build-system = with python3Packages; [
    uv-build
  ];

  dependencies = with python3Packages; [
    coverage
    gymnasium
    numba
    numpy
    opencv-python
    pandas
    pillow
    pyopengl
    pyopengl-accelerate
    pyqt6
    pyqtgraph
    pyyaml
    requests
    scipy
    marshmallow-dataclass
  ];
  
  pythonImportsCheck = [
    "f1tenth_gym"
  ];

  # TODO try using pythonRelaxDeps again
  patches = [ ./0002-relax-deps.patch ];
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "uv_build>=0.9.26,<0.10.0" "uv-build" \
      --replace-fail "module-name = [\"f1tenth_gym\"]" "module-name = \"f1tenth_gym\""
  '';

  # pythonRelaxDeps = true;
  #   "gymnasium"
  #   # "pyopengl"
  #   # "pyopengl-accelerate"
  #   # "yamldataclassconfig"
  #   "pandas"
  # ];

  meta = {
    description = "This is the repository of the F1TENTH Gym environment";
    homepage = "https://github.com/f1tenth/f1tenth_gym";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
