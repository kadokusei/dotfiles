{
  description = "kadokusei dotfiles: Lix + nix-darwin + Home Manager + mise";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, sops-nix }:
    let
      sharedHmModules = [
        ./modules/home
        sops-nix.homeManagerModules.sops
      ];
    in
    {
      darwinConfigurations."helium" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./modules/darwin/default.nix
          ./hosts/helium.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ];
            # 初回 switch 時に既存ファイルと衝突したら *.hm-backup に退避する
            home-manager.backupFileExtension = "hm-backup";
          }
        ];
      };

      darwinConfigurations."70-42660" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./modules/darwin/default.nix
          ./hosts/70-42660.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ];
            home-manager.backupFileExtension = "hm-backup";
          }
        ];
      };

      # TODO(Step 10): 実機のアーキを確認 (現状 x86_64-linux 前提)
      homeConfigurations."wsl" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
        modules = sharedHmModules ++ [ ./hosts/wsl.nix ];
      };

      # TODO(Step 10): 実機のユーザー名・アーキを確認 (現状 x86_64-linux 前提)
      homeConfigurations."linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
        modules = sharedHmModules ++ [ ./hosts/linux.nix ];
      };
    };
}
