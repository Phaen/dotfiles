#!/bin/bash

# Fuzzy select a dir to CD into
function cdf() {
  cd "$(find . -type d -mindepth 1 -maxdepth 1 | xargs -I{} basename {} | fzf --query="${1:-}" --preview="ls -A {}" --select-1 --height 20)"
}

alias venv="source venv/bin/activate"

persistent() {
    while true; do "$@"; echo "--- Exited ($?), reconnecting in 1s ---"; sleep 1; done
}
