{ pkgs, pkgs-unstable, inputs, nix-flatpak, ... }:
let

  syncthingIgnores = builtins.readFile ../../files/syncthingIgnores.txt;

in {

  programs.fish.enable = true;

  home.file = {
    "sync/common/.stignore".text = syncthingIgnores;
    "sync/configs/.stignore".text = syncthingIgnores;
    "sync/more/.stignore".text = syncthingIgnores;
    "sync/savr_data/.stignore".text = syncthingIgnores;
  };

  # may need to wait until 25.05

  # failing at warning: failed to load external entity "/home/jono/.local/state/syncthing/config.xml"
  /* services.syncthing = {
         enable = true;
     #     user = "jono";
     #     dataDir = "/home/jono/sync2";
     #     configDir = "/home/jono/.config/syncthing2";

         # only in master, not home manager 24.11
     #    guiAddress = "0.0.0.0:8888";  # Custom port 8888

     #     tray.enable  = true;

         settings = {

           extraOptions = [
             "--data=/home/jono/sync2"
             "--config=/home/jono/.config/syncthing2"
           ];

           gui = {
             tls = false;
             theme = "default";
           };
           options = {
             listenAddresses = [ "tcp://0.0.0.0:22001" "quic://0.0.0.0:22001" ];
           };
     #       devices = {
     #         "device1" = {
     #           id = "DEVICE-ID-GOES-HERE";
     #           addresses = [ "dynamic" ];
     #         };
     #       };
           folders = {
             "downl" = {
               path = "/home/jono/Downloads";
     #           devices = [ "device1" ];
             };
           };
         };
       };
  */

  # TODO: in gmail: set sending mail folder. archive folder. deleted folder
  #   looks like gmail sent and trash is working fine with no touch

  programs.thunderbird = {

    # TODO: set master password
    # https://support.mozilla.org/en-US/kb/protect-your-thunderbird-passwords-primary-password

    enable = true;
    profiles = {
      default = {
        isDefault = true;

        # it looks like extensions must be manually installed. so I need to install Google Calendar Provider

        settings = {

          # Sync only specific calendars by their resource names
          "extensions.dav4tbsync.account1.syncCalendars" = true;

          # Specify which calendars to sync (Gmail calendar resource URLs)
          "extensions.dav4tbsync.account1.syncedCalendars" = [
            # "user@gmail.com#WorkCalendarID"
            "jfinger@gmail.com"
          ];

          # UI settings
          "mail.server.default.check_new_mail" = true;
          "mail.server.default.login_at_startup" = true;

          "mailnews.mark_message_read.auto" = false;
          "mailnews.mark_message_read.delay" = false;
          "mail.folder_views.unifiedFolders" = true;

          "mailnews.default_sort_type" = 18;
          "mailnews.default_sort_order" = 1;

          #   attempts at getting 'delete' on nix mac to work
          # "mail.deleteByBackspace" = true;
          # "mail.delete_matches_backspace" = true;
          # "mail.keyboard.delete_key.on_mac" = 1;

          # this is an attempt to support google's standard oauth2 workflow. it does not seem to work. so for now, when starting thunderbird for the first time do this in the settings UI:
          #   find the server settings for gmail and set the "Authentication method" to "Oauth2"

          "mail.server.serverG.hostname" = "imap.gmail.com"; # IMAP server
          "mail.server.serverG.name" = "GMail"; # IMAP server
          "mail.server.serverG.type" = "imap";
          "mail.server.serverG.authMethod" = 10; # 10 = OAuth2
          "mail.server.serverG.socketType" = 3; # SSL/TLS
          "mail.server.serverG.is_gmail" = true;

          # "mail.account.account1.smtp.oauth2" = true;

          # outgoing mail does not set Oauth2. I can set it at run time and send email, but it gets unset after restart.

          # SMTP Settings
          "mail.smtpserver.smtpG.description" = "generic gmail smtp";
          "mail.smtpserver.smtpG.hostname" = "smtp.gmail.com";
          "mail.smtpserver.smtpG.authMethod" = 10; # OAuth2
          "mail.smtpserver.smtpG.socketType" = 2; # SSL/TLS

          # Tell Thunderbird to use OAuth2 by default
          # "mail.smtpserver.default.authMethod" = 10;

          # Automatically add accounts to Thunderbird's password manager
          # "signon.rememberSignons" = true;

        };
      };
    };
  };

  accounts.email = {

    # NOTE: passwords are entered and stored in thunderbird when it starts

    # TODO: maybe use sops just to protect the name/addresses here

    accounts = {
      "jono@dgt" = {
        primary = true;
        address = "jono@dgt.is";
        userName = "jono@dgt.is";
        realName = "Jono";
        imap = {
          host = "gemini.sslcatacombnetworking.com";
          port = 993;
        };
        smtp = {
          host = "gemini.sslcatacombnetworking.com";
          port = 465;
        };
        thunderbird.enable = true;
      };

      "lmi" = {
        address = "jono@lmi.net";
        userName = "jono@lmi.net";
        realName = "Jono";
        imap = {
          host = "mail.lmi.net";
          port = 993;
        };
        smtp = {
          host = "mail.lmi.net";
          port = 465;
        };
        thunderbird.enable = true;
      };

      "jonojuggles@g" = {
        address = "jonojuggles@gmail.com";
        userName = "jonojuggles@gmail.com";
        realName = "Jono";
        flavor = "gmail.com";
        thunderbird.enable = true;
      };

      "jfinger@g" = {
        address = "jfinger@gmail.com";
        userName = "jfinger@gmail.com";
        realName = "Jono";
        flavor = "gmail.com";
        thunderbird.enable = true;
      };

      "populus" = {
        flavor = "gmail.com";
        address = "jono.finger@populus.ai";
        userName = "jono.finger@populus.ai";
        realName = "Jono";
        thunderbird.enable = true;
      };

      # TODO: maybe add jono@fnb, jjwf16, bonj

    };
  };

  home.packages = with pkgs-unstable;
    [
      just
      trayscale

    ] ++ (with pkgs;
      [

      ]);

  #       services.flatpak = {
  #         packages = [
  #           "com.github.tchx84.Flatseal"
  #         ];
  #       };

  imports = [

    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ../../modules/common.nix
    ../../modules/linux-desktop.nix

    #     (home-manager-master + "/modules/services/syncthing.nix")

  ];

}
