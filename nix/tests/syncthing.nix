
# run like: nix eval --impure --file ./nix/tests/syncthing.nix

let
  pkgs = import <nixpkgs> {};
  lib = pkgs.lib;
  syncthing = import ../modules/syncthing.nix;
in
let

  result1 = (syncthing { config = {
    digitus.services.syncthing = {
      enable = true;
      folderDevices = {
        testFolder = {
          devices = [ "zeeba" ];
          versioned = true;
        };
        two = {
          devices = [ "choco" ];
          versioned = false;
          path = "/some/other/path";
        };
      };
    };
  }; lib = lib; pkgs = pkgs; }).config.content.services;
in

  assert result1.syncthing.settings.devices."zeeba".id == "FHJMBVS-QFCCTVG-XQCQTCB-RTX6I37-B76EXZ7-Y7VSFBZ-YT5QWFK-4XQVGAH";

  assert result1.syncthing == {
    enable = true;
    user = "jono";
    dataDir = "/home/jono/sync";
    configDir = "/home/jono/sync/.config/syncthing";

    overrideDevices = true;
    overrideFolders = true;

    guiAddress = "0.0.0.0:8384";

    settings = {

      gui = {
        user = "admin";
        password =  "$2a$10$ucKVjnQbOk9E//OmsllITuuDkQKkPBaL0x39Zuuc1b8Kkn2tmkwHm";
      };

      devices = {
        zeeba = {
          id = "FHJMBVS-QFCCTVG-XQCQTCB-RTX6I37-B76EXZ7-Y7VSFBZ-YT5QWFK-4XQVGAH"; };
        choco = {
          id = "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR"; };
          
        }; 
        folders = { 
          testFolder = { 
            devices = [ "zeeba" ];
            path = "/home/jono/sync/testFolder";
            versioning = {
                type = "staggered";
                params = {
                  cleanInterval = "3600";
                  maxAge = "1";
                };
              };
          };
          two = {
            devices = [ "choco" ];
            path = "/some/other/path";
            # versioning = null;
          };
        };
      };
    };

  "tests passed"
