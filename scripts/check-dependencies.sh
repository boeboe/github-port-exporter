#!/usr/bin/env bash
# check-dependencies.sh - Script to check if required binaries are installed and print their versions
# shellcheck disable=SC1091

set -euo pipefail

# Source logging functions
source "${SCRIPTS_DIR}/functions/logging.sh"

# Check if a binary is installed and print its version
# Arguments:
#   $1 - The binary name (e.g., az, jq, yq)
# Exits:
#   If the binary is not installed
function check_binary_installed() {
  local binary="$1"

  if command -v "${binary}" &>/dev/null; then
    print_success "Dependency '${binary}' is installed."
  else
    print_error "Dependency '${binary}' is not installed. Please install it before running this script."
    exit 1
  fi
}

# Check prerequisites by verifying the presence of binaries
# Arguments:
#   A list of binary names to check (e.g., az, jq, yq)
# Exits:
#   If any of the binaries are not installed
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
# Arguments:
#   Command-line arguments specifying the binaries to check
if [[ $# -lt 1 ]]; then
  print_error "Usage: ${0} <binary1> <binary2> ..."
  exit 1
fi

check_prerequisites "$@"