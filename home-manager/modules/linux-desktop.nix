{ pkgs, pkgs-unstable, inputs, modulesPath, home-manager, ... }:
let

  inherit (inputs) self;
in {

  programs.firefox = {
    # not using flatpak since keepass integration does not work there
    enable = true;

    # firefox sync takes care of the bootmarks and extenions

    profiles."default" = {
      settings = {
        "browser.toolbars.bookmarks.visibility" = "always";
        "browser.startup.page" = 3;  # preserves previously opened tabs
      };
    };
  };


  home.packages = with pkgs-unstable;
    [
      telegram-desktop
      # # vscodium
      vscode # needed for dev containers

      librewolf

  ] ++ (with pkgs; [

    # # TODO: move to flatpak?
    # firefox-bin

  ]);

  # tell flatpak? user services to start when enabled. needed by home manager
  systemd.user.startServices = "sd-switch";

  services.flatpak = {

    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "daily";
    };
    packages = [

    ];
  };

}
