#######################
# Container Providers #
#######################

# Fuzzy find the container
function docker_container_fuzzy() {
  docker ps | grep -v CONTAINER | awk '-F ' ' {print $NF}' | fzf --query="${1:-}" --select-1 --height 20
}

# Find the container with the current project mounted
function docker_container_project() {
  dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  docker ps -q | xargs docker inspect | jq -r '.[] | select(.Mounts[] | .Source == "'$dir'") | .Name'
}

##################
# Base Functions #
##################

function docker_function_exec() {
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

  local container=$1
  shift
  docker exec $opts -it "$container" "${@:-sh}"
}

function docker_function_log() {
  docker logs -f "$1"
}

##############
# Composites #
##############

function fdex() {
  local container=$(docker_container_fuzzy "$1")
  shift
  docker_function_exec "$container" "$@"
}

function flog() {
  docker_function_log "$(docker_container_fuzzy "$1")"
}

alias pdex='docker_function_exec $(docker_container_project)'
alias plog='docker_function_log $(docker_container_project)'
