# Fuzzy select a dir to CD into
function cdf() {
  cd "$(find . -type d -mindepth 1 -maxdepth 1 | xargs -I{} basename {} | fzf --query="${1:-}" --preview="ls -A {}" --select-1 --height 20)"
}
