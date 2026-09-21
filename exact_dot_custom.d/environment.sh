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
  "$HOME/.local/share/mise/shims"
)
for bin_path in "${BIN_PATHS[@]}"; do
  if [ -d "$bin_path" ] && [[ ":$PATH:" != *":$bin_path:"* ]]; then
    export PATH="$bin_path:$PATH"
  fi
done

# Resolve cloud storage roots into shortcut vars (cd "$proton", ls "$proton")
proton_dir="$(find "$HOME/Library/CloudStorage" -mindepth 1 -maxdepth 1 -name 'ProtonDrive-*' 2>/dev/null | head -n1)"
if [ -n "$proton_dir" ]; then
  export proton="$proton_dir"
fi
unset proton_dir
