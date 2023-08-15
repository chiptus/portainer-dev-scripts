#!/bin/bash

#====================== log ======================

log_info() {
  # Usage: log_info "this is the info log message"
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo "${NOW} [INFO] $1"
}

log_warning() {
  # Usage: log_warning "this is the warning log message"
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo "${NOW} [WARNING] $1"
}

log_error() {
  # Usage: log_error "this is the error log message"
  NOW=$(date +"%Y-%m-%d %H:%M:%S")
  echo "${NOW} [ERROR] $1"
}

log_exit() {
  # Usage: log_exit "the log message before exit"
  log_error "$1"
  exit 1
}
