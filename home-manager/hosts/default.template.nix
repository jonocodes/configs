{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let
  inherit (inputs) self;

in {

#   home-manager.users.jono = {config, ...}: {
#     # The home.stateVersion option does not have a default and must be set
#     home.stateVersion = "24.11";
# 
#     home.file = {
#       "sync/configs/.stignore".text = syncthingIgnores;
#     };
# 
#     programs.ssh.enable = true;
# 
# 
#     programs.fish = {
#       enable = true;
# 
#       # interactiveShellInit = ''
#       #   set fish_greeting # Disable greeting
#       # '';
# 
#       shellAbbrs = {
#         # cat = "bat";
#         # p = "ping google.com"; # "ping nixos.org";
#         # "..." = "cd ../..";
# 
#         u = "sudo date && os-update && time os-build && os-switch";
#       };
# 
#       shellAliases = {
# 
#         # update the checksum of the repos
#         os-update = "cd /home/jono/sync/configs/nix && nix flake update && cd -";
# 
#         # list incoming changes, compile, but dont install/switch to them
#         os-build =
#           "nix build --out-link /tmp/result --dry-run /home/jono/sync/configs/nix#nixosConfigurations.$hostname.config.system.build.toplevel && nix build --out-link /tmp/result /home/jono/sync/configs/nix#nixosConfigurations.$hostname.config.system.build.toplevel && nvd diff /run/current-system /tmp/result";
# 
#         # switch brings in flake file changes. as well as the last 'build'
#         os-switch = "sudo nixos-rebuild switch -v --flake /home/jono/sync/configs/nix";
# 
#       };
# 
#     };
# 
#   };

  imports = [
    # ../../modules/common-nixos.nix
  ];

}
