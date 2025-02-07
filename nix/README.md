
# TODO

write how to bootstrap a new system


# to bootstrap a new system

setup syncthing to get config share in /etc/nixos/configuration.nix

```nix
  services = {
    syncthing = {

      enable = true;
      user = "jono";
      dataDir = "/home/jono/sync";
      configDir = "/home/jono/.config/syncthing";

      overrideDevices = true;
      overrideFolders = true;

      guiAddress = "0.0.0.0:8384";

      settings = {

        gui = {
          user = "admin";
          password = "temp_password";
        };

        folders = {
          "configs" = {
            path = "/home/jono/sync/configs";
            devices = [ "choco" ];
          };
        };

        devices = {
          "choco" = {
            id =
              "ITAESBW-TIKWVEX-ITJPOWT-PM7LSDA-O23Q2FO-6L5VSY2-3UW5VM6-I6YQAAR";
          };
        };

      };

    };
  };
```


then > sudo nixos-rebuild --upgrade switch

setup syncthing to get the configs into ~/sync/configs/

mkdir ~/sync/configs/nix/hosts/(hostname)/
cp /etc/nixos/* ~/sync/configs/nix/hosts/(hostname)/
cd ~/sync/configs/nix/hosts/
cp default.template.nix (hostname)/default.nix

copy over whatever looks critical from configuration.nix to default.nix. it should not be much

in default.nix
    replace 'nixhost' with new hostname
    generate a hostid (if using zfs)
        https://search.nixos.org/options?channel=23.11&show=networking.hostId

add new host to the bottom of configs/nix/flake.nix

copy the os-build alias and run it in shell to build the flake
    make sure to use " --experimental-features 'nix-command flakes'" in first calls to 'nix' command

manually run the os-switch alias

now log out and in. your shell should be updated and aliases set

delete configuration.nix since its not being used any more.



# to set up dobro

this is no longer the case

ln -s $HOME/sync/configs/nix/hosts/dobro/flake.nix /etc/nixos/flake.nix

ln -s $HOME/sync/configs/nix/hosts/dobro/flake.lock /etc/nixos/flake.lock

ln -s $HOME/sync/configs/nix/modules /etc/nixos/modules
