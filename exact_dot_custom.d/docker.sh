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

  # Always interactive, add TTY only if STDIN is a terminal
  opts+=("-i")
  if [ -t 0 ]; then
    opts+=("-t")
  fi

  docker exec "${opts[@]}" "$container" "${@:-sh}"
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

##################
# Misc Functions #
##################

dserv() {
  local project_mode=false

  # Parse flags
  while [[ $# -gt 0 ]]; do
    case $1 in
    -p | --project)
      project_mode=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: dserv [-p|--project]"
      return 1
      ;;
    esac
  done
  # Find containers configured to bind HOST ports 80 or 465
  local containers_info=$(docker ps -a --format "{{.Names}}" | while read -r container; do
    # Check if any HostPort is "80" or "465"
    if docker inspect "$container" --format '{{json .HostConfig.PortBindings}}' 2>/dev/null |
      grep -E '"HostPort":"(80|465)"' >/dev/null; then

      # Get project info
      local project=$(docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null)
      local service=$(docker inspect "$container" --format '{{index .Config.Labels "com.docker.compose.service"}}' 2>/dev/null)

      if [[ "$project_mode" == "true" && -n "$project" ]]; then
        echo "$container|$project|$service"
      else
        echo "$container||"
      fi
    fi
  done)

  local containers=$(echo "$containers_info" | cut -d'|' -f1)

  if [[ -z "$containers" ]]; then
    echo "No containers found with ports 80 or 465"
    return 1
  fi

  # Use fzf to select a container
  local selection_list
  if [[ "$project_mode" == "true" ]]; then
    selection_list=$(echo "$containers_info" | while IFS='|' read -r container project service; do
      if [[ -n "$project" ]]; then
        echo "$container ($project)"
      else
        echo "$container (standalone)"
      fi
    done)
  else
    selection_list="$containers"
  fi

  local selected=$(echo "$selection_list" | fzf --prompt="Select container to start: " --height=10)

  if [[ -z "$selected" ]]; then
    echo "No container selected"
    return 0
  fi

  # Extract container name from selection
  local selected_container=$(echo "$selected" | sed 's/ (.*//')

  # Get project info for selected container
  local selected_info=$(echo "$containers_info" | grep "^$selected_container|")
  local selected_project=$(echo "$selected_info" | cut -d'|' -f2)

  # Find currently running containers bound to host ports 80/465
  local running=$(docker ps --format "{{.Names}}" | while read -r container; do
    if docker inspect "$container" --format '{{json .HostConfig.PortBindings}}' 2>/dev/null |
      grep -E '"HostPort":"(80|465)"' >/dev/null; then
      echo "$container"
    fi
  done)

  # Stop running containers on ports 80/465
  if [[ -n "$running" ]]; then
    echo "Stopping containers using ports 80/465:"
    echo "$running" | while read -r container; do
      echo "  Stopping $container..."
      docker stop "$container" >/dev/null
    done
  fi

  # Start the selected container or project
  if [[ "$project_mode" == "true" && -n "$selected_project" ]]; then
    echo "Starting project: $selected_project"

    # Get compose file path from docker compose ls
    local compose_file=$(docker compose ls -a --format json | jq -r ".[] | select(.Name == \"$selected_project\") | .ConfigFiles" | tr ',' '\n' | head -1)

    if [[ -n "$compose_file" && -f "$compose_file" ]]; then
      docker compose -f "$compose_file" up -d
    else
      echo "Warning: Could not find compose project $selected_project"
      echo "Falling back to starting individual container..."
      docker start "$selected_container"
    fi
  else
    echo "Starting $selected_container..."
    docker start "$selected_container"
  fi
}

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
