function fdcontainer() {
  docker ps | rg -v CONTAINER | awk '-F ' ' {print $NF}' | fzf
}

function fdex() {
  docker exec -it $(fdcontainer) "${@:-bash}"
}

function fdlog() {
  docker logs -f $(fdcontainer)
}
