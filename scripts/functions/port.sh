#!/usr/bin/env bash
# port.sh - Functions to interact with the Port API.
# shellcheck disable=SC1091

set -euo pipefail

# Authenticate with Port API and return the access token
# Arguments:
#   $1 - Port Client ID
#   $2 - Port Client Secret
# Outputs:
#   Access token for further interactions (to stdout)
function authenticate_with_port() {
  local port_client_id="$1"
  local port_client_secret="$2"

  print_info "Authenticating with Port API..." >&2

  local response
  response=$(curl -s -w "\n%{http_code}" --location -X POST \
    --header 'Content-Type: application/json' \
    --data-raw "{ \"clientId\": \"${port_client_id}\", \"clientSecret\": \"${port_client_secret}\" }" \
    'https://api.getport.io/v1/auth/access_token')

  local http_status
  http_status=$(echo "${response}" | tail -n1)
  local response_body
  response_body=$(echo "${response}" | sed '$d')

  if ! [[ "${http_status}" =~ ^2[0-9]{2}$ ]]; then
    print_error "Failed to authenticate with Port API. HTTP Status: ${http_status}" >&2
    print_error "Response body: ${response_body}" >&2
    exit 1
  fi

  local access_token
  access_token=$(echo "${response_body}" | jq -r '.accessToken')
  if [[ -z "${access_token}" || "${access_token}" == "null" ]]; then
    print_error "Failed to retrieve access token. Response: ${response_body}" >&2
    exit 1
  fi

  print_success "Successfully authenticated with Port API." >&2
  echo "${access_token}"
}

# Upload JSON entities to Port API
# Arguments:
#   $1 - Access token
#   $2 - Entity type (blueprint name)
#   $3 - Path to the JSON file containing entities
function upload_to_port() {
  local access_token="$1"
  local entity_type="$2"
  local json_file="$3"
  local output_dir="/tmp/${entity_type}_responses"
  local success_count=0
  local failure_count=0
  local parallel_limit=20
  local current_jobs=0

  if [[ ! -f "${json_file}" ]]; then
    print_error "JSON file for entity ${entity_type} not found: ${json_file}"
    exit 1
  fi

  mkdir -p "${output_dir}"
  print_info "Uploading ${entity_type} entities to Port..."

  while IFS= read -r entity; do
    {
      local unique_id
      local response_file
      unique_id=$(date +%s%N | shasum | head -c 32)
      response_file="${output_dir}/response_${unique_id}.txt"

      curl -s -w "\n%{http_code}" --location --request POST \
        "https://api.getport.io/v1/blueprints/${entity_type}/entities?upsert=true" \
        --header "Authorization: Bearer ${access_token}" \
        --header "Content-Type: application/json" \
        --data-raw "${entity}" >"${response_file}"
    } &

    current_jobs=$((current_jobs + 1))
    if [[ "${current_jobs}" -ge "${parallel_limit}" ]]; then
      wait -n
      current_jobs=$((current_jobs - 1))
    fi
  done < <(jq -c '.[]' "${json_file}")

  wait

  print_info "Analyzing ${entity_type} entity upload responses..."
  for response_file in "${output_dir}"/*.txt; do
    local http_status
    local response_body
    response_body=$(sed '$d' "${response_file}")
    http_status=$(tail -n1 "${response_file}")
    if [[ "${http_status}" =~ ^2[0-9]{2}$ ]]; then
      success_count=$((success_count + 1))
    else
      failure_count=$((failure_count + 1))
      print_error "Failed to upload a ${entity_type} entity. HTTP Status: ${http_status}"
      print_error "Response body: ${response_body}"
    fi
  done

  print_info "Upload ${entity_type} entities completed."
  print_info "Success: ${success_count}, Failures: ${failure_count}"

  if [[ "${failure_count}" -eq 0 ]]; then
    print_success "All ${success_count} ${entity_type} entities were uploaded successfully!"
  else
    print_error "Failed to upload ${failure_count} ${entity_type} entities."
    exit 1
  fi
}

# Upload code scanning alerts to Port
# Arguments:
#   $1 - Access token
#   $2 - Path to the JSON file containing code scanning alerts
function upload_code_scanning_alerts() {
  upload_to_port "$1" "code_scanning_alert" "$2"
}

# Upload Dependabot alerts to Port
# Arguments:
#   $1 - Access token
#   $2 - Path to the JSON file containing Dependabot alerts
function upload_dependabot_alerts() {
  upload_to_port "$1" "dependabot_alert" "$2"
}

# Upload dependencies to Port
# Arguments:
#   $1 - Access token
#   $2 - Path to the JSON file containing dependencies
function upload_dependencies() {
  upload_to_port "$1" "dependency" "$2"
}

# Upload container image data to Port
# Arguments:
#   $1 - Access token
#   $2 - Path to the JSON file containing the container image data
function upload_container_image() {
  local access_token="$1"
  local container_image_file="$2"

  print_info "Uploading container image to Port..."
  local response
  local http_status
  local response_body

  response=$(curl -s -w "\n%{http_code}" --location --request POST "https://api.getport.io/v1/blueprints/container_image/entities?upsert=true" \
    --header "Authorization: Bearer ${access_token}" \
    --header "Content-Type: application/json" \
    --data-raw "$(cat "${container_image_file}")")

  http_status=$(echo "${response}" | tail -n1)
  response_body=$(echo "${response}" | sed '$d')

  if ! [[ "${http_status}" =~ ^2[0-9]{2}$ ]]; then
    print_error "Failed to upload container image. HTTP Status: ${http_status}"
    print_error "Response body: ${response_body}"
    exit 1
  fi

  print_success "Successfully uploaded container image to Port."
}

# Update Port application with the new container image
# Arguments:
#   $1 - Access token
#   $2 - Application ID
#   $3 - Container image identifier
function update_port_app_with_container_image() {
  local access_token="$1"
  local application_id="$2"
  local container_image_identifier="$3"

  print_info "Updating Port application ${application_id} with container image ${container_image_identifier}..."
  local response
  local http_status
  local response_body

  response=$(curl -s -w "\n%{http_code}" --location --request GET "https://api.getport.io/v1/blueprints/app/entities/${application_id}" \
    --header "Authorization: Bearer ${access_token}" \
    --header "Content-Type: application/json")

  http_status=$(echo "${response}" | tail -n1)
  response_body=$(echo "${response}" | sed '$d')

  if ! [[ "${http_status}" =~ ^2[0-9]{2}$ ]]; then
    print_error "Failed to fetch existing container images. HTTP Status: ${http_status}"
    print_error "Response body: ${response_body}"
    exit 1
  fi

  local existing_images
  existing_images=$(echo "${response_body}" | jq -r '.entity.relations.container_images')
  local updated_images
  updated_images=$(echo "${existing_images}" | jq -c --arg new_image "${container_image_identifier}" '. + [$new_image]')

  response=$(curl -s -w "\n%{http_code}" --location --request PATCH "https://api.getport.io/v1/blueprints/app/entities/${application_id}" \
    --header "Authorization: Bearer ${access_token}" \
    --header "Content-Type: application/json" \
    --data-raw "{
      \"relations\": {
        \"container_images\": ${updated_images}
      }
    }")

  http_status=$(echo "${response}" | tail -n1)
  response_body=$(echo "${response}" | sed '$d')

  if ! [[ "${http_status}" =~ ^2[0-9]{2}$ ]]; then
    print_error "Failed to update Port application. HTTP Status: ${http_status}"
    print_error "Response body: ${response_body}"
    exit 1
  fi

  print_success "Successfully updated application ${application_id} with container image ${container_image_identifier}."
}