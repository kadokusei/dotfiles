{ lib, ... }:

{
  # TODO(Step 10): 実機の LocalHostName / ユーザー名に置換すること
  networking.hostName = lib.mkDefault "work-mac";

  system.primaryUser = lib.mkDefault "work-user";

  users.users.work-user = {
    name = "work-user";
    home = "/Users/work-user";
  };

  home-manager.users.work-user = {
    imports = [ ../modules/home ];
  };
}
