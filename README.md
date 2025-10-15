
# Jono's configs

These are configs for various applications, shared development environments, and my nix systems.

I use git for a historical record of changes and github for sharing. It is not used to sync to different machines. For that I use syncthing.

I generally manage about a dozen systems in x86 and arm. Mostly but not all Linux.


# Bootstrapping new hosts

* Connect node to tailscale
* Connect syncthing to get configs
* Setup nixos/apps. see [nixos/Readme.md](nixos/README.md)


# Updating hosts

On all machines you can use the command 'u' which will pull down all the updates for whenever system you are using.


# General system setup

## flatpak

    various declarative approaches were tried. none worked well. I started making my own (see flatpak/). for now I stick to using the flatpak command line to manage apps.

    If an app can be installed here use this before going through nix methods.

## nix home-manager

    this is where dotfiles and local apps are installed. favor doing as much config here as possible

## nixos

    this is for host configs. mostly focused on hardware and top services. keep this lean if possible.

## syncthing

    this is core to all systems. there are several shared folders used across machines. this includes the configs themselves. also passwords and notes.


# Some app specifics

## firefox

    firefox sync server is used for settings, bookmarks, extensions. not passwords

## thunderbird

    the thunderbird setup is complex. some day thunderbird will have its own setting sync server. until then I do it in nix.

    https://blog.thunderbird.net/2023/07/an-update-on-thunderbird-sync/
    https://bugzilla.mozilla.org/show_bug.cgi?id=446444

## vscode

    using vscode's own sync mechanism via github
    
