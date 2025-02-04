#!/bin/bash

# Fail command if any of pipeline blocks fail
set -o pipefail || exit "$?"

# Usage: transfer_gitlab_ci_cd_variables [--proxy <proxy_url>] <gitlab_project_1_url> <gitlab_project_1_api_token> <gitlab_project_2_url> <gitlab_project_2_api_token>
function transfer_gitlab_ci_cd_variables() {
  local proxy
  if [ "${1}" == "--proxy" ]; then
    proxy="${2}" && { shift || true; }
    shift
  fi

  if [ "$#" -ne 4 ]; then
    echo "Usage: ${0} [--proxy <proxy_url>] <gitlab_project_1_url> <gitlab_project_1_api_token> <gitlab_project_2_url> <gitlab_project_2_api_token>" >&2
    return 1
  fi

  local gitlab_project_1_url="${1}" && { shift || true; }
  local gitlab_project_1_api_token="${1}" && { shift || true; }
  local gitlab_project_2_url="${1}" && { shift || true; }
  local gitlab_project_2_api_token="${1}" && { shift || true; }

  if ! which curl &> /dev/null; then
    echo '"curl" is not installed!' >&2
    return 1
  fi

  if ! which jq &> /dev/null; then
    echo '"jq" is not installed!' >&2
    return 1
  fi

  # Arguments for "curl" commands
  declare -a curl_extra_args=(
    # Follow redirects
    --location

    # Do not print progress and errors output
    --silent
    # Print errors output
    --show-error

    # Fail command if response code is not 200
    --fail

    --header "PRIVATE-TOKEN: ${gitlab_project_1_api_token}"
  )
  if [ -n "${proxy}" ]; then
    curl_extra_args+=("--proxy" "${proxy}")
  fi

  local gitlab_hostname
  gitlab_hostname="$(echo "${gitlab_project_1_url}" | sed -r 's#^https?://([^/]+)/.*$#\1#')" || return "$?"
  if [ -z "${gitlab_hostname}" ]; then
    echo "Failed to extract GitLab hostname from '${gitlab_project_1_url}'" >&2
    return 1
  fi

  local projects_info
  projects_info="$(curl "${curl_extra_args[@]}" "https://${gitlab_hostname}/api/v4/projects")" || return "$?"

  local project_info
  project_info="$(echo "${projects_info}" | jq -r ".[] | select(.web_url == \"${gitlab_project_1_url}\")")" || return "$?"

  local project_id
  project_id="$(echo "${project_info}" | jq -r '.id')" || return "$?"

  local project_api
  project_api="https://${gitlab_hostname}/api/v4/projects/${project_id}/variables"

  curl "${curl_extra_args[@]}" "${project_api}" | jq -r '.[] | .key, .value, ""' || return "$?"
}

transfer_gitlab_ci_cd_variables "$@" || exit "$?"
