{ pkgs, pkgs-unstable, inputs, modulesPath, ... }:
let

  inherit (inputs) self;
in {
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];
  hardware.sane.enable = true;
  hardware.graphics.enable = true;

  programs.nix-ld.enable = true; # for remote vscode. dont know if this works yet

  services.xserver = { enable = true; };

  xdg.portal.enable = true;

  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ];

  programs.adb.enable = true;
  users.users.jono.extraGroups = [ "adbusers" ];
  # android_sdk.accept_license = true;

  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; # used by nixd

  services.flatpak = {

    # NOTE: there is no feedback/logging of these, so you can watch flatpak progress like so: watch systemctl status flatpak-managed-install.service

    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "daily";
    };
    packages = [];
  };

  # add support for manually running downloaded AppImages
  #  this can probably be updated to something here: https://mynixos.com/search?q=appimage
  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = "${pkgs.appimage-run}/bin/appimage-run";
    recognitionType = "magic";
    offset = 0;
    mask = "\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\xff\\xff\\xff";
    magicOrExtension = "\\x7fELF....AI\\x02";
  };

}
