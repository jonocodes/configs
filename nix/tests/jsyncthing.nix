
# run this test like so :  nix eval --impure '#nixosConfigurations.test.config.services.syncthing.settings'

{ pkgs, lib, nixpkgs, system, ... }:

{
  imports = [
    ../modules/jsyncthing.nix
  ];

  config = {
    services.jsyncthing = {
      enable = true;
      folderDevices = {
        testFolder = {
          devices = [ "zeeba" ];
          path = "/home/jono/sync/testFolder";
          versioned = true;
        };
      };
    };
  };
}
