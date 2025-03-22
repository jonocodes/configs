
# just nix-build and it works!
# requires the parent default.nix

# from https://github.com/NixOS/nixpkgs/issues/356478

{
  lib,
  stdenv,
  nixpkgs,
  callPackage,
  fetchurl,
  nixosTests,
  commandLineArgs ? "",
  useVSCodeRipgrep ? stdenv.hostPlatform.isDarwin,
}:
# https://windsurf-stable.codeium.com/api/update/linux-x64/stable/latest
callPackage "${nixpkgs}/pkgs/applications/editors/vscode/generic.nix" rec {
  inherit commandLineArgs useVSCodeRipgrep;

  version = "1.2.1";
  pname = "windsurf";

  executableName = "windsurf";
  longName = "Windsurf";
  shortName = "windsurf";

  src = fetchurl {
    # url = "https://windsurf-stable.codeiumdata.com/linux-x64/stable/56025767068f846a4d68adf1914f19f9c34e1375/Windsurf-linux-x64-${version}.tar.gz";
    # hash = "sha256-YxXnSwjV8/0O2Slb6opKfEdRiGbtBaAVkRpg/BXlf6g=";

    url = "https://windsurf-stable.codeiumdata.com/linux-x64/stable/aa53e9df956d9bc7cb1835f8eaa47768ce0e5b44/Windsurf-linux-x64-${version}.tar.gz";
    hash = "sha256-dGEZQzShF5MVUZVVNFhccueVF9VqQ+/oatKRd0ZAOS0=";

  };

  sourceRoot = "Windsurf";

  tests = nixosTests.vscodium;

  updateScript = "nil";

  meta = with lib; {
    description = "The first agentic IDE, and then some";
  };
}
