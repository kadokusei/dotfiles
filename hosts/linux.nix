{ lib, ... }:

{
  # TODO(Step 10): 実機のユーザー名・ホームパスを確認すること
  home.username = lib.mkDefault "kadokusei";
  home.homeDirectory = lib.mkDefault "/home/kadokusei";
}
