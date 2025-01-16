#!/usr/bin/env bash
# check-dependencies.sh - Script to check if required binaries are installed and print their versions
# shellcheck disable=SC1091

set -euo pipefail

# Source logging functions
source "${SCRIPTS_DIR}/functions/logging.sh"

# Function to check if a binary is installed and print its version
# Inputs:
#   $1 - The binary name (az, jq, yq)
function check_binary_installed() {
  local binary="$1"

  if command -v "${binary}" &>/dev/null; then
    print_success "Dependency '${binary}' is installed."
  else
    print_error "Dependency '${binary}' is not installed. Please install it before running this script."
    exit 1
  fi
}

# Function to check prerequisites
# Inputs:
#   A list of binaries to check (az, jq, yq)
function check_prerequisites() {
  local binaries=("$@")
  if [[ "${#binaries[@]}" -eq 0 ]]; then
    print_error "No binaries specified. Usage: ${0} <binary1> <binary2> ..."
    exit 1
  fi

  for binary in "${binaries[@]}"; do
    check_binary_installed "${binary}"
  done

  print_success "All required binaries are installed and verified."
}

# Main logic
if [[ $# -lt 1 ]]; then
  print_error "Usage: ${0} <binary1> <binary2> ..."
  exit 1
fi

check_prerequisites "$@"