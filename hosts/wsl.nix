{ lib, ... }:

{
  dotfiles.isWSL = true;

  # TODO(Step 10): 実機のユーザー名・ホームパスを確認すること
  home.username = lib.mkDefault "hyr3k";
  home.homeDirectory = lib.mkDefault "/home/hyr3k";
}
