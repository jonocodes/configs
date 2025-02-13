
# NOTE: I use flox instead of this for now

{ pkgs, pkgs-unstable, inputs, modulesPath, home-manager, ... }:
let inherit (inputs) self;
in {

  # favor apps to not use root for security
  # requires a logout of gnome after an install to show the launcher?
  home-manager.users.jono.home.packages = with pkgs-unstable;
    [

      python311
      python311Packages.pip
      python311Packages.numpy
      conda
      # python311Packages.conda
      # python3.pkgs.truststore 
      # pdm
      nodejs_20
      yarn
      gnumake
      go-task
      terraform
      (google-cloud-sdk.withExtraComponents
        [ google-cloud-sdk.components.gke-gcloud-auth-plugin ])
      kubectl
      google-cloud-sql-proxy

      go
      gcc

      binutils

      # parquet-tools

      # zap

      # trying to get airflow tests working
      # gcc-unwrapped
      # gcc6
      # libz
      zlib

    ] ++ (with pkgs;
      [

      ]);

}
