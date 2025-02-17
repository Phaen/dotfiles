function fdcontainer() {
  docker ps | grep -v CONTAINER | awk '-F ' ' {print $NF}' | fzf
}

function fdex() {
  docker exec -it $(fdcontainer) "${@:-bash}"
}

function fdlog() {
  docker logs -f $(fdcontainer)
}
