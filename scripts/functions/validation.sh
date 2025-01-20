#!/usr/bin/env bash
# validation.sh - Functions to validate input parameters.
# shellcheck disable=SC1091

# Ensure a parameter is set
# Arguments:
#   $1 - Parameter name (e.g., "PORT_CLIENT_ID")
#   $2 - Parameter value
# Exits:
#   If the parameter value is empty or unset
function validate_set() {
  local param_name="${1}"
  local param_value="${2}"

  if [[ -z "${param_value}" ]]; then
    print_error "${param_name} is required but not set."
    exit 1
  fi
  print_info "${param_name} is set to '${param_value}'."
}

# Validate that a value belongs to a predefined list (enum)
# Arguments:
#   $1 - Parameter name
#   $2 - Parameter value
#   $@ - Valid values (e.g., "value1 value2 value3")
# Exits:
#   If the parameter value does not match any of the valid values
function validate_enum() {
  local param_name="$1"
  local param_value="$2"
  shift 2
  local valid_values=("$@")

  for value in "${valid_values[@]}"; do
    if [[ "${param_value}" == "${value}" ]]; then
      print_info "${param_name} is valid: '${param_value}'"
      return 0
    fi
  done

  print_error "${param_name} must be one of: ${valid_values[*]}. Provided: '${param_value}'"
  exit 1
}

# Validate that a parameter value is a boolean
# Arguments:
#   $1 - Parameter name
#   $2 - Parameter value ("true" or "false")
# Exits:
#   If the parameter value is not "true" or "false"
function validate_boolean() {
  local param_name="${1}"
  local param_value="${2}"

  if [[ "${param_value}" != "true" && "${param_value}" != "false" ]]; then
    print_error "${param_name} must be either 'true' or 'false'. Provided: '${param_value}'"
    exit 1
  fi
  print_info "${param_name} is a valid boolean: '${param_value}'."
}

# Validate that a parameter value is a positive integer
# Arguments:
#   $1 - Parameter name
#   $2 - Parameter value
# Exits:
#   If the parameter value is not a positive integer
function validate_positive_integer() {
  local param_name="${1}"
  local param_value="${2}"

  if ! [[ "${param_value}" =~ ^[0-9]+$ ]]; then
    print_error "${param_name} must be a positive integer. Provided: '${param_value}'"
    exit 1
  fi
  print_info "${param_name} is a valid positive integer: '${param_value}'."
}

# Validate that a parameter value is valid JSON
# Arguments:
#   $1 - Parameter name
#   $2 - Parameter value (JSON string)
# Exits:
#   If the parameter value is not valid JSON
function validate_json() {
  local param_name="${1}"
  local param_value="${2}"

  if ! echo "${param_value}" | jq . > /dev/null 2>&1; then
    print_error "${param_name} must be a valid JSON string. Provided: '${param_value}'"
    exit 1
  fi
  print_info "${param_name} is a valid JSON string."
}

# Validate that a file exists
# Arguments:
#   $1 - Parameter name
#   $2 - File path
# Exits:
#   If the file does not exist
function validate_file_exists() {
  local param_name="${1}"
  local file_path="${2}"

  if [[ ! -f "${file_path}" ]]; then
    print_error "${param_name} file does not exist: '${file_path}'"
    exit 1
  fi
  print_info "${param_name} file exists: '${file_path}'."
}