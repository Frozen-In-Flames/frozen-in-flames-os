{
  description = "FROZEN IN FLAMES: a libre NixOS-based service platform with 39 platform targets";

  inputs = {
    # Pinned by flake.lock. Commit flake.lock after the first successful evaluation.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }:
    let
      system = "x86_64-linux";

      # Release configuration. No default credentials.
      releaseModules = [
        ./system/default.nix
        ./system/packages.nix
        ./system/services.nix
        ./system/frozen-services.nix
        ./system/legacy.nix
      ];

      # Test configuration. Development credentials and open ports. Never ship it.
      testModules = releaseModules ++ [ ./profiles/development.nix ];
    in
    {
      nixosConfigurations = {
        frozen-in-flames = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = releaseModules;
        };
        frozen-in-flames-test = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = testModules;
        };
      };

      packages.${system} = {
        qcow2 = nixos-generators.nixosGenerate {
          inherit system;
          format = "qcow";
          modules = releaseModules;
        };
        iso = nixos-generators.nixosGenerate {
          inherit system;
          format = "install-iso";
          modules = releaseModules;
        };
        qcow2-test = nixos-generators.nixosGenerate {
          inherit system;
          format = "qcow";
          modules = testModules;
        };
      };
    };
}
