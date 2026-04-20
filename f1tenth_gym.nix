{
  lib,
  python3Packages,
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

  # Basically all tests require web access and so fail
  # nativeCheckInputs = with python3Packages; [ pytestCheckHook ];
  
  pythonImportsCheck = [
    "f1tenth_gym"
  ];

  # Some dependencies need to be relaxed since Nix doesn't pin versions
  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail "uv_build>=0.9.26,<0.10.0" "uv-build" \
      --replace-fail "module-name = [\"f1tenth_gym\"]" "module-name = \"f1tenth_gym\""
  '';

  pythonRelaxDeps = [
    "gymnasium"
  ];

  meta = {
    description = "This is the repository of the F1TENTH Gym environment";
    homepage = "https://github.com/f1tenth/f1tenth_gym";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
  };
}
