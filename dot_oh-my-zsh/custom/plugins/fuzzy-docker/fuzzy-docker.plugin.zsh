function fdcontainer() {
  docker ps | grep -v CONTAINER | awk '-F ' ' {print $NF}' | fzf
}

function fdex() {
  docker exec -it $(fdcontainer) "${@:-sh}"
}

function fdlog() {
  docker logs -f $(fdcontainer)
}
