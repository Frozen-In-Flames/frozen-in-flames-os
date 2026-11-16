{
  description = "FROZEN IN FLAMES — libre, integrated 39-platform computing environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, nixos-generators, ... }:
    let
      system = "x86_64-linux";
      modules = [ ./nixos/configuration.nix ];
      pkgs = import nixpkgs { inherit system; config.allowUnfree = false; };
    in {
      nixosConfigurations.frozen-in-flames = nixpkgs.lib.nixosSystem {
        inherit system modules;
        specialArgs = { inherit self; };
      };
      packages.${system}.qcow2 = nixos-generators.nixosGenerate {
        inherit system modules;
        format = "qcow";
      };
      packages.${system}.iso = nixos-generators.nixosGenerate {
        inherit system modules;
        format = "install-iso";
      };
      checks.${system}.catalog = pkgs.runCommand "fif-catalog-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python ${./scripts/validate_catalog.py} ${./registry/platforms.json}
        touch $out
      '';
    };
}
