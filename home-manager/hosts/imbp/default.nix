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

  # TODO: sync calendars

  # TODO: in gmail: set sending mail folder. archive folder. deleted folder

  programs.thunderbird = {

    # TODO: set master password
    # https://support.mozilla.org/en-US/kb/protect-your-thunderbird-passwords-primary-password

    enable = true;
    profiles = {
      default = {
        isDefault = true;


        extraConfig = ''
          user_pref("extensions.installedDistroAddon.{a62ef8ec-5fdc-40c2-873c-223b8a6925cc}", true);
        '';


        # extensions = [
        #   "TbSync@jobisoft.de"       # TbSync
        #   "{a62ef8ec-5fdc-40c2-873c-223b8a6925cc}"  # Provider for Google Calendar
        # ];

        # it looks like extensions must be manually installed

        settings = {
          # Enable OAuth2 for Gmail
          # "mail.server.serverG.hostname" = "imap.gmail.com";
          # "mail.server.serverG.authMethod" = 10;  # 10 = OAuth2
          # "mail.server.serverG.socketType" = 2;   # SSL/TLS

          # TbSync Sync Interval
          "extensions.dav4tbsync.account1.autosyncinterval" = 15;  # Sync every 15 mins

          # calendars
          # Automatically enable this TbSync account
          "extensions.dav4tbsync.account1.enabled" = true;
          "extensions.dav4tbsync.account1.username" = "jfinger@gmail.com";

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

          # this is an attempt to support google's standard oauth2 workflow. it does not seem to work. so for now, when starting thunderbird for the first time do this in the settings UI:
          #   find the server settings for gmail and set the "Authentication method" to "Oauth2"

          "mail.server.serverG.hostname" = "imap.gmail.com"; # IMAP server
          "mail.server.serverG.type" = "imap";
          "mail.server.serverG.authMethod" = 10; # 10 = OAuth2
          "mail.server.serverG.socketType" = 3; # SSL/TLS
          "mail.server.serverG.is_gmail" = true;

          # "mail.server.serverG.oauth2.issuer" = "accounts.google.com";
          # "mail.server.serverG.oauth2.scope" = "https://mail.google.com";

          # SMTP Settings
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

  # accounts.calendar = {
  #   accounts = {
  #     "jfingr@g" = {
  #       primary = true;
  #       # type = "google";
  #       userName = "jfinger@gmail.com";
  #       # thunderbird = {
  #       #   enable = true;
  #       #   settings = {
  #       #     "calendar.google.calPrefs.syncEvents" = true;
  #       #     "calendar.google.calPrefs.syncTasks" = true;
  #       #     "calendar.google.calPrefs.syncInvitations" = true;
  #       #   };
  #       # };
  #     };
  #   };
  # };

  accounts.email = {

    # NOTE: passwords are entered and stored in thunderbird when it starts

    # TODO: maybe use sops just to protect the name/addresses here

    accounts = {
      "jono@dgt" = {
        primary = true;
        address = "jono@dgt.is";
        userName = "jono@dgt.is";
        realName = "Jono";
        imap.host = "gemini.sslcatacombnetworking.com";
        smtp.host = "gemini.sslcatacombnetworking.com";
        thunderbird.enable = true;
      };

      "jono@lmi" = {
        address = "jono@lmi.net";
        userName = "jono@lmi.net";
        realName = "Jono";
        imap.host = "mail.lmi.net";
        smtp.host = "mail.lmi.net";
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
        # thunderbird.enable = true;
        thunderbird = {
          enable = true;
          settings = id:
            {
              # "mail.server.server_${id}.authMethod" = 10;
              # "calendar.google.calPrefs.${id}.syncEvents" = true;
              # "calendar.google.calPrefs.${id}.syncTasks" = true;
              # "calendar.google.calPrefs.${id}.syncInvitations" = true;
            };
        };
      };

      "jono.finger@populus" = {
        flavor = "gmail.com";
        address = "jono.finger@populus.ai";
        userName = "jono.finger@populus.ai";
        realName = "Jono";
        thunderbird = {
          enable = true;
          settings = id:
            {
              # "mail.server.serverG.check_new_mail" = false;
            };
        };
      };

      # TODO: maybe add jono@fnb, jjwf16

    };
  };

  home.packages = with pkgs-unstable;
    [
      just

      #         helix
    ] ++ (with pkgs;
      [

        #         librewolf

      ]);

  #       services.flatpak = {
  #         packages = [
  #           "com.github.tchx84.Flatseal"
  #         ];
  #       };

  imports = [

    inputs.nix-flatpak.homeManagerModules.nix-flatpak

    ../../modules/common-nixos.nix
    ../../modules/linux-desktop.nix

  ];

}
