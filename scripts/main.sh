#!/usr/bin/env bash
# main.sh - Script to orchestrate the GitHub-to-Port export process
# shellcheck disable=SC1091

set -euo pipefail
trap 'echo "[ERROR] Script failed at line $LINENO with exit code $? (last command: $BASH_COMMAND)"' ERR

# Source shared functions
source "${SCRIPTS_DIR}/functions/logging.sh"
source "${SCRIPTS_DIR}/functions/validation.sh"
source "${SCRIPTS_DIR}/functions/github.sh"
source "${SCRIPTS_DIR}/functions/transform.sh"
source "${SCRIPTS_DIR}/functions/port.sh"

# Usage message
function usage() {
  local usage_message="Usage: ${0} [ACTION] [ARGUMENTS]\n"
  usage_message+="Action:\n"
  usage_message+="  validate-inputs\n"
  usage_message+="  execute\n"
  usage_message+="Arguments:\n"
  usage_message+="  --version <string>\n"
  usage_message+="  --github-token <string>\n"
  usage_message+="  --port-client-id <string>\n"
  usage_message+="  --port-client-secret <string>\n"
  usage_message+="  --application <string>\n"
  print_info "$usage_message"
  exit 1
}

# Parse arguments
function parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "${1}" in
      validate-inputs)
        ACTION="validate_inputs"
        shift
        ;;
      execute)
        ACTION="execute"
        shift
        ;;
      --version)
        INPUT_VERSION="${2}"
        shift 2
        ;;
      --github-token)
        INPUT_GITHUB_TOKEN="${2}"
        shift 2
        ;;
      --port-client-id)
        INPUT_PORT_CLIENT_ID="${2}"
        shift 2
        ;;
      --port-client-secret)
        INPUT_PORT_CLIENT_SECRET="${2}"
        shift 2
        ;;
      --application)
        INPUT_APPLICATION="${2}"
        shift 2
        ;;
      *)
        print_error "Unknown argument: ${1}"
        usage
        ;;
    esac
  done

  if [[ -z "${ACTION:-}" ]]; then
    print_error "No action specified (e.g., validate-inputs or execute)."
    usage
  fi
}

# Validate inputs
function validate_inputs() {
  print_info "Validating inputs..."
  validate_set "INPUT_VERSION" "${INPUT_VERSION:-}"
  validate_set "INPUT_GITHUB_TOKEN" "${INPUT_GITHUB_TOKEN:-}"
  validate_set "INPUT_PORT_CLIENT_ID" "${INPUT_PORT_CLIENT_ID:-}"
  validate_set "INPUT_PORT_CLIENT_SECRET" "${INPUT_PORT_CLIENT_SECRET:-}"
  validate_set "INPUT_APPLICATION" "${INPUT_APPLICATION:-}"
  print_success "Inputs validated successfully."
}

# Execute the main operation
function execute() {
  print_info "Starting GitHub-to-Port export process..."

  local code_scanning_alerts_file="code_scanning_alerts.json"
  local dependabot_alerts_file="dependabot_alerts.json"
  local sbom_file="sbom.json"
  local code_scanning_alerts_entities_file="code_scanning_alert_entities.json"
  local dependabot_alerts_entities_file="dependabot_alert_entities.json"
  local dependency_entities_file="dependency_entities.json"
  local container_image_file="container_image.json"

  # Fetch Code Scanning Alerts, Dependabot Alerts, and Dependencies from GitHub API
  fetch_code_scanning_alerts \
    "${INPUT_GITHUB_TOKEN}" \
    "${GITHUB_REPOSITORY}" \
    "${INPUT_VERSION}" \
    "${code_scanning_alerts_file}"
  fetch_dependabot_alerts \
    "${INPUT_GITHUB_TOKEN}" \
    "${GITHUB_REPOSITORY}" \
    "${INPUT_VERSION}" \
    "${dependabot_alerts_file}"
  fetch_dependencies \
    "${INPUT_GITHUB_TOKEN}" \
    "${GITHUB_REPOSITORY}" \
    "${sbom_file}"

  # Transform and Map JSON Data for Port
  transform_code_scanning_alerts "${code_scanning_alerts_file}" "${code_scanning_alerts_entities_file}"
  transform_dependabot_alerts "${dependabot_alerts_file}" "${dependabot_alerts_entities_file}"
  transform_dependencies "${sbom_file}" "${dependency_entities_file}"
  transform_container_image_json \
    "${INPUT_APPLICATION}" \
    "${INPUT_VERSION}" \
    "${dependency_entities_file}" \
    "${code_scanning_alerts_entities_file}" \
    "${dependabot_alerts_entities_file}" \
    "${container_image_file}"

  # Authenticate with Port API
  local port_access_token
  port_access_token=$(authenticate_with_port "${INPUT_PORT_CLIENT_ID}" "${INPUT_PORT_CLIENT_SECRET}")
  echo "::add-mask::${port_access_token}"

  # Upsert Data to Port
  upload_code_scanning_alerts "${port_access_token}" "${code_scanning_alerts_entities_file}"
  upload_dependabot_alerts "${port_access_token}" "${dependabot_alerts_entities_file}"
  upload_dependencies "${port_access_token}" "${dependency_entities_file}"
  upload_container_image "${port_access_token}" "${container_image_file}"

  # Update Port App with Container Image
  update_port_app_with_container_image \
    "${port_access_token}" \
    "${INPUT_APPLICATION}" \
    "${INPUT_APPLICATION}:${INPUT_VERSION}"

  print_success "GitHub-to-Port export process completed successfully."
  echo "success=true" >> "${GITHUB_OUTPUT}"
}

# Main logic
function main() {
  parse_arguments "$@"

  case "${ACTION}" in
    validate_inputs)
      validate_inputs
      ;;
    execute)
      execute
      ;;
    *)
      print_error "Unknown action: ${ACTION}"
      usage
      ;;
  esac
}

# Execute the main function with all arguments
main "$@"