# To bootstrap a new system

On a fresh system start by copy the syncthing config from default.template.nix into configuration.nix

> sudo nixos-rebuild --upgrade switch

This should bring down the config share via syncthing.


Now you can create a new host in the config and switch to the flake setup.


> mkdir ~/sync/configs/nix/hosts/(hostname)/
> cp /etc/nixos/* ~/sync/configs/nix/hosts/(hostname)/
> cd ~/sync/configs/nix/hosts/
> cp default.template.nix (hostname)/default.nix

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

