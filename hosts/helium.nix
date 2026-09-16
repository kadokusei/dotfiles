{ lib, ... }:

{
  networking.hostName = "helium";

  system.primaryUser = "readabi1ity";

  users.users.readabi1ity = {
    name = "readabi1ity";
    home = "/Users/readabi1ity";
  };

  home-manager.users.readabi1ity = {
    imports = [ ../modules/home ];
  };
}
