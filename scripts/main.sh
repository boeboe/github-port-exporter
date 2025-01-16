#!/usr/bin/env bash
# sync-code-scanning-alerts.sh - Script to orchestrate the GitHub-to-Port export process
# shellcheck disable=SC1091

set -euo pipefail
trap 'echo "[ERROR] Script failed at line $LINENO with exit code $? (last command: $BASH_COMMAND)"' ERR

# Source shared functions
source "${SCRIPTS_DIR}/functions/logging.sh"
source "${SCRIPTS_DIR}/functions/validation.sh"

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
    echo "[INFO] Starting GitHub-to-Port export process..."

    # Fetch Code Scanning Alerts from GitHub API
    echo "[INFO] Fetching Code Scanning Alerts from GitHub..."
    PAGE=1
    PER_PAGE=100
    TOTAL_CODE_ALERTS=()
    while true; do
        RESPONSE=$(curl -s -w "%{http_code}" -X GET \
            -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${GITHUB_REPOSITORY}/code-scanning/alerts?ref=refs/tags/${INPUT_VERSION}&per_page=${PER_PAGE}&page=${PAGE}")
        HTTP_STATUS=$(echo "${RESPONSE}" | tail -n1)
        RESPONSE_BODY=$(echo "${RESPONSE}" | sed '$d')
        if [ "$HTTP_STATUS" -ne 200 ]; then
            echo "[ERROR] Non-2XX response code: ${HTTP_STATUS}, exiting loop."
            break
        fi
        ALERTS=$(echo "${RESPONSE_BODY}" | jq '.[]')
        if [ -z "${ALERTS}" ]; then break; fi
        TOTAL_CODE_ALERTS+=("${ALERTS}")
        PAGE=$((PAGE + 1))
    done
    echo "${TOTAL_CODE_ALERTS[@]}" | jq -s '.' > code_scanning_alerts.json

    # Fetch Dependabot Alerts from GitHub API
    echo "[INFO] Fetching Dependabot Alerts from GitHub..."
    PAGE=1
    PER_PAGE=100
    TOTAL_DEPENDABOT_ALERTS=()
    while true; do
        RESPONSE=$(curl -s -w "%{http_code}" -X GET \
            -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${GITHUB_REPOSITORY}/dependabot/alerts?ref=refs/tags/${INPUT_VERSION}&per_page=${PER_PAGE}&page=${PAGE}")
        HTTP_STATUS=$(echo "${RESPONSE}" | tail -n1)
        RESPONSE_BODY=$(echo "${RESPONSE}" | sed '$d')
        if [ "${HTTP_STATUS}" -ne 200 ]; then
            echo "[ERROR] Non-2XX response code: ${HTTP_STATUS}, exiting loop."
            break
        fi
        ALERTS=$(echo "${RESPONSE_BODY}" | jq '.[]')
        if [ -z "${ALERTS}" ]; then break; fi
        if [ "$(echo "$RESPONSE_BODY" | jq 'length')" -lt "${PER_PAGE}" ]; then
            TOTAL_DEPENDABOT_ALERTS+=("${ALERTS}")
            break
        fi
        TOTAL_DEPENDABOT_ALERTS+=("${ALERTS}")
        PAGE=$((PAGE + 1))
    done
    echo "${TOTAL_DEPENDABOT_ALERTS[@]}" | jq -s '.' > dependabot_alerts.json

    # Fetch Dependencies from GitHub API
    echo "[INFO] Fetching Dependencies from GitHub..."
    curl -s -X GET \
        -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/dependency-graph/sbom" \
        -o sbom.json

    # Authenticate with Port API
    echo "[INFO] Authenticating with Port API..."
    PORT_ACCESS_TOKEN=$(curl -s --location --request POST 'https://api.getport.io/v1/auth/access_token' \
        --header 'Content-Type: application/json' \
        --data-raw "{
            \"clientId\": \"${INPUT_PORT_CLIENT_ID}\",
            \"clientSecret\": \"${INPUT_PORT_CLIENT_SECRET}\"
        }" | jq -r '.accessToken')
    echo "::add-mask::$PORT_ACCESS_TOKEN"
    echo "[INFO] Successfully authenticated with Port API."

    # Transform and Map JSON Data for Port
    echo "[INFO] Transforming Code Scanning Alerts..."
    jq '[.[] | {
        identifier: .rule.id,
        icon: "vulnerability",
        blueprint: "code_scanning_alert",
        properties: {
            severity: (.rule.security_severity_level | if type == "string" then ascii_upcase else "LOW" end),
            url: .html_url,
            description: .rule.full_description,
            security_tool: .tool.name
        }
    }]' < code_scanning_alerts.json > code_scanning_alert_entities.json

    echo "[INFO] Transforming Dependabot Alerts..."
    jq '[.[] | {
        identifier: .security_advisory.cve_id,
        icon: "vulnerability",
        blueprint: "dependabot_alert",
        properties: {
            severity: (.security_advisory.severity | if type == "string" then ascii_upcase else "LOW" end),
            url: .html_url,
            description: .security_advisory.description
        }
    }]' < dependabot_alerts.json > dependabot_alert_entities.json

    echo "[INFO] Transforming Dependencies..."
    jq '[.sbom.packages[] | {
        identifier: .name,
        title: .name,
        icon: "dependabot",
        blueprint: "dependency",
        properties: {
            version: .versionInfo
        }
    }]' < sbom.json > dependency_entities.json

    # Upsert Data to Port
    echo "[INFO] Upserting Code Scanning Alerts to Port..."
    while IFS= read -r entity; do
        curl -s --location --request POST "https://api.getport.io/v1/blueprints/code_scanning_alert/entities?upsert=true" \
            --header "Authorization: Bearer ${PORT_ACCESS_TOKEN}" \
            --header "Content-Type: application/json" \
            --data-raw "$entity" \
            --parallel \
            --parallel-max 20 &
    done < <(jq -c '.[]' code_scanning_alert_entities.json)
    wait

    echo "[INFO] Upserting Dependabot Alerts to Port..."
    while IFS= read -r entity; do
        curl -s --location --request POST "https://api.getport.io/v1/blueprints/dependabot_alert/entities?upsert=true" \
            --header "Authorization: Bearer ${PORT_ACCESS_TOKEN}" \
            --header "Content-Type: application/json" \
            --data-raw "$entity" \
            --parallel \
            --parallel-max 20 &
    done < <(jq -c '.[]' dependabot_alert_entities.json)
    wait

    echo "[INFO] Upserting Dependencies to Port..."
    while IFS= read -r entity; do
        curl -s --location --request POST "https://api.getport.io/v1/blueprints/dependency/entities?upsert=true" \
            --header "Authorization: Bearer ${PORT_ACCESS_TOKEN}" \
            --header "Content-Type: application/json" \
            --data-raw "$entity" \
            --parallel \
            --parallel-max 20 &
    done < <(jq -c '.[]' dependency_entities.json)
    wait

    # Prepare Container Image JSON
    echo "[INFO] Preparing Container Image JSON..."
    DEPENDENCIES=$(jq -r '[.[] | .identifier]' < dependency_entities.json)
    CODE_SCANNING_ALERTS=$(jq -r '[.[] | .identifier]' < code_scanning_alert_entities.json)
    DEPENDABOT_ALERTS=$(jq -r '[.[] | .identifier]' < dependabot_alert_entities.json)
    jq -n --arg identifier "${INPUT_APPLICATION}:${INPUT_VERSION}" \
        --arg title "${INPUT_APPLICATION}:${INPUT_VERSION}" \
        --arg blueprint "container_image" \
        --arg version "${INPUT_VERSION}" \
        --argjson dependencies "${DEPENDENCIES}" \
        --argjson code_scanning_alerts "${CODE_SCANNING_ALERTS}" \
        --argjson dependabot_alerts "${DEPENDABOT_ALERTS}" '{
            identifier: $identifier,
            title: $title,
            blueprint: $blueprint,
            properties: {
                version: $version
            },
            relations: {
                dependencies: $dependencies,
                code_scanning_alerts: $code_scanning_alerts,
                dependabot_alerts: $dependabot_alerts
            }
        }' > container_image.json

    echo "[INFO] Upserting Container Image to Port..."
    curl -s --location --request POST "https://api.getport.io/v1/blueprints/container_image/entities?upsert=true" \
        --header "Authorization: Bearer ${PORT_ACCESS_TOKEN}" \
        --header "Content-Type: application/json" \
        --data-raw "$(cat container_image.json)"

    echo "[INFO] Updating Port App with Container Image..."
    EXISTING_CONTAINER_IMAGES=$(curl -s --location --request GET "https://api.getport.io/v1/blueprints/app/entities/${INPUT_APPLICATION}" \
        --header "Authorization: Bearer ${PORT_ACCESS_TOKEN}" | jq -r '.entity.relations.container_images')
    UPDATED_CONTAINER_IMAGES=$(echo "${EXISTING_CONTAINER_IMAGES}" | jq -c --arg new_image "${INPUT_APPLICATION}:${INPUT_VERSION}" '. + [$new_image]')
    curl -s --location --request PATCH "https://api.getport.io/v1/blueprints/app/entities/${INPUT_APPLICATION}" \
        --header "Authorization: Bearer ${PORT_ACCESS_TOKEN}" \
        --header "Content-Type: application/json" \
        --data-raw "{
            \"relations\": {
                \"container_images\": ${UPDATED_CONTAINER_IMAGES}
            }
        }"

    echo "[INFO] GitHub-to-Port export process completed successfully."
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