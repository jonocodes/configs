
# building with GOPROXY=https://proxy.golang.org nix-build
#   but its having some issues pulling vendor libraries

# { lib, pkg, buildGoModule, fetchFromGitHub }:
{ pkgs ? import <nixpkgs> {} }:

pkgs.buildGoModule rec {

  GOPROXY = "https://proxy.golang.org";
  
  # This allows network access during the build
  doCheck = false;
  doVendoring = false;  # Disable vendoring entirely
  nativeBuildInputs = [ pkgs.gnutar ];
  allowedRequisites = [ pkgs.go ];
  shellHook = ''
    export GOPROXY=https://proxy.golang.org
  '';


  pname = "flatpak-compose";
  version = "0.4.1"; # Replace with your project's version

  src = pkgs.fetchFromGitHub {
    owner = "faan11";
    repo = pname;
    rev = version;
    sha256 = "sha256-lRjH9Kj8WuZdW5eQFmn5La3nmFznoQeRI4KrP64HhsE="; # Leave empty for now
  };

  # vendorHash = null; # Set to null if your project doesn't have dependencies

  vendorHash = "sha256-1TyFfRL6HTOa+M4CEcHeiReRcPlPNKMneq2AVXS0kX0="; # Let Nix prefetch the modules


  # Force Go to bypass vendoring completely
  subPackages = [ "cmd" ];  # Set the subdirectory where your main app lives
  buildFlagsArray = [ "-mod=mod" ];  # Force Go to fetch dependencies


  meta = with pkgs.lib; {
    description = "Define your flatpak applications and permissions ";
    homepage = "https://github.com/faan11/flatpak-compose";
    license = licenses.mit;
    maintainers = with maintainers; [ "Jono" ];
  };
}

