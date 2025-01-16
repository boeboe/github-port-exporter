#!/usr/bin/env bash
# transform.sh - Functions to transform and map JSON data for Port.
# shellcheck disable=SC1091

# Transform Code Scanning Alerts for Port
function transform_code_scanning_alerts() {
  local input_file="${1}"
  local output_file="${2}"

  print_info "Transforming Code Scanning Alerts from ${input_file} to ${output_file}..."

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
  }]' < "${input_file}" > "${output_file}"

  local alert_count
  alert_count=$(jq 'length' "${output_file}")
  print_success "Transformed ${alert_count} Code Scanning Alerts to file ${output_file}."
}

# Transform Dependabot Alerts for Port
function transform_dependabot_alerts() {
  local input_file="${1}"
  local output_file="${2}"

  print_info "Transforming Dependabot Alerts from ${input_file} to ${output_file}..."

  jq '[.[] | {
    identifier: .security_advisory.cve_id,
    icon: "vulnerability",
    blueprint: "dependabot_alert",
    properties: {
      severity: (.security_advisory.severity | if type == "string" then ascii_upcase else "LOW" end),
      url: .html_url,
      description: .security_advisory.description
    }
  }]' < "${input_file}" > "${output_file}"

  local alert_count
  alert_count=$(jq 'length' "${output_file}")
  print_success "Transformed ${alert_count} Dependabot Alerts to file ${output_file}."
}

# Transform Dependencies (SBOM) for Port
function transform_dependencies() {
  local input_file="${1}"
  local output_file="${2}"

  print_info "Transforming Dependencies (SBOM) from ${input_file} to ${output_file}..."

  jq '[.sbom.packages[] | {
    identifier: .name,
    title: .name,
    icon: "dependabot",
    blueprint: "dependency",
    properties: {
      version: .versionInfo
    }
  }]' < "${input_file}" > "${output_file}"

  local dependency_count
  dependency_count=$(jq 'length' "${output_file}")
  print_success "Transformed ${dependency_count} Dependencies (SBOM) to file ${output_file}."
}

# Transform Container Image JSON for Port
function transform_container_image_json() {
  local application="${1}"
  local version="${2}"
  local dependency_file="${3}"
  local code_scanning_alerts_file="${4}"
  local dependabot_alerts_file="${5}"
  local output_file="${6}"

  print_info "Preparing Container Image JSON..."

  local dependencies
  dependencies=$(jq -r '[.[] | .identifier]' < "${dependency_file}")
  local code_scanning_alerts
  code_scanning_alerts=$(jq -r '[.[] | .identifier]' < "${code_scanning_alerts_file}")
  local dependabot_alerts
  dependabot_alerts=$(jq -r '[.[] | .identifier]' < "${dependabot_alerts_file}")

  jq -n --arg identifier "${application}:${version}" \
    --arg title "${application}:${version}" \
    --arg blueprint "container_image" \
    --arg version "${version}" \
    --argjson dependencies "${dependencies}" \
    --argjson code_scanning_alerts "${code_scanning_alerts}" \
    --argjson dependabot_alerts "${dependabot_alerts}" '{
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
    }' > "${output_file}"

  print_success "Container Image JSON prepared and written to ${output_file}."
}