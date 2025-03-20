{ lib, pkgs, pkgs-unstable, inputs, modulesPath, home-manager, ... }:

with lib;

let

  inherit (inputs) self;
in {

  programs.firefox = {
    # not using flatpak since keepass integration does not work there
    enable = true;

    # firefox sync takes care of the bookmarks and extenions

    profiles.default = {
      settings = {
        "browser.toolbars.bookmarks.visibility" = "always";
        "browser.startup.page" = 3;  # preserves previously opened tabs
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      };
      userChrome = ''
        // #TabsToolbar { visibility: collapse !important; }

        #tabbrowser-tabs {
          visibility: collapse !important;
        }

      '';
    };

    # usefull for google voice, or asahi since it does not have builds of zoom or slack
    nativeMessagingHosts = [ pkgs.firefoxpwa ];
  };


  home.packages = with pkgs-unstable;
    [
    ] ++ (with pkgs; [
      vscode  # needed for dev containers
    ]);


  programs.fish = {
    shellAliases = {

      # TODO: get this working
      # i-flatpak = "cd ~/sync/configs/flatpak && ./flatpak-compose-linux-amd64 apply -current-state=system";

      u-flatpak = "flatpak update --assumeyes";

      u = "i-nixos --update && i-home --update && u-flatpak";
    };
  };


  # tell flatpak? user services to start when enabled. needed by home manager
  systemd.user.startServices = "sd-switch";

  # This may actually not be used as the global service may handle it??
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
