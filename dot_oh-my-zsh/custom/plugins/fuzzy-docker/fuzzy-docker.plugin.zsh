function fdcontainer() {
  docker ps | rg -v CONTAINER | awk '-F ' ' {print $NF}' | fzf
}

function fdex() {
  docker exec -it $(fdcontainer) "${@:-bash}"
}

function fdex() {
  docker logs -f $(fdcontainer)
}
