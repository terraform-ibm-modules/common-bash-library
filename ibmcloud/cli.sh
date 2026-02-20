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
# FUNCTION: install_ibmcloud_plugin
# DESCRIPTION: Installs one or more IBM Cloud CLI plugins
#
# ENVIRONMENT VARIABLES:
#   - VERBOSE: If set to true, print verbose output (optional, defaults to false)
#
# ARGUMENTS:
#   - $1: comma-separated plugin name(s) (required). Can specify version using @ syntax.
#         Examples: "code-engine" or "container-service@1.0.506,secrets-manager@0.1.25"
#   - $2: custom directory for plugin installation (optional, uses latest if not specified)
#   - $3: if set to true, skips installation if plugin is already installed (optional, defaults to true)
#         Plugin detection is done by running 'ibmcloud <plugin_name>' which returns 0 if installed
#
# RETURNS:
#   0 - Success (all plugins installed successfully)
#   1 - Failure (one or more plugins failed to install)
#   2 - Failure (incorrect usage of function)
#
# USAGE:
#   # Single plugin
#   install_ibmcloud_plugin "code-engine"
#
#   # Multiple plugins with versions (recommended: store in variable first)
#   plugins="container-service@1.0.506,secrets-manager@0.1.25"
#   install_ibmcloud_plugin "${plugins}"
#
#   # With custom location
#   plugins="code-engine,container-service@1.0.506"
#   install_ibmcloud_plugin "${plugins}" "/tmp" "true"
#===============================================================
install_ibmcloud_plugin() {

  local plugins_str=${1:-""}
  local location=${2:-""}
  local skip_if_detected=${3:-"true"}
  local verbose=${VERBOSE:-false}

  # Validate plugins string is provided
  if [ -z "${plugins_str}" ]; then
    echo "Error: Plugin name(s) required as first argument. Run 'ibmcloud plugin repo-plugins' to see all available plugins." >&2
    echo "Usage: install_ibmcloud_plugin <plugin1[@version][,plugin2[@version]...]> [location] [skip_if_detected]" >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # Validate $3 arg is boolean
  if ! is_boolean "${skip_if_detected}"; then
    echo "Unsupported value detected for the 3rd argument. Only 'true' or 'false' is supported. Found: ${skip_if_detected}." >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # ensure ibmcloud is installed
  check_required_bins ibmcloud || return $?

  # Convert comma-separated string to array
  IFS=',' read -ra plugins <<< "${plugins_str}"

  if [ ${#plugins[@]} -eq 0 ]; then
    echo "Error: At least one plugin name is required." >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # Set custom plugin directory if specified
  local original_ibmcloud_home=""
  if [ -n "${location}" ]; then
    original_ibmcloud_home="${IBMCLOUD_HOME:-}"
    export IBMCLOUD_HOME="${location}"
    mkdir -p "${location}"

    if [ "${verbose}" = true ]; then
      echo "Using custom IBM Cloud home directory: ${location}"
    fi
  fi

  if [ "${verbose}" = true ]; then
    echo "Installing IBM Cloud CLI plugin(s): ${plugins[*]}"
  fi

  # Filter out already installed plugins if skip_if_detected is true
  local plugins_to_install=()
  if [ "${skip_if_detected}" = "true" ]; then
    for plugin_spec in "${plugins[@]}"; do
      # Extract plugin name (before @ if present)
      local plugin_name="${plugin_spec%%@*}"

      # Check if plugin is installed by running ibmcloud <plugin_name>
      # This command returns 0 if the plugin is installed
      if ibmcloud "${plugin_name}" >/dev/null 2>&1; then
        if [ "${verbose}" = true ]; then
          echo "Plugin '${plugin_name}' already installed. Skipping."
        fi
      else
        plugins_to_install+=("${plugin_spec}")
      fi
    done
  else
    plugins_to_install=("${plugins[@]}")
  fi

  # If no plugins to install, return success
  if [ ${#plugins_to_install[@]} -eq 0 ]; then
    if [ "${verbose}" = true ]; then
      echo "All plugins already installed. Nothing to do."
    fi

    # Restore original IBMCLOUD_HOME if it was changed
    if [ -n "${location}" ]; then
      if [ -n "${original_ibmcloud_home}" ]; then
        export IBMCLOUD_HOME="${original_ibmcloud_home}"
      else
        unset IBMCLOUD_HOME
      fi
    fi

    return ${RETURN_CODE_SUCCESS}
  fi

  # Build install command - ibmcloud supports multiple plugins in one command
  # The @version syntax is supported: ibmcloud plugin install plugin1@version1 plugin2@version2
  local install_cmd=(ibmcloud plugin install -f "${plugins_to_install[@]}")

  if [ "${verbose}" = true ]; then
    echo "Running: ${install_cmd[*]}"
  fi

  # Install the plugins
  local rc=0
  if [ "${verbose}" = true ]; then
    "${install_cmd[@]}" || rc=$?
  else
    "${install_cmd[@]}" >/dev/null 2>&1 || rc=$?
  fi

  # Restore original IBMCLOUD_HOME if it was changed
  if [ -n "${location}" ]; then
    if [ -n "${original_ibmcloud_home}" ]; then
      export IBMCLOUD_HOME="${original_ibmcloud_home}"
    else
      unset IBMCLOUD_HOME
    fi
  fi

  if [ ${rc} -eq 0 ]; then
    if [ "${verbose}" = true ]; then
      echo "Successfully installed plugin(s): ${plugins_to_install[*]}"
    fi
    return ${RETURN_CODE_SUCCESS}
  else
    echo "Error: Failed to install one or more plugins: ${plugins_to_install[*]}" >&2
    return ${RETURN_CODE_ERROR}
  fi
}

#===============================================================
# UNIT TESTS
#===============================================================
_test() {
    local make_api_calls="${MAKE_API_CALLS:-false}"
    printf "%s\n\n" "Running tests.."

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

    # install_ibmcloud_plugin
    # -----------------------------------
    if [ "${make_api_calls}" = true ]; then
      # - Test installing a single plugin
      printf "%s\n" "Running 'install_ibmcloud_plugin cloud-object-storage'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "cloud-object-storage" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test installing plugin when it already exists (should be skipped)
      printf "%s\n" "Running 'install_ibmcloud_plugin cloud-object-storage' (already installed - should skip)"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "cloud-object-storage" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test installing multiple plugins with comma-separated syntax
      printf "%s\n" "Running 'install_ibmcloud_plugin container-registry,code-engine'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "container-registry,code-engine" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test installing plugins with version syntax
      printf "%s\n" "Running 'install_ibmcloud_plugin container-service@1.0.506,secrets-manager@0.1.25'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "container-service@1.0.506,secrets-manager@0.1.25" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test with invalid plugin (should fail)
      printf "%s\n" "Running 'install_ibmcloud_plugin invalid-plugin-xyz' (should fail)"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "invalid-plugin-xyz" "" "false" >/dev/null 2>&1 || rc=$?
      assert_fail "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test installing plugin to custom location
      printf "%s\n" "Running 'install_ibmcloud_plugin secrets-manager /tmp false'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "secrets-manager" "/tmp" "false" >/dev/null 2>&1 || rc=$?
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
