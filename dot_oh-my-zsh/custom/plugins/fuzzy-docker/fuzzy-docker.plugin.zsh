function fdcontainer() {
  docker ps | grep -v CONTAINER | awk '-F ' ' {print $NF}' | fzf --query="${1:-}" --select-1 --height 20
}

function fdex() {
  local container=$(fdcontainer $1)
  shift
  docker exec -it "$container" "${@:-sh}"
}

function fdlog() {
  docker logs -f $(fdcontainer $1)
}
