function fdcontainer() {
  docker ps | grep -v CONTAINER | awk '-F ' ' {print $NF}' | fzf --query="${1:-}" --select-1 --height 20
}

function fdex() {
  local opts=()
  while [[ "$1" == --* ]]; do
    case "$1" in
      --root)
        opts+=("-u" "0")
        ;;
      *)
        echo "Error: Invalid option: $1" >&2
        exit 1
        ;;
    esac
    shift
  done

  local container=$(fdcontainer $1)
  shift
  docker exec $opts -it "$container" "${@:-sh}"
}

function fdlog() {
  docker logs -f $(fdcontainer $1)
}
