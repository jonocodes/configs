{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let inherit (inputs) self;
in
{
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  services.udev.packages = with pkgs; [ gnome-settings-daemon ];

  # favor apps to not use root for secrurity
  # requires a logout of gnome after an install to show the launcher?
  # home-manager.users.jono.home.packages = with pkgs-unstable; [

  #   aisleriot # solitare

  # ] ++ (with pkgs; [

  #   gnome-tweaks
  #   transmission_3-gtk
  #   gnome-screenshot

  # ]);


  #  I dont think this works as expected
  # environment.gnome.excludePackages = (with pkgs; [
  #   gnome-photos
  #   gnome-tour
  # ]) ++ (with pkgs.gnome; [
  #   tali # poker game
  #   iagno # go game
  #   hitori # sudoku game
  #   atomix # puzzle game


  # ]);

}
