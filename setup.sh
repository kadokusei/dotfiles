#!/bin/bash

"git submodule"
cd $HOME/dotfiles
git submodule init
git submodule update

# vim
ln -s $HOME/dotfiles/vim/vimrc $HOME/.vimrc
ln -s $HOME/dotfiles/vim/vimfiles $HOME/.vim
vim -c NeoBundleInstall! -c q

# zsh
ln -s $HOME/dotfiles/zsh/zshrc $HOME/.zshrc

# git
ln -s $HOME/dotfiles/git/gitconfig $HOME/.gitconfig
ln -s $HOME/dotfiles/git/gitignore $HOME/.gitignore
