final: prev:
{
  f1tenth-gym = final.callPackage ././f1tenth_gym.nix {};
  f1tenth-gym-ros = final.callPackage ././package.nix {};
}
