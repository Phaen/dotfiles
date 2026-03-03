#!/bin/bash

# Fuzzy select a dir to CD into
function cdf() {
  cd "$(find . -type d -mindepth 1 -maxdepth 1 | xargs -I{} basename {} | fzf --query="${1:-}" --preview="ls -A {}" --select-1 --height 20)"
}

# Easy auto-restart with 1s sleep
persistent() {
  while true; do
    "$@"
    echo "--- Exited ($?), reconnecting in 1s ---"
    sleep 1
  done
}

# Easy access to Python venv
alias venv="source venv/bin/activate"

# Bypass xterm-kitty during sudo, when unavailable on sudo'd user
alias sudou='sudo TERM=xterm-256color -iu'
