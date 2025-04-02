#!/bin/bash

# Add missing local bin paths to PATH
BIN_PATHS=(
  "$HOME/.local/bin"
  "$HOME/bin"
  "$HOME/.npm-global/bin"
  "$HOME/.cargo/bin"
  "$HOME/.composer/vendor/bin"
  "$HOME/.config/composer/vendor/bin"
  "$HOME/.yarn/bin"
  "$HOME/.pyenv/bin"
  "$HOME/.rbenv/bin"
  "$HOME/.deno/bin"
)
for bin_path in "${BIN_PATHS[@]}"; do
  if [ -d "$bin_path" ] && [[ ":$PATH:" != *":$bin_path:"* ]]; then
    export PATH="$bin_path:$PATH"
  fi
done
