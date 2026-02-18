#!/usr/bin/env bash

set -eo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/../common/common.sh"

#===============================================================
# GLOBAL VARIABLES
#===============================================================
RETURN_CODE_ERROR=1
RETURN_CODE_SUCCESS=0

#===============================================================
# FUNCTION: generate_iam_bearer_token
# DESCRIPTION: Generates an IBM Cloud IAM bearer token from an API key.
#
# ENVIRONMENT VARIABLES:
#   - IBMCLOUD_API_KEY: IBM Cloud API key (required)
#   - IBMCLOUD_IAM_API_ENDPOINT: IBM Cloud IAM API endpoint (optional, defaults to https://iam.cloud.ibm.com)
#
# ARGUMENTS: n/a
#
# RETURNS:
#   0 - Success (token printed to stdout)
#   1 - Failure (error message printed to stderr)
#
# USAGE: IBMCLOUD_API_KEY=XXX; token=$(generate_iam_bearer_token)
#===============================================================
generate_iam_bearer_token() {
    local iam_cloud_endpoint="${IBMCLOUD_IAM_API_ENDPOINT:-"https://iam.cloud.ibm.com"}"
    local iam_endpoint="${iam_cloud_endpoint#https://}" # Removes https:// prefix if present
    local token_url="https://${iam_endpoint}/identity/token"

    # validate curl and jq are installed
    check_required_bins curl jq || return ${RETURN_CODE_ERROR}

    # validate IBMCLOUD_API_KEY is set
    check_env_vars IBMCLOUD_API_KEY || return ${RETURN_CODE_ERROR}

    # Make the API call to generate the token
    local response
    response=$(curl --silent \
      --connect-timeout 5 \
      --max-time 10 \
      --retry 3 \
      --retry-delay 2 \
      --retry-connrefused \
      --write-out "\n%{http_code}" \
      --request POST \
      --header "Content-Type: application/x-www-form-urlencoded" \
      --data "grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=${IBMCLOUD_API_KEY}" \
      "${token_url}")

    # Extract HTTP status code and response body
    local http_code
    http_code=$(echo "${response}" | tail -n1)
    local response_body
    response_body=$(echo "${response}" | sed '$d')

    # Check for HTTP errors
    if [[ "${http_code}" -ne 200 ]]; then
      echo "Error: Failed to generate IAM token (HTTP ${http_code})" >&2
      echo "${response_body}" >&2
      return ${RETURN_CODE_ERROR}
    fi

    # Check if response contains an error message
    local error_message
    error_message=$(echo "${response_body}" | jq -r '.errorMessage // empty' 2>/dev/null)
    if [[ -n "${error_message}" ]]; then
      echo "Error: ${error_message}" >&2
      return ${RETURN_CODE_ERROR}
    fi

    # Extract the access token
    local access_token
    access_token=$(echo "${response_body}" | jq -r '.access_token // empty' 2>/dev/null)

    if [[ -z "${access_token}" ]] || [[ "${access_token}" == "null" ]]; then
      echo "Error: Failed to extract access token from response" >&2
      echo "${response_body}" >&2
      return ${RETURN_CODE_ERROR}
    fi

    # Output the token
    echo "${access_token}"
    return "${RETURN_CODE_SUCCESS}"
}

_test() {
    local make_api_calls="${MAKE_API_CALLS:-false}"
    printf "%s\n\n" "Running tests.."

    # generate_iam_bearer_token (requires MAKE_API_CALLS=true to be set to run)
    # -----------------------------------
    if [ "${make_api_calls}" = true ]; then
      # IBMCLOUD_API_KEY must be set if MAKE_API_CALLS=true
      if ! check_env_vars IBMCLOUD_API_KEY; then
        echo "IBMCLOUD_API_KEY must be set if MAKE_API_CALLS=true" >&2
        exit ${RETURN_CODE_ERROR}
      fi

      # - Test success (requires IBMCLOUD_API_KEY to be set)
      printf "%s\n" "Running 'generate_iam_bearer_token'"
      rc=${RETURN_CODE_SUCCESS}
      generate_iam_bearer_token >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test invalid apikey
      printf "%s\n" "Running 'IBMCLOUD_API_KEY=123; generate_iam_bearer_token'"
      rc=${RETURN_CODE_SUCCESS}
      IBMCLOUD_API_KEY=123; generate_iam_bearer_token >/dev/null 2>&1 || rc=$?
      assert_fail "${rc}"
      printf "%s\n\n" "✅ PASS"
    fi

    echo "✅ All tests passed!"
}

main() {
    _test
}

#===============================================================
# Determine if the script is being sourced or executed (run).
#===============================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    # This script is being run.
    __name__="__main__"
else
    # This script is being sourced.
    __name__="__source__"
fi

# Only run `main` if this script is being **run**, NOT sourced (imported).
if [ "$__name__" = "__main__" ]; then
    main "$@"
fi
