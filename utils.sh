#!/bin/bash

function get_dev_branch_name() {
  origin_branch="$1"
  # if the branch is already a dev branch, return 1
  if [[ $origin_branch == *auto-develop* ]]; then
    echo "this is already a dev branch"
    return 1
  fi

  echo "$origin_branch" | awk '/EE-[0-9]+\/+/{sub(/EE-[0-9]+\//, "&auto-develop/")} 1'
}

function get_other_edition_path() {
  if [[ $PWD == *portainer-ee ]]; then
    echo "$HOME/portainer-org/portainer"
  else
    echo "$HOME/portainer-org/portainer-ee"
  fi
}

function get_current_branch_name() {
  git branch --show-current
}

function gpb() {
  git push -u origin "$(get_current_branch_name)"
}
