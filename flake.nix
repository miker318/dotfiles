{
  inputs = {
    nixos-pkgs.url = "github:NixOS/nixpkgs/nixos-24.05-small";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Secure Boot for NixOS
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixos-pkgs";
    };

    # User profile manager based on Nix
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Service to fix libraries and links for NixOS hosting as VSCode remote
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Links persistent folders into system
    impermanence.url = "github:nix-community/impermanence";

    # Provides module support for specific vendor hardware
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    # fw ectool as configured for FW13 7040 AMD (until patch is upstreamed)
    fw-ectool = {
      url = "github:tlvince/ectool.nix";
      inputs.nixpkgs.follows = "nixos-pkgs";
    };
  };

  outputs = { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = inputs.nixos-pkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      osOverlays = [
        (_: _: { fw-ectool = inputs.fw-ectool.packages.${system}.ectool; })
      ];

      # Base user config modules
      homeModules = [
        ./.config/nixos/home/tui.nix
        ./.config/nixos/home/git.nix
        ./.config/nixos/home/neovim.nix
        ./.config/nixos/home/helix.nix
        ./.config/nixos/home/gpg-agent.nix
      ];

      # Additional user applications and configurations
      guiModules = [
        ./.config/nixos/home/applications.nix
        ./.config/nixos/home/gnome.nix
      ];

      # User config modules for hosting services
      serverHomeModules = [
        inputs.vscode-server.nixosModules.home
        ./.config/nixos/home/services.nix
      ];

      # Base OS configs, adapts to system configs
      osModules = [
        inputs.lanzaboote.nixosModules.lanzaboote
        inputs.impermanence.nixosModules.impermanence
        inputs.nixos-hardware.nixosModules.common-hidpi
        ./.config/nixos/os/persist.nix
        ./.config/nixos/os/secure-boot.nix
        ./.config/nixos/os/system.nix
        ./.config/nixos/os/upgrade.nix
        {
          nixpkgs.overlays = osOverlays;
        }
      ];

      # Function to build a home configuration from user modules
      homeUser = (userModules: inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        # userModules overwrites, so is appended
        modules = homeModules ++ guiModules ++ userModules;
      });

      # Function to build a nixos configuration from system modules
      nixosSystem = (systemModules: lib.nixosSystem {
        inherit system;
        # osModules depends on some values from systemModules, so is appended
        modules = systemModules ++ osModules;
      });

    in {
      homeConfigurations = {

        mrose = homeUser [ ./.config/nixos/users/mrose.nix ];

      };
      nixosConfigurations = {

        fw-laptop = nixosSystem [
          inputs.nixos-hardware.nixosModules.framework-13-11th-gen-intel
          ./.config/nixos/systems/fw-laptop.nix
        ];

        cronos = nixosSystem [
          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p1-gen3
          ./.config/nixos/systems/cronos.nix
        ];

      };
    };
}
