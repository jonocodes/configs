{ lib
, fetchFromGitLab
, mesa
, llvmPackages_19
, spirv-llvm-translator
}:

(mesa.override {
  galliumDrivers = [ "softpipe" "llvmpipe" "asahi" ];
  vulkanDrivers = [ "swrast" "asahi" ];
  llvmPackages = llvmPackages_19;
  spirv-llvm-translator = spirv-llvm-translator.override { llvm = llvmPackages_19.llvm; };
}).overrideAttrs (oldAttrs: {
  version = "25.1.0-asahi";
  src = fetchFromGitLab {
    # tracking: https://pagure.io/fedora-asahi/mesa/commits/asahi
    domain = "gitlab.freedesktop.org";
    owner = "asahi";
    repo = "mesa";
    tag = "asahi-20250723";
    hash = "sha256-6awfLOy0pmNHw6JK0hEMWv9FswYlZyEG2o9/aB+OU/o=";
  };

  mesonFlags =
    let
      badFlags = [
        "-Dinstall-mesa-clc"
        "-Dgallium-nine"
        "-Dgallium-mediafoundation"
        "-Dgallium-rusticl"
        "-Dtools"
      ];
      isBadFlagList = f: builtins.map (b: lib.hasPrefix b f) badFlags;
      isGoodFlag = f: !(builtins.foldl' (x: y: x || y) false (isBadFlagList f));
    in
    (builtins.filter isGoodFlag oldAttrs.mesonFlags) ++ [
      # we do not build any graphics drivers these features can be enabled for
      "-Dgallium-va=disabled"
      "-Dgallium-vdpau=disabled"
      "-Dgallium-xa=disabled"
      "-Dtools=asahi"
      "-Dgallium-rusticl=false"
    ];

  # replace patches with ones tweaked slightly to apply to this version
  patches = [
    ./opencl.patch
  ];

  postFixup = let
    lines = lib.splitString "\n" (oldAttrs.postFixup or "");
    filtered = builtins.filter (l: !(lib.hasInfix "RusticlOpenCL" l)) lines;
  in lib.concatStringsSep "\n" filtered;

  postInstall = (oldAttrs.postInstall or "") + ''
    # we don't build anything to go in this output but it needs to exist
    touch $spirv2dxil
    touch $cross_tools
    mkdir -p $opencl/lib
    touch $opencl/lib/.keep
  '';
})
