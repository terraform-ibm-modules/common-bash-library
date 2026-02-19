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
#   - $1: name of the plugin to install (required). Example: "code-engine"
#   - $2: plugin version to install (optional, defaults to latest)
#   - $3: custom directory for plugin installation (optional, uses default if not specified)
#   - $4: if set to true, skips installation if plugin is already installed (optional, defaults to true)
#
# RETURNS:
#   0 - Success (plugin installation successful)
#   1 - Failure (plugin installation failed)
#   2 - Failure (incorrect usage of function)
#
# USAGE: install_ibmcloud_plugin "code-engine" "latest" "/custom/path" "true"
#===============================================================
install_ibmcloud_plugin() {

  local plugin_name=${1:-""}
  local version=${2:-"latest"}
  local location=${3:-""}
  local skip_if_detected=${4:-"true"}
  local verbose=${VERBOSE:-false}

  # Validate plugin_name is provided
  if [ -z "${plugin_name}" ]; then
    echo "Error: Plugin name is required as the first argument" >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # Validate $4 arg is boolean
  if ! is_boolean "${skip_if_detected}"; then
    echo "Unsupported value detected for the 4th argument. Only 'true' or 'false' is supported. Found: ${skip_if_detected}." >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # ensure ibmcloud is installed
  check_required_bins ibmcloud || return $?

  # Set custom plugin directory if specified
  local original_ibmcloud_home=""
  if [ -n "${location}" ]; then
    original_ibmcloud_home="${IBMCLOUD_HOME:-}"
    export IBMCLOUD_HOME="${location}"

    if [ "${verbose}" = true ]; then
      echo "Using custom IBM Cloud home directory: ${location}"
    fi

    # Create directory if it doesn't exist
    mkdir -p "${location}"
  fi

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

      # Restore original IBMCLOUD_HOME if it was changed
      if [ -n "${location}" ] && [ -n "${original_ibmcloud_home}" ]; then
        export IBMCLOUD_HOME="${original_ibmcloud_home}"
      elif [ -n "${location}" ]; then
        unset IBMCLOUD_HOME
      fi

      return ${RETURN_CODE_SUCCESS}
    fi
  fi

  if [ "${verbose}" = true ]; then
    echo "Installing IBM Cloud CLI plugin: ${plugin_name}"
    if [ "${version}" != "latest" ]; then
      echo "Version: ${version}"
    fi
    if [ -n "${location}" ]; then
      echo "Installation directory: ${location}"
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

  # Restore original IBMCLOUD_HOME if it was changed
  if [ -n "${location}" ] && [ -n "${original_ibmcloud_home}" ]; then
    export IBMCLOUD_HOME="${original_ibmcloud_home}"
  elif [ -n "${location}" ]; then
    unset IBMCLOUD_HOME
  fi

  if [ ${rc} -ne 0 ]; then
    echo "Error: Failed to install plugin '${plugin_name}'" >&2
    return ${RETURN_CODE_ERROR}
  fi

  if [ "${verbose}" = true ]; then
    echo "Successfully installed plugin: ${plugin_name}"
    if [ -n "${location}" ]; then
      echo "Plugin installed to: ${location}"
    fi
  fi

  return ${RETURN_CODE_SUCCESS}
}
#===============================================================
# FUNCTION: install_ibmcloud_plugins
# DESCRIPTION: Installs multiple IBM Cloud CLI plugins
#
# ENVIRONMENT VARIABLES:
#   - VERBOSE: If set to true, print verbose output (optional, defaults to false)
#
# ARGUMENTS:
#   - $1: space-separated list of plugin names to install (required). Example: "code-engine container-service"
#   - $2: plugin version to install for all plugins (optional, defaults to latest)
#   - $3: custom directory for plugin installation (optional, uses default if not specified)
#   - $4: if set to true, skips installation if plugin is already installed (optional, defaults to true)
#
# RETURNS:
#   0 - Success (all plugins installed successfully)
#   1 - Failure (one or more plugins failed to install)
#   2 - Failure (incorrect usage of function)
#
# USAGE: install_ibmcloud_plugins "code-engine container-service cloud-object-storage" "latest" "/custom/path" "true"
#===============================================================
install_ibmcloud_plugins() {

  local plugin_list=${1:-""}
  local version=${2:-"latest"}
  local location=${3:-""}
  local skip_if_detected=${4:-"true"}
  local verbose=${VERBOSE:-false}

  # Validate plugin_list is provided
  if [ -z "${plugin_list}" ]; then
    echo "Error: Plugin list is required as the first argument" >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # Validate $4 arg is boolean
  if ! is_boolean "${skip_if_detected}"; then
    echo "Unsupported value detected for the 4th argument. Only 'true' or 'false' is supported. Found: ${skip_if_detected}." >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # ensure ibmcloud is installed
  check_required_bins ibmcloud || return $?

  if [ "${verbose}" = true ]; then
    echo "Installing IBM Cloud CLI plugins: ${plugin_list}"
    if [ "${version}" != "latest" ]; then
      echo "Version: ${version}"
    fi
    if [ -n "${location}" ]; then
      echo "Installation directory: ${location}"
    fi
  fi

  # Track installation results
  local failed_plugins=()
  local installed_plugins=()
  local skipped_plugins=()

  # Convert plugin list to array
  local plugins_array
  read -ra plugins_array <<< "${plugin_list}"

  # Install each plugin
  for plugin_name in "${plugins_array[@]}"; do
    if [ "${verbose}" = true ]; then
      echo ""
      echo "Processing plugin: ${plugin_name}"
    fi

    set +e
    install_ibmcloud_plugin "${plugin_name}" "${version}" "${location}" "${skip_if_detected}"
    local rc=$?
    set -e

    if [ ${rc} -eq 0 ]; then
      # Check if it was skipped or installed
      set +e
      local was_already_installed
      was_already_installed=$(ibmcloud plugin list 2>/dev/null | grep -w "${plugin_name}" || true)
      set -e
      
      if [ -n "${was_already_installed}" ] && [ "${skip_if_detected}" = "true" ]; then
        skipped_plugins+=("${plugin_name}")
      else
        installed_plugins+=("${plugin_name}")
      fi
    else
      failed_plugins+=("${plugin_name}")
    fi
  done

  # Print summary
  if [ "${verbose}" = true ]; then
    echo ""
    echo "=========================================="
    echo "Installation Summary:"
    echo "=========================================="
    
    if [ ${#installed_plugins[@]} -gt 0 ]; then
      echo "✅ Installed (${#installed_plugins[@]}): ${installed_plugins[*]}"
    fi
    
    if [ ${#skipped_plugins[@]} -gt 0 ]; then
      echo "⏭️  Skipped (${#skipped_plugins[@]}): ${skipped_plugins[*]}"
    fi
    
    if [ ${#failed_plugins[@]} -gt 0 ]; then
      echo "❌ Failed (${#failed_plugins[@]}): ${failed_plugins[*]}"
    fi
    echo "=========================================="
  fi

  # Return error if any plugins failed
  if [ ${#failed_plugins[@]} -gt 0 ]; then
    echo "Error: Failed to install ${#failed_plugins[@]} plugin(s): ${failed_plugins[*]}" >&2
    return ${RETURN_CODE_ERROR}
  fi

  if [ "${verbose}" = true ]; then
    echo "Successfully processed all plugins"
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
      printf "%s\n" "Running 'install_ibmcloud_plugin cloud-object-storage latest \"\" false'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "cloud-object-storage" "latest" "" "false" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test skipping installation when plugin already exists
      printf "%s\n" "Running 'install_ibmcloud_plugin cloud-object-storage latest \"\" true' (should skip)"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "cloud-object-storage" "latest" "" "true" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test error handling with invalid plugin name
      printf "%s\n" "Running 'install_ibmcloud_plugin invalid-plugin-name-xyz latest \"\" false'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugin "invalid-plugin-name-xyz" "latest" "" "false" >/dev/null 2>&1 || rc=$?
      assert_fail "${rc}"
      printf "%s\n\n" "✅ PASS"
    fi

    # install_ibmcloud_plugins
    # -----------------------------------
    if [ "${make_api_calls}" = true ]; then
      # - Test installing multiple plugins
      printf "%s\n" "Running 'install_ibmcloud_plugins \"cloud-object-storage container-registry\" latest \"\" true'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugins "cloud-object-storage container-registry" "latest" "" "true" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test with one invalid plugin in the list (should fail)
      printf "%s\n" "Running 'install_ibmcloud_plugins \"cloud-object-storage invalid-plugin-xyz\" latest \"\" false'"
      rc=${RETURN_CODE_SUCCESS}
      install_ibmcloud_plugins "cloud-object-storage invalid-plugin-xyz" "latest" "" "false" >/dev/null 2>&1 || rc=$?
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
