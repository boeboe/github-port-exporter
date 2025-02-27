#!/usr/bin/env bash
# github.sh - Functions to interact with the GitHub API.
# shellcheck disable=SC1091

# Fetch Code Scanning Alerts
# Arguments:
#   $1 - GitHub token
#   $2 - Repository name (e.g., "owner/repo")
#   $3 - Version (ref) to filter alerts (e.g., "v1.0.0")
#   $4 - Path to the output file where alerts will be saved
function fetch_code_scanning_alerts() {
  local token="${1}"
  local repository="${2}"
  local version="${3}"
  local output_file="${4}"

  local page=1
  local per_page=100
  local total_code_alerts=()

  print_info "Fetching Code Scanning Alerts for repository ${repository} and version ${version}..."

  while true; do
    local response
    response=$(curl -s -w "\n%{http_code}" -X GET \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/${repository}/code-scanning/alerts?ref=refs/tags/${version}&per_page=${per_page}&page=${page}")
    
    local http_status
    http_status=$(echo "${response}" | tail -n1)
    local response_body
    response_body=$(echo "${response}" | sed '$d')

    if ! [[ "${http_status}" =~ ^2[0-9]{2}$ ]]; then
      print_error "Non-2XX response code: ${http_status}"
      print_error "Response body: ${response_body}"
      break
    fi

    local alerts
    alerts=$(echo "${response_body}" | jq '.[]')
    if [ -z "${alerts}" ]; then break; fi

    total_code_alerts+=("${alerts}")
    page=$((page + 1))
  done

  echo "${total_code_alerts[@]}" | jq -s '.' > "${output_file}"

  local alert_count
  alert_count=$(jq 'length' "${output_file}")
  print_success "Written ${alert_count} Code Scanning Alerts to file ${output_file}."
}

# Fetch Dependabot Alerts
# Arguments:
#   $1 - GitHub token
#   $2 - Repository name (e.g., "owner/repo")
#   $3 - Version (ref) to filter alerts (e.g., "v1.0.0")
#   $4 - Path to the output file where alerts will be saved
function fetch_dependabot_alerts() {
  local token="${1}"
  local repository="${2}"
  local version="${3}"
  local output_file="${4}"

  local page=1
  local per_page=100
  local total_dependabot_alerts=()

  print_info "Fetching Dependabot Alerts for repository ${repository} and version ${version}..."

  while true; do
    local response
    response=$(curl -s -w "\n%{http_code}" -X GET \
      -H "Authorization: Bearer ${token}" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/${repository}/dependabot/alerts?ref=refs/tags/${version}&per_page=${per_page}&page=${page}")
    
    local http_status
    http_status=$(echo "${response}" | tail -n1)
    local response_body
    response_body=$(echo "${response}" | sed '$d')

    if ! [[ "${http_status}" =~ ^2[0-9]{2}$ ]]; then
      print_error "Non-2XX response code: ${http_status}"
      print_error "Response body: ${response_body}"
      break
    fi

    local alerts
    alerts=$(echo "${response_body}" | jq '.[]')
    if [ -z "${alerts}" ]; then break; fi

    total_dependabot_alerts+=("${alerts}")
    page=$((page + 1))
  done

  echo "${total_dependabot_alerts[@]}" | jq -s '.' > "${output_file}"

  local alert_count
  alert_count=$(jq 'length' "${output_file}")
  print_success "Written ${alert_count} Dependabot Alerts to file ${output_file}."
}

# Fetch Dependencies (SBOM)
# Arguments:
#   $1 - GitHub token
#   $2 - Repository name (e.g., "owner/repo")
#   $3 - Path to the output file where the SBOM will be saved
function fetch_dependencies() {
  local token="${1}"
  local repository="${2}"
  local output_file="${3}"

  print_info "Fetching Dependencies (SBOM) for repository ${repository}..."

  local response
  response=$(curl -s -w "\n%{http_code}" -X GET \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${repository}/dependency-graph/sbom")
  
  local http_status
  http_status=$(echo "${response}" | tail -n1)
  local response_body
  response_body=$(echo "${response}" | sed '$d')

  if ! [[ "${http_status}" =~ ^2[0-9]{2}$ ]]; then
    print_error "Non-2XX response code: ${http_status}"
    print_error "Response body: ${response_body}"
    return 1
  fi

  echo "${response_body}" > "${output_file}"

  local alert_count
  dependency_count=$(jq '.sbom.packages | length' "${output_file}")
  print_success "Written ${dependency_count} dependencies (SBOM) to file ${output_file}."
}