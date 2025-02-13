let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  inherit (lib) runTests;
in
  runTests {
    testFoo = {
      expr = import ../modules/hello-world.nix { config = { helloMessage = "foo"; }; lib = pkgs.lib; };
      expected = { config.result = "Hello foo"; };
    };

  }
