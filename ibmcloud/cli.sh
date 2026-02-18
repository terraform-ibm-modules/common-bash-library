#!/usr/bin/env bash

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/../common/common.sh"

#===============================================================
# GLOBAL VARIABLES
#===============================================================
RETURN_CODE_ERROR=1
RETURN_CODE_ERROR_INCORRECT_USAGE=2
RETURN_CODE_SUCCESS=0

#===============================================================
# FUNCTION: install_ibmcloud
# DESCRIPTION: Installs IBM Cloud CLI (ibmcloud)
#
# ENVIRONMENT VARIABLES:
#   - VERBOSE: If set to true, print verbose output (optional, defaults to false)
#
# ARGUMENTS:
#   - $1: version of ibmcloud to install (optional, defaults to latest)
#   - $2: location to install ibmcloud to (optional, defaults to /tmp)
#   - $3: if set to true, skips installation if ibmcloud is already detected (optional, defaults to true)
#   - $4: exact installer URL (optional, overrides automatic URL construction)
#
# RETURNS:
#   0 - Success (ibmcloud installation successful)
#   1 - Failure (ibmcloud installation failed)
#   2 - Failure (incorrect usage of function)
#
# USAGE: install_ibmcloud "latest" "/usr/local/bin" "true"
#===============================================================
install_ibmcloud() {

  local version=${1:-"latest"}
  local location=${2:-"/tmp"}
  local skip_if_detected=${3:-"true"}
  local link_to_binary=${4:-""}
  local verbose=${VERBOSE:-false}

  # Validate $3 arg is boolean
  if ! is_boolean "${skip_if_detected}"; then
    echo "Unsupported value detected for the 3rd argument. Only 'true' or 'false' is supported. Found: ${skip_if_detected}." >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # return 0 if ibmcloud already installed and skip_if_detected is true
  if [ "${skip_if_detected}" = "true" ]; then
    if check_required_bins ibmcloud; then
      if [ "${verbose}" = true ]; then
        echo "Found ibmcloud already installed. Taking no action."
      fi
      return ${RETURN_CODE_SUCCESS}
    fi
  fi

  # ensure curl, tar, gzip are installed
  check_required_bins curl tar gzip || return $?

  # If version is "latest", fetch the latest version number from GitHub
  if [ "${version}" = "latest" ]; then
    if [ "${verbose}" = true ]; then
      echo "Fetching latest IBM Cloud CLI version from GitHub..."
    fi

    # Fetch latest version from GitHub API
    set +e
    version=$(curl --silent \
      --connect-timeout 5 \
      --max-time 10 \
      --retry 3 \
      --retry-delay 2 \
      --retry-connrefused \
      --fail \
      "https://api.github.com/repos/IBM-Cloud/ibm-cloud-cli-release/releases/latest" \
      | grep '"tag_name":' \
      | sed -E 's/.*"v?([^"]+)".*/\1/')
    set -e

    # Return error if fetch fails
    if [ -z "${version}" ] || [ "${version}" = "null" ]; then
      echo "Error: Failed to fetch latest version from GitHub API. Please try again later, or specify an explicit version instead of 'latest'. Example: install_ibmcloud '2.41.0' '/usr/local/bin' 'true'" >&2
      return ${RETURN_CODE_ERROR}
    fi

    if [ "${verbose}" = true ]; then
      echo "Latest version determined: ${version}"
    fi
  fi

  # strip "v" prefix if it exists in version
  if [[ "${version}" == "v"* ]]; then
    version="${version#v}"
  fi

  # if no link to binary passed, determine the download link based on detected os and arch
  if [ -z "${link_to_binary}" ]; then
    # determine the OS
    local os="linux"
    if [[ ${OSTYPE} == 'darwin'* ]]; then
      os="macos"
    fi

    # determine the architecture
    local arch="amd64"
    if [[ ${OSTYPE} == 'darwin'* ]]; then
      arch=$(return_mac_architecture)
    fi

    # Build download URL with correct pattern:
    # - macOS AMD64: IBM_Cloud_CLI_{version}_macos.tgz (NO arch suffix)
    # - macOS ARM64: IBM_Cloud_CLI_{version}_macos_arm64.tgz
    # - Linux AMD64: IBM_Cloud_CLI_{version}_linux_amd64.tgz
    # - Linux ARM64: IBM_Cloud_CLI_{version}_linux_arm64.tgz
    if [[ "${os}" == "macos" ]] && [[ "${arch}" == "amd64" ]]; then
      # Special case: macOS Intel has NO arch suffix
      link_to_binary="https://download.clis.cloud.ibm.com/ibm-cloud-cli-dn/${version}/binaries/IBM_Cloud_CLI_${version}_${os}.tgz"
    else
      # All other cases: include arch suffix
      link_to_binary="https://download.clis.cloud.ibm.com/ibm-cloud-cli-dn/${version}/binaries/IBM_Cloud_CLI_${version}_${os}_${arch}.tgz"
    fi
  fi

  if [ "${verbose}" = true ]; then
    echo "Using download link: ${link_to_binary}"
  fi

  # use sudo if needed
  local arg=""
  if ! [ -w "${location}" ]; then
    echo "No write permission to ${location}. Using sudo..."
    arg=sudo
  fi

  # remove if already exists
  ${arg} rm -f "${location}/ibmcloud"

  # create temp directory
  local tmp_dir
  tmp_dir=$(mktemp -d)

  # download and extract
  set +e
  if ! curl --silent \
    --connect-timeout 5 \
    --max-time 20 \
    --retry 3 \
    --retry-delay 2 \
    --retry-connrefused \
    --fail \
    --show-error \
    --location \
    "${link_to_binary}" | tar -xz -C "${tmp_dir}"
  then
    echo "Failed to download ${link_to_binary}"
    rm -rf "${tmp_dir}"
    return ${RETURN_CODE_ERROR}
  fi
  set -e

  # move binary
  ${arg} mv "${tmp_dir}/IBM_Cloud_CLI/ibmcloud" "${location}/ibmcloud"
  ${arg} chmod +x "${location}/ibmcloud"

  rm -rf "${tmp_dir}"

  if [ "${verbose}" = true ]; then
    echo "Successfully completed installation to ${location}/ibmcloud"
  fi

  return ${RETURN_CODE_SUCCESS}
}

#===============================================================
# UNIT TESTS
#===============================================================
_test() {
    local make_api_calls="${MAKE_API_CALLS:-false}"
    printf "%s\n\n" "Running tests for ibmcloud/cli.sh..."

    # install_ibmcloud
    # -----------------------------------
    if [ "${make_api_calls}" = true ]; then
      # Check if ibmcloud already exists on $PATH
      local ibmcloud_installed=true
      check_required_bins ibmcloud || ibmcloud_installed=false

      # - Test installing ibmcloud using defaults (when it does not already exist)
      if [ ${ibmcloud_installed} = false ]; then
        printf "%s\n" "Running 'install_ibmcloud' (when ibmcloud does not already exists)"
        rc=${RETURN_CODE_SUCCESS}
        install_ibmcloud >/dev/null 2>&1 || rc=$?
        assert_pass "${rc}"
        printf "%s\n\n" "✅ PASS"
      fi

      # - Test installing it when ibmcloud already exists with default args (should be skipped)
      printf "%s\n" "Running 'install_ibmcloud' (when ibmcloud already exists - install will be skipped)"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test installing exact version to /tmp even if ibmcloud already detected on $PATH
      printf "%s\n" "Running 'install_ibmcloud 2.41.0 /tmp false'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud "2.41.0" "/tmp" "false" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
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
    __name__="__main__"
else
    __name__="__source__"
fi

if [ "${__name__}" = "__main__" ]; then
    main "$@"
fi
