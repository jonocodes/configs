{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.digitus.services.syncthing;

  # TODO: add ignore files

  # TODO: make my own syncthing wrapper so I can programatically manage the syncthing network: https://github.com/Yeshey/nixOS-Config/blob/468f1f63f0efa337370d317901bb92fc421b3033/modules/nixos/mySystem/syncthing.nix#L173

  # NOTE: waiting on ability to do ignore inline: https://github.com/NixOS/nixpkgs/pull/353770

  # Maybe move do a different namespace like 'within' here: https://github.com/AdrielVelazquez/nixos-config/blob/main/modules/services/docker.nix
  # how about the namespace 'digitus'

  # if there are sync issues, they can often be resolved like so> /nix/store/gij0yzbyi9d64rh4f62386fqd3x4nl8g-syncthing-1.28.0/bin/syncthing --reset-database

  syncRoot = "/home/jono/sync";

  deviceMap = {

    dobro = "QDPAOUZ-TN6RRAG-X6AJNTZ-QMXHGC4-RZPBFTG-4VS74JF-3ESV6QN-KMZTOAS";
    # "IVBFEHN-WLC4YLP-QQ66IFS-PKTKVJD-OMFKMXM-R64H5A6-MRLY5CU-TUEYGQJ";

    choco = "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR";

    zeeba = "FHJMBVS-QFCCTVG-XQCQTCB-RTX6I37-B76EXZ7-Y7VSFBZ-YT5QWFK-4XQVGAH";

    orc = "LBHD5BY-O43E3DC-VTLHLMG-ZZJJRFT-A5I3TGD-OINPMXI-C4V7ARX-A2QGCQC";

    # this does not exist any more
    #pop-mac = "N7XVA3T-WPY2XRB-P44F7KS-CEFRIDX-KK6DEYQ-UM2URKO-DVA2G2O-FLO6IAV";

    # intel macbook pro?
    imbp = "FYNDFJD-C5GT4BD-SXKIZEP-ZYQNKK6-TCQ5UXG-XMQBRZ4-LZZGVPU-NOCOSAX";

    nixahi = "QKJPJZ2-H27NL23-63H2CV2-P426R26-UFOFP7Q-HOXPLVH-A6E5J3K-Y4FPMA4";

    # terradot macbook
    jonodot = "CMZWDHI-EZA4GC4-RBICS26-OBO647N-TB2WZXN-IJ5AGV2-SC7G2AF-DSYJ6QB";

    galaxyS23 =
      "GNT4UMD-JUYX45B-ODZXIZL-Q4JBCN5-DR5FEEI-LKLP667-VYEEJLP-GF4UCQO";

  };

  # Function to validate devices and generate settings
  generateSettings = folderDevices:
    let
      allDevices =
        unique (concatMap (folder: folder.devices) (attrValues folderDevices));
      unknownDevices = filter (device: !(deviceMap ? ${device})) allDevices;
    in assert assertMsg (unknownDevices == [ ])
      "Unknown devices: ${toString unknownDevices}"; {

        options = {
          listenAddresses = [ "tcp://0.0.0.0:22008" "quic://0.0.0.0:22008" ];
        };

        gui = {
          user = "admin";

          # NOTE: syncthing config accepts raw or brcypt hashed password

          password =
            "$2a$10$ucKVjnQbOk9E//OmsllITuuDkQKkPBaL0x39Zuuc1b8Kkn2tmkwHm";
        };

        devices = mapAttrs (name: id: { inherit id; })
          (filterAttrs (name: _: elem name allDevices) deviceMap);

        folders = mapAttrs (name: folder:

          {

            # path = folder.path or "${syncRoot}/${name}";
            # path = "/tmp";
            path =
              if (builtins.hasAttr "path" folder && folder.path != null) then
                folder.path
              else
                "${syncRoot}/${name}";

            # path = folder.path or "/home/jono/sync/${name}";
            devices = folder.devices;
            # versioning =
            #   if folder.versioned or false
            #   then {
            #     type = "staggered";
            #     params = {
            #       cleanInterval = "3600";
            #       maxAge = "1";
            #     };
            #   }
            #   else null;
          } // lib.optionalAttrs
          (builtins.hasAttr "versioned" folder && folder.versioned) {
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "1";
              };
            };
          }) folderDevices;
      };

in {

  options.digitus.services.syncthing = {
    enable = mkEnableOption "Syncthing wrapper service";
    folderDevices = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          devices = mkOption {
            type = types.listOf types.str;
            description = "List of devices for this folder";
          };
          path = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Custom path for the folder (optional)";
          };
          versioned = mkOption {
            type = types.nullOr types.bool;
            default = false;
            description = "Enable versioning for this folder";
          };
        };
      });
      default = { };
      example = {
        common = {
          devices = [ "choco" "zeeba" "galaxyS23" ];
          versioned = true;
        };
        more = { devices = [ "choco" "zeeba" ]; };
        camera = {
          path = "/dpool/camera/JonoCameraS23";
          devices = [ "galaxyS23" ];
        };
      };
      description = "Folder configurations with associated devices and options";
    };
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;    # TODO: this should not be hard coded
      user = "jono";
      dataDir = syncRoot;
      configDir = "${syncRoot}/.config/syncthing";
      overrideDevices = true;
      overrideFolders = true;
#       guiAddress = "0.0.0.0:8384";
      guiAddress = "0.0.0.0:8388";

      # putting this on non standard ports while I mess with home manager syncthing
      # options = {
      #   listenAddresses = [ "tcp://0.0.0.0:22008" "quic://0.0.0.0:22008" ];
      # };


      settings = generateSettings cfg.folderDevices;
    };

    # prevent the creation of the default sync folder
    # systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
  };
}
