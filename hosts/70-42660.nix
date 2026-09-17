{ lib, ... }:

{
  networking.hostName = "70-42660";

  system.primaryUser = "h.yoshimura";

  users.users."h.yoshimura" = {
    name = "h.yoshimura";
    home = "/Users/h.yoshimura";
  };

  homebrew.casks = [
    "docker"
  ];

  home-manager.users."h.yoshimura" = {
    imports = [ ../modules/home ];
    dotfiles.localGitHubKey = true;
  };
}
