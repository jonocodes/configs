
# run like: nix eval --impure --file ./nix/tests/hello-world.nix

let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  hello = import ../modules/hello-world.nix ;
in
  assert (hello { lib = pkgs.lib; 
    config = { helloMessage = "foo"; }; }).config.result == "Hello foo";

  assert (hello { lib = pkgs.lib; 
    config = { helloMessage = "bar"; }; }).config.result == "Hello bar";


  "tests passed"
