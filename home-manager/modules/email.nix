{ pkgs, config, lib, system, ... }:

with lib;

let

  # isDarwin = pkgs.currentSystem == "x86_64-darwin" || builtins.currentSystem == "aarch64-darwin";

  makeGmailAccount = address: {
    inherit address;
    userName = address;
    realName = "Jono";
    flavor = "gmail.com";

    # This can be simplified if this gets merged https://github.com/nix-community/home-manager/pull/6579

    thunderbird.enable = true;
    thunderbird.settings = id: {
      "mail.server.server_${id}.authMethod" = 10; # 10 = OAuth2
      "mail.server.server_${id}.socketType" = 3;  # SSL/TLS
      "mail.server.server_${id}.is_gmail" = true; # handle labels, trash, etc
    };
  };

  # thunderbirdConfigPath = if isDarwin then "Library/Thunderbird" else ".thunderbird";


  # thunderbirdConfigPath = ".thunderbird";

  # xulstorePath = "${config.home.homeDirectory}/${thunderbirdConfigPath}/default/xulstore.json";
  # xulstore = builtins.fromJSON (builtins.readFile xulstorePath);
  # hasValue = false; # xulstore.someKey == "jono";
  # updatedXulstore = if hasValue then xulstore else xulstore // { someKey = "jono2"; };
  # updatedJson = builtins.toJSON updatedXulstore;

  # updatedXulstoreFile = pkgs.writeText "xulstore-updated.json" updatedJson;

in {

  # home.activation = {
  #   updateXulstore = lib.hm.dag.entryAfter ["writeBoundary"] ''
  #     cp ${updatedXulstoreFile} ${xulstorePath}-new
  #   '';
  # };


  # never got the 'Recipient' column to keep showing in unified inbox.
  # thunderbird guy said its probably in an .msf file, but I cant find it.
  # I filed a ticket to have it shown by default:
  #   https://bugzilla.mozilla.org/show_bug.cgi?id=1952614


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


      "populus" = makeGmailAccount "jono.finger@populus.ai";

      "jonojugg@g" = makeGmailAccount "jonojuggles@gmail.com";

      "bonjono@g" = makeGmailAccount "bonjono@gmail.com";

      "jfinger@g" = makeGmailAccount "jfinger@gmail.com";


      # "jonojuggles@g" = {
      #   address = "jonojuggles@gmail.com";
      #   userName = "jonojuggles@gmail.com";
      #   realName = "Jono";
      #   flavor = "gmail.com";
      #   thunderbird.enable = true;

      #   # thunderbird.settings = id: {
      #   #   "mail.server.server_${id}.authMethod" = 10; # 10 = OAuth2
      #   #   "mail.server.server_${id}.socketType" = 3; # SSL/TLS
      #   #   "mail.server.server_${id}.is_gmail" = true; # handle labels, trash, etc
      #   # };
      # };


      # TODO: maybe add jono@fnb, jjwf16

    };
  };


  # imports = [

  # ];

}
