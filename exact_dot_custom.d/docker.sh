#!/bin/bash

#######################
# Container Providers #
#######################

# Fuzzy find the container
function docker_container_fuzzy() {
  local container cache_file="/tmp/docker_container_fuzzy_cache"
  local query="${1:-}"
  local cached_container=""

  # Check if cache exists and container is still running
  if [ -f "$cache_file" ] && [ -n "$query" ]; then
    cached_container=$(grep "^$query:" "$cache_file" | cut -d':' -f2)
    if [ -n "$cached_container" ] && docker ps -q --filter "name=$cached_container" | grep -q .; then
      echo "$cached_container"
      return 0
    fi
  fi

  # No valid cache, perform fuzzy search
  container=$(docker ps | grep -v CONTAINER | awk '{print $NF}' | fzf --query="$query" --select-1 --height 20)
  if [ -z "$container" ]; then
    return 1
  fi

  # Save to cache if query was provided
  if [ -n "$query" ]; then
    grep -v "^$query:" "$cache_file" 2>/dev/null >"${cache_file}.tmp" || touch "${cache_file}.tmp"
    echo "$query:$container" >>"${cache_file}.tmp"
    mv "${cache_file}.tmp" "$cache_file"
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

# Shortcuts
alias d='pdex'
alias dlog='pdlog'

# Laravel
alias da='d php artisan'

# PHP
alias dstan='pdex php vendor/bin/phpstan --memory-limit=2G'
