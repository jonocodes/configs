{ pkgs, pkgs-unstable, inputs, modulesPath, home-manager, ... }:
let inherit (inputs) self;
in
{
  services.xserver.enable = true;

  services = {
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;
  };

  # security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

#   home-manager.users.jono.services.kdeconnect = {
#     enable = true;
#     package = pkgs.kdePackages.kdeconnect-kde;
#     indicator = true;
#   };

  # so gnome and kde can be installed together
  # programs.ssh.askPassword = pkgs.lib.mkForce "${pkgs.ksshaskpass.out}/bin/ksshaskpass";

  # favor apps to not use root for secrurity
  # requires a logout of gnome after an install to show the launcher?
  home-manager.users.jono.home.packages = with pkgs-unstable; [

    kdePackages.kfind
    kdePackages.kcalc

    #    transmission_4-qt

    ocs-url # allows the installing of kde plugins

    baobab # disk usage anylizer since gnome's is better then kdePackages.filelight

    kdePackages.plasma-pa

  ] ++ (with pkgs; [

  ]);

}
