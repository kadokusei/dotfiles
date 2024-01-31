#!/bin/bash

# "git submodule"
cd $HOME/dotfiles
# vim
ln -sf $HOME/dotfiles/vim/vimrc $HOME/.vimrc
ln -sf $HOME/dotfiles/vim/vimfiles $HOME/.vim

# zsh
ln -sf $HOME/dotfiles/zsh/zshrc $HOME/.zshrc

# git
ln -sf $HOME/dotfiles/git/gitconfig $HOME/.gitconfig
ln -sf $HOME/dotfiles/git/gitignore $HOME/.gitignore

# tmux
ln -sf $HOME/dotfiles/tmux/tmux.conf $HOME/.tmux.conf
