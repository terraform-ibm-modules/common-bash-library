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
# FUNCTION: install_ibmcloud_plugin
# DESCRIPTION: Installs an IBM Cloud CLI plugin
#
# ENVIRONMENT VARIABLES:
#   - VERBOSE: If set to true, print verbose output (optional, defaults to false)
#
# ARGUMENTS:
#   - $1: name of the plugin to install (required). Example: "container-service"
#   - $2: if set to true, skips installation if plugin is already installed (optional, defaults to true)
#   - $3: plugin version to install (optional, defaults to latest)
#
# RETURNS:
#   0 - Success (plugin installation successful)
#   1 - Failure (plugin installation failed)
#   2 - Failure (incorrect usage of function)
#
# USAGE: install_ibmcloud_plugin "container-service" "true" "latest"
#===============================================================
install_ibmcloud_plugin() {

  local plugin_name=${1:-""}
  local skip_if_detected=${2:-"true"}
  local version=${3:-"latest"}
  local verbose=${VERBOSE:-false}

  # Validate plugin_name is provided
  if [ -z "${plugin_name}" ]; then
    echo "Error: Plugin name is required as the first argument" >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # Validate $2 arg is boolean
  if ! is_boolean "${skip_if_detected}"; then
    echo "Unsupported value detected for the 2nd argument. Only 'true' or 'false' is supported. Found: ${skip_if_detected}." >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # ensure ibmcloud is installed
  check_required_bins ibmcloud || return $?

  # Check if plugin is already installed and skip_if_detected is true
  if [ "${skip_if_detected}" = "true" ]; then
    if [ "${verbose}" = true ]; then
      echo "Checking if plugin '${plugin_name}' is already installed..."
    fi

    set +e
    local plugin_check
    plugin_check=$(ibmcloud plugin list 2>/dev/null | grep -w "${plugin_name}" || true)
    set -e

    if [ -n "${plugin_check}" ]; then
      if [ "${verbose}" = true ]; then
        echo "Found plugin '${plugin_name}' already installed. Skipping installation."
      fi
      return ${RETURN_CODE_SUCCESS}
    fi
  fi

  if [ "${verbose}" = true ]; then
    echo "Installing IBM Cloud CLI plugin: ${plugin_name}"
    if [ "${version}" != "latest" ]; then
      echo "Version: ${version}"
    fi
  fi

  # Build install command
  local install_cmd="ibmcloud plugin install ${plugin_name} -f"

  # Add version flag if not latest
  if [ "${version}" != "latest" ]; then
    install_cmd="${install_cmd} -v ${version}"
  fi

  if [ "${verbose}" = true ]; then
    echo "Running: ${install_cmd}"
  fi

  # Install the plugin
  set +e
  if [ "${verbose}" = true ]; then
    ${install_cmd}
    local rc=$?
  else
    ${install_cmd} >/dev/null 2>&1
    local rc=$?
  fi
  set -e

  if [ ${rc} -ne 0 ]; then
    echo "Error: Failed to install plugin '${plugin_name}'" >&2
    return ${RETURN_CODE_ERROR}
  fi

  if [ "${verbose}" = true ]; then
    echo "Successfully installed plugin: ${plugin_name}"
  fi

  return ${RETURN_CODE_SUCCESS}
}

#===============================================================
# UNIT TESTS
#===============================================================
_test() {
    local make_api_calls="${MAKE_API_CALLS:-false}"
    printf "%s\n\n" "Running tests.."

    # install_ibmcloud_plugin
    # -----------------------------------
    if [ "${make_api_calls}" = true ]; then
      # Check if ibmcloud is installed
      if ! check_required_bins ibmcloud; then
        echo "ibmcloud CLI must be installed to run these tests" >&2
        exit ${RETURN_CODE_ERROR}
      fi

      # - Test installing a plugin (using a lightweight plugin for testing)
      printf "%s\n" "Running 'install_ibmcloud_plugin cloud-object-storage false'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "cloud-object-storage" "false" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test skipping installation when plugin already exists
      printf "%s\n" "Running 'install_ibmcloud_plugin cloud-object-storage true' (should skip)"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "cloud-object-storage" "true" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test error handling with invalid plugin name
      printf "%s\n" "Running 'install_ibmcloud_plugin invalid-plugin-name-xyz false'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "invalid-plugin-name-xyz" "false" >/dev/null 2>&1 || rc=$?
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
    __name__="__main__"
else
    __name__="__source__"
fi

if [ "${__name__}" = "__main__" ]; then
    main "$@"
fi
