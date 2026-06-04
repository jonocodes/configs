{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

in {

  home.packages = with pkgs-unstable;
    [
		claude-code
    ] ++ (with pkgs; [

      # lzop # for syncoid compression
      mbuffer
    ]);

  programs.fish = {
    shellAbbrs = { 
      show-leases = "sudo fish -c 'cat /var/lib/kea/*'";
      show-static = "jq '.Dhcp4.subnet4[].reservations[]' /etc/kea/dhcp4-server.conf";
    };
  };

  imports = [ 
    ../modules/common.nix
  ];

}
