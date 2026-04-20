{ lib
, pkgs
, callPackage
, makeRustPlatform
, fetchFromGitHub
, bzip2
, blueprint-compiler
, expat
, fontconfig
, freetype
, gettext
, git
, glib
, gobject-introspection
, glslang
, gst_all_1
, gtk4-layer-shell
, harfbuzz
, libGL
, libX11
, libXcursor
, libXi
, libXrandr
, libxml2
, libxkbcommon
, oniguruma
, libpng
, ncurses
, pandoc
, pkg-config
, autoPatchelfHook
, patchelf
, simdutf
, spirv-cross
, wayland
, wayland-protocols
, wayland-scanner
, wrapGAppsHook4
, zig_0_15
, zlib
, gtk4
, libadwaita
, webkitgtk_6_0
, libsoup_3
, glib-networking
, gsettings-desktop-schemas
, adwaita-icon-theme
, hicolor-icon-theme
, shared-mime-info
, libepoxy
}:

# TODO: submit this to nixpkgs

let
  rustOverlay = import (builtins.fetchTarball {
    url = "https://github.com/oxalica/rust-overlay/archive/8d6387ed6d8e6e6672fd3ed4b61b59d44b124d99.tar.gz";
    sha256 = "sha256-3xBsGnGDLOFtnPZ1D3j2LU19wpAlYefRKTlkv648rU0=";
  });

  pkgsRust = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config;
    overlays = [ rustOverlay ];
  };

  rustToolchain = pkgsRust.rust-bin.stable."1.92.0".default;
  rustPlatform = makeRustPlatform {
    cargo = rustToolchain;
    rustc = rustToolchain;
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "limux";
  version = "0.1.11";

  src = fetchFromGitHub {
    owner = "am-will";
    repo = "limux";
    rev = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-OML1f4TvLegpXHr17MVcFvP1PJkFFMk3s+QMvrC7+ok=";
  };

  cargoHash = "sha256-uHYgmdwYHjxnq/jpRkolAnq5oQMlZsfNIFjoYF5QLRE=";

  ghosttyDeps = callPackage "${finalAttrs.src}/ghostty/build.zig.zon.nix" {
    name = "limux-ghostty-zig-cache";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    blueprint-compiler
    gettext
    git
    gobject-introspection
    libxml2
    ncurses
    pandoc
    pkg-config
    patchelf
    wayland-protocols
    wayland-scanner
    wrapGAppsHook4
    zig_0_15
  ];

  buildInputs = [
    bzip2
    expat
    fontconfig
    freetype
    glib
    glslang
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gstreamer
    libepoxy
    libGL
    libX11
    libXcursor
    libXi
    libXrandr
    libxkbcommon
    gtk4
    gtk4-layer-shell
    libadwaita
    webkitgtk_6_0
    libsoup_3
    glib-networking
    gsettings-desktop-schemas
    adwaita-icon-theme
    hicolor-icon-theme
    harfbuzz
    libpng
    libxml2
    oniguruma
    shared-mime-info
    simdutf
    spirv-cross
    wayland
    zlib
  ];

  cargoBuildFlags = [ "-p" "limux-host-linux" ];
  cargoInstallFlags = [ "-p" "limux-host-linux" "--bin" "limux" ];
  cargoTestFlags = [ "-p" "limux-host-linux" ];
  doCheck = false;
  strictDeps = true;
  dontSetZigDefaultFlags = true;

  env = {
    ZIG_GLOBAL_CACHE_DIR = ".zig-cache-global";
    ZIG_LOCAL_CACHE_DIR = ".zig-cache";
    GI_TYPELIB_PATH = lib.makeSearchPath "lib/girepository-1.0" [
      gtk4
      libadwaita
      webkitgtk_6_0
      libsoup_3
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gstreamer
    ];
  };

  preBuild = ''
    (
      cd ghostty
      zig build \
        --system "${finalAttrs.ghosttyDeps}" \
        -Dapp-runtime=none \
        -Dgtk-x11=true \
        -Dgtk-wayland=true \
        -Doptimize=ReleaseFast \
        -Dcpu=baseline \
        --prefix "$PWD/zig-out"
    )
  '';

  postInstall = ''
    mkdir -p $out/lib $out/share/limux

    install -Dm755 ghostty/zig-out/lib/libghostty.so $out/lib/libghostty.so
    cp -r ghostty/zig-out/share/ghostty $out/share/limux/ghostty

    mkdir -p $out/share/limux/terminfo
    cp -r ghostty/zig-out/share/terminfo/. $out/share/limux/terminfo/ || true

    install -Dm644 rust/limux-host-linux/dev.limux.linux.desktop \
      $out/share/applications/dev.limux.linux.desktop
    install -Dm644 rust/limux-host-linux/dev.limux.linux.metainfo.xml \
      $out/share/metainfo/dev.limux.linux.metainfo.xml

    cp -r rust/limux-host-linux/icons/hicolor $out/share/icons/ || true

    if [ -d rust/limux-host-linux/icons/app ]; then
      for size in 16 32 128 256 512; do
        src="rust/limux-host-linux/icons/app/$size.png"
        if [ -f "$src" ]; then
          install -Dm644 "$src" "$out/share/icons/hicolor/''${size}x''${size}/apps/limux.png"
        fi
      done
    fi

    patchelf --add-rpath $out/lib $out/bin/limux
  '';

  preFixup = ''
    addAutoPatchelfSearchPath $out/lib
    gappsWrapperArgs+=(
      --prefix TERMINFO_DIRS : "$out/share/limux/terminfo"
    )
  '';

  meta = {
    description = "GPU-accelerated terminal workspace manager for Linux";
    homepage = "https://github.com/am-will/limux";
    changelog = "https://github.com/am-will/limux/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "limux";
    platforms = [ "x86_64-linux" ];
  };
})
