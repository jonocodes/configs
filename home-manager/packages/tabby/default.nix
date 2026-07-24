# Tabby — "a terminal for a more modern age" (https://github.com/Eugeny/tabby).
#
# NOTE: This is NOT the nixpkgs `tabby` package. nixpkgs `tabby` is TabbyML,
# an unrelated self-hosted AI code-completion server (github.com/TabbyML/tabby).
# The Eugeny/tabby GUI terminal is not in nixpkgs, so we wrap the upstream
# native AppImage. Multi-arch: x86_64 + aarch64. To bump, update `version` and
# both hashes below:
#   for a in x64 arm64; do
#     nix-prefetch-url --type sha256 \
#       "https://github.com/Eugeny/tabby/releases/download/v<VER>/tabby-<VER>-linux-$a.AppImage" \
#       | xargs nix hash to-sri --type sha256
#   done

{ lib, stdenv, appimageTools, fetchurl }:

let
  pname = "tabby";
  version = "1.0.235";

  # Upstream publishes one native AppImage per arch (…-linux-x64/arm64.AppImage).
  sources = {
    "x86_64-linux" = {
      arch = "x64";
      hash = "sha256-DKXcAV/l7nhA8rIGhkzDfFL3w2t6c06GU6Oa6KV23O8=";
    };
    "aarch64-linux" = {
      arch = "arm64";
      hash = "sha256-dGyeMB7qeK8VLybG3x0ps+6lWzDvKf/Z+oa88r2NA74=";
    };
  };

  selected = sources.${stdenv.hostPlatform.system} or (throw
    "tabby: unsupported system ${stdenv.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/Eugeny/tabby/releases/download/v${version}/tabby-${version}-linux-${selected.arch}.AppImage";
    inherit (selected) hash;
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/tabby.desktop \
      $out/share/applications/tabby.desktop
    install -Dm444 ${appimageContents}/usr/share/icons/hicolor/512x512/apps/tabby.png \
      $out/share/icons/hicolor/512x512/apps/tabby.png
    # Point the launcher at the wrapped binary instead of the AppImage's AppRun.
    substituteInPlace $out/share/applications/tabby.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=${pname} --no-sandbox %U'
  '';

  meta = {
    description = "Terminal for a more modern age (Eugeny/tabby; distinct from nixpkgs tabby = TabbyML)";
    homepage = "https://github.com/Eugeny/tabby";
    changelog = "https://github.com/Eugeny/tabby/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "tabby";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}
