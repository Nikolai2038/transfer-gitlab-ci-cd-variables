#!/bin/bash

# Fail command if any of pipeline blocks fail
set -o pipefail || exit "$?"

# Checks, if all required tools are installed.
# Returns 0 if all required tools are installed, otherwise returns 1.
#
# Usage: check_requirements
function check_requirements() {
  if ! which curl &> /dev/null; then
    echo '"curl" is not installed!' >&2
    return 1
  fi

  if ! which jq &> /dev/null; then
    echo '"jq" is not installed!' >&2
    return 1
  fi

  if ! which sed &> /dev/null; then
    echo '"sed" is not installed!' >&2
    return 1
  fi

  return 0
}

# Prints project ID.
#
# Usage: get_project_id <gitlab_hostname> <gitlab_project_url> <gitlab_api_token> [curl_arg]...
function get_project_id() {
  if [ "$#" -lt 3 ]; then
    echo "Usage: ${FUNCNAME[0]} <gitlab_hostname> <gitlab_project_url> <gitlab_api_token> [curl_arg]..." >&2
    return 1
  fi

  local gitlab_hostname="${1}" && { shift || true; }
  local gitlab_project_url="${1}" && { shift || true; }
  local gitlab_api_token="${1}" && { shift || true; }

  echo "Extracting project name from the project URL \"${gitlab_project_url}\"..." >&2
  local project_name
  project_name="${gitlab_project_url##*/}" || return "$?"
  if [ -z "${project_name}" ]; then
    echo "Extracting project name from the project URL \"${gitlab_project_url}\": failed!" >&2
    return 1
  fi
  echo "Extracting project name from the project URL \"${gitlab_project_url}\": success!" >&2
  echo "Project name: ${project_name}" >&2

  echo "Getting projects info..." >&2
  local projects_info
  projects_info="$(curl --header "PRIVATE-TOKEN: ${gitlab_api_token}" "${@}" "${gitlab_hostname}/api/v4/projects?search=${project_name}")" || return "$?"
  if [ -z "${projects_info}" ]; then
    echo "Getting projects info: failed!" >&2
    return 1
  fi
  echo "Getting projects info: success!" >&2

  echo "Getting project info..." >&2
  local project_info
  project_info="$(echo "${projects_info}" | jq -r ".[] | select(.web_url == \"${gitlab_project_url}\")")" || return "$?"
  if [ -z "${project_info}" ]; then
    echo "Getting project info: failed!" >&2
    return 1
  fi
  echo "Getting project info: success!" >&2

  echo "Extracting project ID from the project info..." >&2
  local project_id
  project_id="$(echo "${project_info}" | jq -r '.id')" || return "$?"
  if [ -z "${project_id}" ]; then
    echo "Extracting project ID from the project info: failed!" >&2
    return 1
  fi
  echo "Extracting project ID from the project info: success!" >&2

  echo "${project_id}"
}

# Transfers GitLab CI/CD variables from one project to another.
#
# Usage: transfer_gitlab_ci_cd_variables [--proxy <proxy_url>] <gitlab_project_1_url> <gitlab_project_1_api_token> <gitlab_project_2_url> <gitlab_project_2_api_token>
function transfer_gitlab_ci_cd_variables() {
  local proxy
  if [ "${1}" == "--proxy" ]; then
    shift || true
    proxy="${1}" && { shift || true; }
  fi

  if [ "$#" -ne 4 ]; then
    echo "Usage: ${FUNCNAME[0]} [--proxy <proxy_url>] <gitlab_project_1_url> <gitlab_project_1_api_token> <gitlab_project_2_url> <gitlab_project_2_api_token>" >&2
    return 1
  fi

  local gitlab_project_1_url="${1}" && { shift || true; }
  local gitlab_project_1_api_token="${1}" && { shift || true; }
  local gitlab_project_2_url="${1}" && { shift || true; }
  local gitlab_project_2_api_token="${1}" && { shift || true; }

  check_requirements || return "$?"

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
  )
  if [ -n "${proxy}" ]; then
    curl_extra_args+=("--proxy" "${proxy}")
  fi

  # Arguments for "curl" commands to first GitLab
  declare -a curl_extra_args_for_gitlab_1=(
    "${curl_extra_args[@]}"
    --header "PRIVATE-TOKEN: ${gitlab_project_1_api_token}"
  )
  # Arguments for "curl" commands to second GitLab
  declare -a curl_extra_args_for_gitlab_2=(
    "${curl_extra_args[@]}"
    --header "PRIVATE-TOKEN: ${gitlab_project_2_api_token}"
  )

  echo "Extracting GitLab hostname 1 from \"${gitlab_project_1_url}\"..." >&2
  local gitlab_hostname_1
  gitlab_hostname_1="$(echo "${gitlab_project_1_url}" | sed -E 's#^(https?://[^/]+)/.*$#\1#')" || return "$?"
  if [ -z "${gitlab_hostname_1}" ]; then
    echo "Extracting GitLab hostname 1 from \"${gitlab_project_1_url}\": failed!" >&2
    return 1
  fi
  echo "Extracting GitLab hostname 1 from \"${gitlab_project_1_url}\": success!" >&2
  echo "GitLab hostname 1: ${gitlab_hostname_1}" >&2

  echo "Extracting GitLab hostname 2 from \"${gitlab_project_2_url}\"..." >&2
  local gitlab_hostname_2
  gitlab_hostname_2="$(echo "${gitlab_project_2_url}" | sed -E 's#^(https?://[^/]+)/.*$#\1#')" || return "$?"
  if [ -z "${gitlab_hostname_2}" ]; then
    echo "Extracting GitLab hostname 2 from \"${gitlab_project_2_url}\": failed!" >&2
    return 1
  fi
  echo "Extracting GitLab hostname 2 from \"${gitlab_project_2_url}\": success!" >&2
  echo "GitLab hostname 2: ${gitlab_hostname_2}" >&2

  local project_id_1
  project_id_1="$(get_project_id "${gitlab_hostname_1}" "${gitlab_project_1_url}" "${gitlab_project_1_api_token}" "${curl_extra_args[@]}")" || return "$?"
  echo "Project 1 ID: ${project_id_1}"

  local project_id_2
  project_id_2="$(get_project_id "${gitlab_hostname_2}" "${gitlab_project_2_url}" "${gitlab_project_2_api_token}" "${curl_extra_args[@]}")" || return "$?"
  echo "Project 2 ID: ${project_id_2}"

  local is_all_pages_parsed=0

  local page=1

  # GitLab allows max 100 items per page
  local per_page=100

  while ((!is_all_pages_parsed)); do
    local project_api_1
    project_api_1="${gitlab_hostname_1}/api/v4/projects/${project_id_1}/variables?per_page=${per_page}&page=${page}"

    echo "Creating temp file for headers..." >&2
    local project_1_headers_filename
    project_1_headers_filename="$(mktemp --suffix "_project_1_headers.txt")" || return "$?"
    echo "Creating temp file for headers: success!" >&2
    echo "Temp file for headers: ${project_1_headers_filename}" >&2

    # Clear temp file for headers.
    function clear_temp_file() {
      echo "Clearing temp file for headers..." >&2
      rm "${project_1_headers_filename}" || return "$?"
      echo "Clearing temp file for headers: success!" >&2
    }
    # Add return handler - To clear temp file for headers (only on first return after this)
    trap "clear_temp_file; trap - RETURN" RETURN

    echo "Getting project 1 CI/CD variables..." >&2
    local project_1_ci_cd_variables
    project_1_ci_cd_variables="$(curl "${curl_extra_args_for_gitlab_1[@]}" --dump-header "${project_1_headers_filename}" "${project_api_1}")" || return "$?"
    if [ -z "${project_1_ci_cd_variables}" ]; then
      echo "Getting project 1 CI/CD variables: failed" >&2
      return 1
    fi
    echo "Getting project 1 CI/CD variables: success!" >&2

    echo "Getting total pages from headers..." >&2
    local total_pages
    total_pages="$(sed -En 's/^x-total-pages: ([0-9]+)\s+$/\1/p' "${project_1_headers_filename}")" || return "$?"
    if [ -z "${total_pages}" ]; then
      echo "Getting total pages from headers: failed!" >&2
      return 1
    fi
    echo "Getting total pages from headers: success!" >&2
    echo "Total pages: ${total_pages}" >&2

    # Clear return handler
    trap - RETURN
    clear_temp_file || return "$?"

    local variables_count
    variables_count="$(echo "${project_1_ci_cd_variables}" | jq 'length')" || return "$?"
    if [ -z "${variables_count}" ]; then
      echo "Failed to extract variables count!" >&2
      return 1
    fi

    local variable_id_on_page
    for ((variable_id_on_page = 0; variable_id_on_page < variables_count; variable_id_on_page++)); do
      local variable
      variable="$(echo "${project_1_ci_cd_variables}" | jq ".[${variable_id_on_page}]")" || return "$?"

      local variable_key
      variable_key="$(echo "${variable}" | jq -r '.key')" || return "$?"

      local variable_value
      variable_value="$(echo "${variable}" | jq -r '(.value // "")')" || return "$?"

      local variable_protected
      variable_protected="$(echo "${variable}" | jq -r '.protected')" || return "$?"

      local variable_masked
      variable_masked="$(echo "${variable}" | jq -r '.masked')" || return "$?"

      local variable_hidden
      variable_hidden="$(echo "${variable}" | jq -r '.hidden')" || return "$?"

      local variable_raw
      variable_raw="$(echo "${variable}" | jq -r '.raw')" || return "$?"

      local variable_environment_scope
      variable_environment_scope="$(echo "${variable}" | jq -r '.environment_scope')" || return "$?"

      local variable_description
      variable_description="$(echo "${variable}" | jq -r '(.description // "")')" || return "$?"

      # Check if variable exists
      if curl "${curl_extra_args_for_gitlab_2[@]}" --head "${gitlab_hostname_2}/api/v4/projects/${project_id_2}/variables/${variable_key}?filter%5Benvironment_scope%5D=${variable_environment_scope}" &> /dev/null; then
        echo "Variable \"${variable_key}\" already exists in the second project for scope \"${variable_environment_scope}\" - skipping it" >&2
        continue
      fi

      # Create variable
      echo "Creating variable \"${variable_key}\" in the second project for scope \"${variable_environment_scope}\"..." >&2
      curl "${curl_extra_args_for_gitlab_2[@]}" --request POST "${gitlab_hostname_2}/api/v4/projects/${project_id_2}/variables" \
        --form "key=${variable_key}" \
        --form "value=${variable_value}" \
        --form "protected=${variable_protected}" \
        --form "masked=${variable_masked}" \
        --form "hidden=${variable_hidden}" \
        --form "raw=${variable_raw}" \
        --form "environment_scope=${variable_environment_scope}" \
        --form "description=${variable_description}" \
        > /dev/null || return "$?"
      echo "Creating variable \"${variable_key}\" in the second project for scope \"${variable_environment_scope}\": success!" >&2
    done

    echo "Variables page ${page}/${total_pages} parsed (${per_page} variables per page)!" >&2

    if ((page < total_pages)); then
      ((page++))
    else
      is_all_pages_parsed=1
    fi
  done

  echo "All done!" >&2
}

transfer_gitlab_ci_cd_variables "$@" || exit "$?"
