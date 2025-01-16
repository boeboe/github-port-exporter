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
    local response
    local access_token

    # Log info messages to stderr
    print_info "Authenticating with Port API..." >&2

    # Perform the API call to get the access token
    response=$(curl -s --location --request POST 'https://api.getport.io/v1/auth/access_token' \
        --header 'Content-Type: application/json' \
        --data-raw "{
            \"clientId\": \"${port_client_id}\",
            \"clientSecret\": \"${port_client_secret}\"
        }")
    access_token=$(echo "${response}" | jq -r '.accessToken')

    # Check if the access token was successfully retrieved
    if [[ -z "${access_token}" || "${access_token}" == "null" ]]; then
        print_error "Failed to authenticate with Port API. Response: ${response}" >&2
        exit 1
    fi

    # Log success messages to stderr
    print_success "Successfully authenticated with Port API." >&2

    # Output the access token to stdout
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

    print_info "Uploading ${entity_type} entities to Port..."
    while IFS= read -r entity; do
        curl -s --location --request POST "https://api.getport.io/v1/blueprints/${entity_type}/entities?upsert=true" \
            --header "Authorization: Bearer ${access_token}" \
            --header "Content-Type: application/json" \
            --data-raw "${entity}" \
            --parallel \
            --parallel-max 20 &
    done < <(jq -c '.[]' "${json_file}")
    wait
    print_success "Successfully uploaded ${entity_type} entities to Port."
}

# Upload code scanning alerts to Port
# Arguments:
#   $1 - Access token
#   $2 - Path to the JSON file containing code scanning alert entities
function upload_code_scanning_alerts() {
    upload_to_port "$1" "code_scanning_alert" "$2"
}

# Upload Dependabot alerts to Port
# Arguments:
#   $1 - Access token
#   $2 - Path to the JSON file containing Dependabot alert entities
function upload_dependabot_alerts() {
    upload_to_port "$1" "dependabot_alert" "$2"
}

# Upload dependencies to Port
# Arguments:
#   $1 - Access token
#   $2 - Path to the JSON file containing dependency entities
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
    curl -s --location --request POST "https://api.getport.io/v1/blueprints/container_image/entities?upsert=true" \
        --header "Authorization: Bearer ${access_token}" \
        --header "Content-Type: application/json" \
        --data-raw "$(cat "${container_image_file}")"
    print_success "Successfully uploaded container image to Port."
}

# Update Port application with the new container image
# Arguments:
#   $1 - Access token
#   $2 - Application identifier
#   $3 - Version identifier for the container image
function update_port_app_with_container_image() {
    local access_token="$1"
    local application_id="$2"
    local container_image_identifier="$3"

    print_info "Updating Port application ${application_id} with container image ${container_image_identifier}..."
    local existing_images
    local updated_images

    existing_images=$(curl -s --location --request GET "https://api.getport.io/v1/blueprints/app/entities/${application_id}" \
        --header "Authorization: Bearer ${access_token}" \
        --header "Content-Type: application/json" | jq -r '.entity.relations.container_images')
    updated_images=$(echo "${existing_images}" | jq -c --arg new_image "${container_image_identifier}" '. + [$new_image]')

    curl -s --location --request PATCH "https://api.getport.io/v1/blueprints/app/entities/${application_id}" \
        --header "Authorization: Bearer ${access_token}" \
        --header "Content-Type: application/json" \
        --data-raw "{
            \"relations\": {
                \"container_images\": ${updated_images}
            }
        }"
    print_success "Successfully updated application ${application_id} with container image ${container_image_identifier}."
}