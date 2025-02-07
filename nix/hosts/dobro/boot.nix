{ config, lib, pkgs, ... }:

let
  cfgBoot = config.zfs-root.boot;
  inherit (lib) mkIf types mkDefault mkOption mkMerge strings;
  inherit (builtins) head toString map tail;
in {
  options.zfs-root.boot = {
    enable = mkOption {
      description = "Enable root on ZFS support";
      type = types.bool;
      default = true;
    };
    luks.enable = mkOption {
      description = "Use luks encryption";
      type = types.bool;
      default = false;
    };
    devNodes = mkOption {
      description = "Specify where to discover ZFS pools";
      type = types.str;
      apply = x:
        assert (strings.hasSuffix "/" x
          || abort "devNodes '${x}' must have trailing slash!");
        x;
      default = "/dev/disk/by-id/";
    };
    bootDevices = mkOption {
      description = "Specify boot devices";
      type = types.nonEmptyListOf types.str;
    };
    immutable.enable = mkOption {
      description = "Enable root on ZFS immutable root support";
      type = types.bool;
      default = false;
    };
    removableEfi = mkOption {
      description = "install bootloader to fallback location";
      type = types.bool;
      default = true;
    };
    partitionScheme = mkOption {
      default = {
        biosBoot = "-part5";
        efiBoot = "-part1";
        swap = "-part4";
        bootPool = "-part2";
        rootPool = "-part3";
      };
      description = "Describe on disk partitions";
      type = types.attrsOf types.str;
    };
  };
  config = mkIf (cfgBoot.enable) (mkMerge [
    {
      zfs-root.fileSystems.datasets = {
        # rpool/path/to/dataset = "/path/to/mountpoint"
        "rpool/nixos/home" = mkDefault "/home";
        "rpool/nixos/var/lib" = mkDefault "/var/lib";
        "rpool/nixos/var/log" = mkDefault "/var/log";
        "bpool/nixos/root" = "/boot";
      };
    }
    (mkIf cfgBoot.luks.enable {
      boot.initrd.luks.devices = mkMerge (map (diskName: {
        "luks-rpool-${diskName}${cfgBoot.partitionScheme.rootPool}" = {
          device = (cfgBoot.devNodes + diskName + cfgBoot.partitionScheme.rootPool);
          allowDiscards = true;
          bypassWorkqueues = true;
        };
      }) cfgBoot.bootDevices);
    })
    (mkIf (!cfgBoot.immutable.enable) {
      zfs-root.fileSystems.datasets = { "rpool/nixos/root" = "/"; };
    })
    (mkIf cfgBoot.immutable.enable {
      zfs-root.fileSystems = {
        datasets = {
          # rpool/path/to/dataset = "/path/to/mountpoint"
          "rpool/nixos/empty" = "/";
          "rpool/nixos/root" = "/oldroot";
        };
        bindmounts = {
          # /bindmount/source = /bindmount/target
          "/oldroot/nix" = "/nix";
          "/oldroot/etc/nixos" = "/etc/nixos";
        };
      };
      boot.initrd.systemd.services.immutable-zfs-root = {
        description = "Rollback root filesystem to an empty snapshot";
        unitConfig.DefaultDependencies = false;
        wantedBy = [ "zfs.target" ];
        after = [ "zfs-import-rpool.service" ];
        before = [ "sysroot.mount" ];
        path = [ pkgs.zfs ];
        serviceConfig.Type = "oneshot";
        script = "zfs rollback -r rpool/nixos/empty@start";
      };
    })
    {
      zfs-root.fileSystems = {
        efiSystemPartitions =
          (map (diskName: diskName + cfgBoot.partitionScheme.efiBoot)
            cfgBoot.bootDevices);
        swapPartitions =
          (map (diskName: diskName + cfgBoot.partitionScheme.swap) cfgBoot.bootDevices);
      };
      boot = {
        supportedFilesystems = [ "zfs" ];
        zfs = {
          devNodes = cfgBoot.devNodes;
          forceImportRoot = mkDefault false;
        };
        loader = {
          efi = {
            canTouchEfiVariables = (if cfgBoot.removableEfi then false else true);
            efiSysMountPoint = ("/boot/efis/" + (head cfgBoot.bootDevices)
              + cfgBoot.partitionScheme.efiBoot);
          };
          generationsDir.copyKernels = true;
          grub = {
            enable = true;
            devices = (map (diskName: cfgBoot.devNodes + diskName) cfgBoot.bootDevices);
            efiInstallAsRemovable = cfgBoot.removableEfi;
            copyKernels = true;
            efiSupport = true;
            zfsSupport = true;
            extraInstallCommands = (toString (map (diskName: ''
              set -x
              ${pkgs.coreutils-full}/bin/cp -r ${config.boot.loader.efi.efiSysMountPoint}/EFI /boot/efis/${diskName}${cfgBoot.partitionScheme.efiBoot}
              set +x
            '') (tail cfgBoot.bootDevices)));
          };
        };
      };
    }
  ]);
}
