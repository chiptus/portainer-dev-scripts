#!/bin/bash

function get_current_branch_name() {
  git branch --show-current
}

# Inserts "release-<version>/" after the ticket segment.
# get_release_branch_name "fix/BE-12885/workflow-status" "BE-12885" "release/2.34"
# -> "fix/BE-12885/release-2.34/workflow-status"
function get_release_branch_name() {
  local branch="$1" ticket="$2" release_base="$3"
  local version
  version=$(echo "$release_base" | sed 's|.*/||')
  echo "$branch" | sed "s|${ticket}/|${ticket}/release-${version}/|"
}

# Inverse: strips "release-<version>/" from after the ticket segment.
# get_dev_branch_name "fix/BE-12885/release-2.34/workflow-status" "BE-12885" "release/2.34"
# -> "fix/BE-12885/workflow-status"
function get_dev_branch_name() {
  local branch="$1" ticket="$2" release_base="$3"
  local version
  version=$(echo "$release_base" | sed 's|.*/||')
  echo "$branch" | sed "s|${ticket}/release-${version}/|${ticket}/|"
}
