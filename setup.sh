#!/bin/bash

# "git submodule"
cd $HOME/dotfiles
git submodule init
git submodule update

# vim
ln -sf $HOME/dotfiles/vim/vimrc $HOME/.vimrc
ln -sf $HOME/dotfiles/vim/vimfiles $HOME/.vim
vim -c NeoBundleInstall! -c q

# zsh
ln -sf $HOME/dotfiles/zsh/zshrc $HOME/.zshrc

# git
ln -sf $HOME/dotfiles/git/gitconfig $HOME/.gitconfig
ln -sf $HOME/dotfiles/git/gitignore $HOME/.gitignore

# tmux
ln -sf $HOME/dotfiles/tmux/tmux.conf $HOME/.tmux.conf
