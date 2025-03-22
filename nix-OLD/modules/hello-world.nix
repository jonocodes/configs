
# this is a demo module I created to learn to write tests

# eval cli to see the output:  nix eval --impure --expr '(import ./nix/modules/hello-world.nix { config = { helloMessage = "world"; }; lib = {}; }).config.result'

{ config, lib, ... }:
{
  options.helloMessage = lib.mkOption {
    type = lib.types.str;
    default = "world";  # Default value if none is provided
    description = "The name to say hello to.";
  };

  config.result = "Hello ${config.helloMessage}";
}

