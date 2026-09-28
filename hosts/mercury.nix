{ lib, ... }:

{
  # TODO(Step 10): 実機のユーザー名・ホームパスを確認すること
  home.username = lib.mkDefault "readabi1ity";
  home.homeDirectory = lib.mkDefault "/home/readabi1ity";

  dotfiles.localGitHubKey = true;
}
