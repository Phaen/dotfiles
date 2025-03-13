function fdcontainer() {
  docker ps | grep -v CONTAINER | awk '-F ' ' {print $NF}' | fzf --select-1 --height 20
}

function fdex() {
  docker exec -it $(fdcontainer) "${@:-sh}"
}

function fdlog() {
  docker logs -f $(fdcontainer)
}
