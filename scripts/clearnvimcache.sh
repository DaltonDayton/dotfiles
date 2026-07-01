#!/usr/bin/bash

APP=${1:-nvim}

rm -rf ~/.local/share/$APP/
rm -rf ~/.local/state/$APP/
rm -rf ~/.cache/$APP/
