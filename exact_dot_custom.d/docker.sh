#!/bin/bash

#######################
# Container Providers #
#######################

# Fuzzy find the container
function docker_container_fuzzy() {
  local container
  container=$(docker ps | grep -v CONTAINER | awk '-F ' ' {print $NF}' | fzf --query="${1:-}" --select-1 --height 20)

  if [ -z "$container" ]; then
    return 1
  fi

  echo "$container"
}

# Find the container with the current project mounted
function docker_container_project() {
  local dir container
  dir=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  container=$(docker ps -q | xargs docker inspect | jq -r '.[] | select(.Mounts[] | .Source == "'"$dir"'") | .Name')

  if [ -z "$container" ]; then
    echo "Error: No container found for $dir" >&2
    return 1
  fi

  echo "$container"
}

##################
# Base Functions #
##################

function docker_function_exec() {

  local container=$1
  shift

  local opts=()
  while [[ "$1" == --* ]]; do
    case "$1" in
    --root)
      opts+=("-u" "0")
      ;;
    *)
      echo "Error: Invalid option: $1" >&2
      return 1
      ;;
    esac
    shift
  done
  docker exec "${opts[@]}" -it "$container" "${@:-sh}"
}

function docker_function_log() {
  docker logs -f "$1"
}

##############
# Composites #
##############

function docker_construct_helper() {
  local base="$1"
  local provider="$2"
  local params="$3"
  shift 3

  if [ $# -lt "$params" ]; then
    echo "Error: missing container selection arguments" >&2
    return 1
  fi

  local container
  container="$($provider "${@:1:$params}")"
  shift "$params"

  if [ -z "$container" ]; then
    return 1
  fi

  $base "$container" "$@"
}

alias pdex='docker_construct_helper "docker_function_exec" "docker_container_project" 0'
alias pdlog='docker_construct_helper "docker_function_log" "docker_container_project" 0'
alias fdex='docker_construct_helper "docker_function_exec" "docker_container_fuzzy" 1'
alias fdlog='docker_construct_helper "docker_function_log" "docker_container_fuzzy" 1'

###########
# Helpers #
###########

# Laravel

alias da='pdex php artisan'

# PHP
alias dstan='pdex php vendor/bin/phpstan'
