{
  description = "Frozen in Flames: one operating system that combines 39 open source platforms";

  inputs = {
    # Pinned by flake.lock. Commit flake.lock after the first successful evaluation.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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
      ];

      # Test configuration. Adds development credentials and open ports. Never ship it.
      devModules = releaseModules ++ [ ./profiles/development.nix ];
    in
    {
      nixosConfigurations = {
        frozen-in-flames = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = releaseModules;
        };
        frozen-in-flames-dev = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = devModules;
        };
      };

      packages.${system} = {
        # Installer ISO that installs the release configuration to physical disks.
        iso = nixos-generators.nixosGenerate {
          inherit system;
          format = "install-iso";
          modules = releaseModules;
        };

        # Test image used by tests/health_check.py.
        qcow2-dev = nixos-generators.nixosGenerate {
          inherit system;
          format = "qcow";
          modules = devModules;
        };
      };
    };
}
