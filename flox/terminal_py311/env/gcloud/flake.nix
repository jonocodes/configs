{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs }: {
    packages = builtins.mapAttrs (system: pkgs: {
      default = pkgs.google-cloud-sdk.withExtraComponents( with pkgs.google-cloud-sdk.components; [
        gke-gcloud-auth-plugin
      ]);
    }) nixpkgs.legacyPackages;
  };
}
