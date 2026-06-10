{ config, lib, pkgs, pkgs-unstable, inputs, modulesPath, home-manager, ... }:

with lib;

let

  inherit (inputs) self;
in {

  services.podman = {
    enable = true;
  };

  # services.podman above only manages quadlets; it does not run the rootless
  # API socket. Enable podman's shipped user socket so DOCKER_HOST (pointing at
  # %t/podman/podman.sock, i.e. $XDG_RUNTIME_DIR) works for docker-compose and
  # any docker client. Socket-activated: connecting starts podman.service on
  # demand, so only the socket gets an [Install] section.
  systemd.user.sockets.podman = {
    Unit.Description = "Podman API Socket";
    Socket = {
      ListenStream = "%t/podman/podman.sock";
      SocketMode = "0660";
    };
    Install.WantedBy = [ "sockets.target" ];
  };

  systemd.user.services.podman = {
    Unit = {
      Description = "Podman API Service";
      Requires = "podman.socket";
      After = "podman.socket";
      Documentation = "man:podman-system-service(1)";
      StartLimitIntervalSec = 0;
    };
    Service = {
      Delegate = true;
      Type = "exec";
      KillMode = "process";
      Environment = ''LOGGING="--log-level=info"'';
      ExecStart = "${config.services.podman.package}/bin/podman $LOGGING system service";
    };
  };

  # Restart containers with restart-policy=always after a reboot. WantedBy
  # default.target means it runs when the user session starts (i.e. at login).
  # No lingering, so this fires on login rather than at boot - fine for a
  # desktop you always log into. Run compose with `restart: always` to opt in.
  systemd.user.services.podman-restart = {
    Unit = {
      Description = "Podman Start All Containers With Restart Policy Set To Always";
      Documentation = "man:podman-start(1)";
      StartLimitIntervalSec = 0;
      Wants = "network-online.target";
      After = "network-online.target";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = ''LOGGING="--log-level=info"'';
      ExecStart = "${config.services.podman.package}/bin/podman $LOGGING start --all --filter restart-policy=always";
      ExecStop = "${config.services.podman.package}/bin/podman $LOGGING stop --all --filter restart-policy=always";
    };
    Install.WantedBy = [ "default.target" ];
  };

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
      docker-compose
      # podman-compose
    ] ++ (with pkgs; [
     vscode  # TODO: add back
     graphite-cli

     # A real `docker` on PATH (-> podman) so scripts, Makefiles/Justfiles, and
     # anything that execs `docker` directly use podman too. Shell aliases only
     # apply to interactive shells, so they can't cover non-interactive scripts.
     (writeShellScriptBin "docker" ''exec ${podman}/bin/podman "$@"'')
    ]);

  home.shellAliases = {

    # TODO: get this working
    # i-flatpak = "cd ~/sync/configs/flatpak && ./flatpak-compose-linux-amd64 apply -current-state=system";

    u-flatpak = "flatpak update --assumeyes";

    u = "u-home && u-nixos && u-flatpak";

    # `docker` is now a real wrapper binary in home.packages (works in scripts
    # too), so no alias needed here.
  };


  # tell flatpak? user services to start when enabled. needed by home manager
  systemd.user.startServices = "sd-switch";

  # Add nix-profile share to XDG_DATA_DIRS so GNOME can find desktop files
  home.sessionVariables = {
    XDG_DATA_DIRS = "$HOME/.nix-profile/share:$XDG_DATA_DIRS";
    DOCKER_HOST = "unix://\${XDG_RUNTIME_DIR}/podman/podman.sock";
  };

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
