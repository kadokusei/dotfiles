#!/bin/bash

# install homebrew
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# install formula
$HOME/dotfiles/brew/brewfile.sh
