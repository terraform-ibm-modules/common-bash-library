#!/usr/bin/env bash

set -euo pipefail

#===============================================================
# GLOBAL VARIABLES
#===============================================================
RETURN_CODE_ERROR=1
RETURN_CODE_ERROR_INCORRECT_USAGE=2
RETURN_CODE_SUCCESS=0

#===============================================================
# FUNCTION: assert_eq
# DESCRIPTION: Assert that two input argument strings are equal.
#
# ARGUMENTS:
#   - $1: First input argument string (required)
#   - $2: Second input argument string (required)
#
# RETURNS:
#   0 - Success (strings are equal)
#   1 - Failure (exit if strings are not equal)
#   2 - Failure (incorrect usage of function)
#
# USAGE: assert_eq "test" "test"
#===============================================================
assert_eq() {
  # Check if exactly 2 arguments are provided
  if [ $# -ne 2 ]; then
    echo "Error: assert_eq requires exactly 2 arguments, but $# were provided" >&2
    echo "Usage: assert_eq <value1> <value2>" >&2
    exit ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  if [ "$1" != "$2" ]; then
    echo "❌ FAIL: assertion failed. Arguments not equal! arg1 = $1; arg2 = $2" >&2
    echo "Exiting." >&2
    exit ${RETURN_CODE_ERROR}
  fi
}

#===============================================================
# FUNCTION: assert_pass
# DESCRIPTION: Assert that input argument is 0.
#
# ARGUMENTS:
#   - $1: Return code to check (required)
#
# RETURNS:
#   0 - Success (input argument is 0)
#   1 - Failure (exit if input argument is not 0)
#   2 - Failure (incorrect usage of function)
#
# USAGE: assert_pass 0
#===============================================================
assert_pass() {
  # Check if exactly 1 argument is provided
  if [ $# -ne 1 ]; then
    echo "Error: assert_pass requires exactly 1 argument, but $# were provided" >&2
    echo "Usage: assert_pass <value>" >&2
    exit ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  if [ "$1" != "${RETURN_CODE_SUCCESS}" ]; then
    echo "❌ FAIL: assertion failed. Expected return code: ${RETURN_CODE_SUCCESS}. Actual: $1." >&2
    echo "Exiting." >&2
    exit ${RETURN_CODE_ERROR}
  fi
}

#===============================================================
# FUNCTION: assert_fail
# DESCRIPTION: Assert that input argument is not 0.
#
# ARGUMENTS:
#   - $1: Return code to check (required)
#
# RETURNS:
#   0 - Success (input argument is not 0)
#   1 - Failure (exit if input argument is 0)
#   2 - Failure (incorrect usage of function)
#
# USAGE: assert_fail 1
#===============================================================
assert_fail() {
  # Check if exactly 1 argument is provided
  if [ $# -ne 1 ]; then
    echo "Error: assert_fail requires exactly 1 argument, but $# were provided" >&2
    echo "Usage: assert_fail <value>" >&2
    exit ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  if [ "$1" == "${RETURN_CODE_SUCCESS}" ]; then
    echo "❌ FAIL: assertion failed. Expected non zero return code. Actual: $1." >&2
    echo "Exiting." >&2
    exit ${RETURN_CODE_ERROR}
  fi
}

#===============================================================
# FUNCTION: check_env_vars
# DESCRIPTION: Checks if environment variables are set
#
# ENVIRONMENT VARIABLES:
#   - VERBOSE: If set to true, print verbose output (optional, defaults to false)
#
# ARGUMENTS:
#   - $1..n: environment variables to check
#
# RETURNS:
#   0 - Success (all environment variables are set)
#   1 - Failure (if any of the environment variables are not set)
#   2 - Failure (incorrect usage of function)
#
# USAGE: check_env_vars PATH HOME
#===============================================================
check_env_vars() {
    local missing=${RETURN_CODE_SUCCESS}
    local verbose=${VERBOSE:-false}

    # Check if 1 or more arguments are provided
    if [ $# -lt 1 ]; then
      echo "Error: check_env_vars requires 1 or more arguments, but $# were provided" >&2
      echo "Usage: check_env_vars <value>" >&2
      exit ${RETURN_CODE_ERROR_INCORRECT_USAGE}
    fi

    for var in "$@"; do
      if [[ -z "${!var+x}" ]]; then
        echo "❌ Environment variable '$var' is NOT set." >&2
        missing=${RETURN_CODE_ERROR}
      else
        if [ "${verbose}" = true ]; then
          echo "✅ $var is set."
        fi
      fi
    done

    return ${missing}
}

#===============================================================
# FUNCTION: check_required_bins
# DESCRIPTION: Checks if binary exists by running command -v <binary>
#
# ENVIRONMENT VARIABLES:
#   - VERBOSE: If set to true, print verbose output (optional, defaults to false)
#
# ARGUMENTS:
#   - $1..n: binaries to check
#
# RETURNS:
#   0 - Success (all binaries are found)
#   1 - Failure (if any of the binaries are not found)
#   2 - Failure (incorrect usage of function)
#
# USAGE: check_required_bins git jq
#===============================================================
check_required_bins() {
  local missing=()
  local verbose=${VERBOSE:-false}

  # Check if 1 or more arguments are provided
  if [ $# -lt 1 ]; then
    echo "Error: check_required_bins requires 1 or more arguments, but $# were provided" >&2
    echo "Usage: check_required_bins <value>" >&2
    exit ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  for bin in "$@"; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        missing+=("$bin")
    fi
  done

  if (( ${#missing[@]} )); then
    if [ "${verbose}" = true ]; then
      echo "Missing binaries: ${missing[*]}" >&2
    fi
    return ${RETURN_CODE_ERROR}
  fi

  if [ "${verbose}" = true ]; then
    echo "All required binaries are installed."
  fi
  return ${RETURN_CODE_SUCCESS}
}

#===============================================================
# FUNCTION: is_boolean
# DESCRIPTION: Determine is value is a boolean.
#
# ARGUMENTS:
#   - $1: value to check (required)
#
# RETURNS:
#   0 - Success (value is a boolean - true, True, false or False)
#   1 - Failure (value is not a boolean)
#   2 - Failure (incorrect usage of function)
#
# USAGE: is_boolean <value>
#===============================================================
is_boolean() {

  # Validate an arg has been provided
  if [ $# -ne 1 ]; then
    echo "Error: is_boolean requires exactly 1 argument, but $# were provided" >&2
    echo "Usage: is_boolean <value>" >&2
    exit ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  if [[ $1 =~ ^([Tt]rue|[Ff]alse)$ ]]; then
    return ${RETURN_CODE_SUCCESS}
  else
    return ${RETURN_CODE_ERROR}
  fi
}

#===============================================================
# FUNCTION: return_mac_architecture
# DESCRIPTION: Returns the architecture of the MacOS
#
# RETURNS:
#   0 - Success
#     - "amd64" - if the OS is macOS and the CPU is Intel
#     - "arm64" - if the OS is macOS and the CPU is Apple Silicon
#   2 - Failure (Did not detect MacOS)
#
# USAGE: return_mac_architecture
#===============================================================
return_mac_architecture() {

  local arch="arm64"
  local cpu
  if [[ ${OSTYPE} == 'darwin'* ]]; then
    cpu="$(sysctl -a | grep machdep.cpu.brand_string)"
    if [[ "${cpu}" == 'machdep.cpu.brand_string: Intel'* ]]; then
      # macOS on Intel architecture
      arch="amd64"
    fi
  else
    echo "Unsupported OS: ${OSTYPE}" >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi
  echo ${arch}
}

#===============================================================
# FUNCTION: install_jq
# DESCRIPTION: Installs jq binary
#
# ENVIRONMENT VARIABLES:
#   - VERBOSE: If set to true, print verbose output (optional, defaults to false)
#
# ARGUMENTS:
#   - $1: version of jq to install (optional, defaults to latest). Example format of valid version is "1.8.1".
#   - $2: location to install jq to (optional, defaults to /usr/local/bin)
#   - $3: if set to true, skips installation if jq is already detected (optional, defaults to true)
#   - $4: the exact url to download jq from (optional, defaults to https://github.com/jqlang/jq/releases/latest/download/jq-<os>-<arch>)
#
# RETURNS:
#   0 - Success (jq installation successful)
#   1 - Failure (jq installation failed)
#   2 - Failure (incorrect usage of function)
#
# USAGE: install_jq "latest" "/usr/local/bin" "true" "https://github.com/jqlang/jq/releases/latest/download/jq-<os>-<arch>"
#===============================================================
install_jq() {

  local version=${1:-"latest"} # default to latest if not specified
  local location=${2:-"/usr/local/bin"}
  local skip_if_detected=${3:-"true"}
  local link_to_binary=${4:-""}
  local verbose=${VERBOSE:-false}

  # Validate $3 arg is boolean
  if ! is_boolean "${skip_if_detected}"; then
    echo "Unsupported value detected for the 3rd argument. Only 'true' or 'false' is supported. Found: ${skip_if_detected}." >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # return 0 if jq already installed and skip_if_detected is true
  if [ "${skip_if_detected}" == "true" ]; then
    if check_required_bins jq; then
      if [ "${verbose}" = true ]; then
        echo "Found jq already installed. Taking no action."
      fi
      return ${RETURN_CODE_SUCCESS}
    fi
  fi
  # ensure curl is installed
  check_required_bins curl || return $?

  # strip "v" prefix if it exists in version
  if [[ "${version}" == "v"* ]]; then
    version="${version#v}"
  fi

  # if no link to binary passed, determine the download link based on detected os and arch
  if [ -z "${link_to_binary}" ]; then
    # determine the OS and architecture
    local os="linux"
    local arch="amd64"
    if [[ ${OSTYPE} == 'darwin'* ]]; then
      arch=$(return_mac_architecture)
    fi
    # determine download link to binary
    link_to_binary="https://github.com/jqlang/jq/releases/download/jq-${version}/jq-${os}-${arch}"
    if [ "${version}" = "latest" ]; then
      link_to_binary="https://github.com/jqlang/jq/releases/latest/download/jq-${os}-${arch}"
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
  ${arg} rm -f "${location}/jq"

  # download binary
  set +e
  if ! ${arg} curl --silent \
    --connect-timeout 5 \
    --max-time 10 \
    --retry 3 \
    --retry-delay 2 \
    --retry-connrefused \
    --fail \
    --show-error \
    --location \
    --output "${location}/jq" \
    "${link_to_binary}"
  then
    echo "Failed to download ${link_to_binary}"
    return ${RETURN_CODE_ERROR}
  fi
  set -e

  # make executable
  ${arg} chmod +x "${location}/jq"

  if [ "${verbose}" = true ]; then
    echo "Successfully completed installation to ${location}/jq"
  fi
  return ${RETURN_CODE_SUCCESS}
}

#===============================================================
# FUNCTION: install_kubectl
# DESCRIPTION: Installs kubectl binary
#
# ENVIRONMENT VARIABLES:
#   - VERBOSE: If set to true, print verbose output (optional, defaults to false)
#
# ARGUMENTS:
#   - $1: version of kubectl to install (optional, defaults to current latest stable). Example format of valid version is "v1.34.2".
#   - $2: location to install kubectl to (optional, defaults to /usr/local/bin)
#   - $3: if set to true, skips installation of kubectl if already detected (optional, defaults to true)
#   - $4: the exact url to download kubectl from (optional, defaults to https://dl.k8s.io/release/<version>/bin/<os>/<arch>/kubectl)
#
# RETURNS:
#   0 - Success (kubectl installation successful)
#   1 - Failure (kubectl installation failed)
#   2 - Failure (incorrect usage of function)
#
# USAGE: kubectl "latest" "/usr/local/bin" "true" "https://dl.k8s.io/release/<version>/bin/<os>/<arch>/kubectl"
#===============================================================
install_kubectl() {

  local version=${1:-"latest"}
  local location=${2:-"/usr/local/bin"}
  local skip_if_detected=${3:-"true"}
  local link_to_binary=${4:-""}
  local verbose=${VERBOSE:-false}

  # Validate $3 arg is boolean
  if ! is_boolean "${skip_if_detected}"; then
    echo "Unsupported value detected for the 3rd argument. Only 'true' or 'false' is supported. Found: ${skip_if_detected}." >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # return 0 if kubectl already installed and skip_if_detected is true
  if [ "${skip_if_detected}" == "true" ]; then
    if check_required_bins kubectl; then
      if [ "${verbose}" = true ]; then
        echo "Found kubectl already installed. Taking no action."
      fi
      return ${RETURN_CODE_SUCCESS}
    fi
  fi
  # ensure curl is installed
  check_required_bins curl || return $?
  # if no link to binary passed, determine the download link based on detected os and arch
  if [ -z "${link_to_binary}" ]; then
    # determine the OS and architecture
    local os="linux"
    local arch="amd64"
    if [[ ${OSTYPE} == 'darwin'* ]]; then
      arch=$(return_mac_architecture)
    fi
    # determine download link to binary
    link_to_binary="https://dl.k8s.io/release/${version}/bin/${os}/${arch}/kubectl"
    if [ "${version}" = "latest" ]; then
      link_to_binary="https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/${os}/${arch}/kubectl"
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
  ${arg} rm -f "${location}/kubectl"

  # download binary
  set +e
  if ! ${arg} curl --silent \
    --connect-timeout 5 \
    --max-time 10 \
    --retry 3 \
    --retry-delay 2 \
    --retry-connrefused \
    --fail \
    --show-error \
    --location \
    --output "${location}/kubectl" \
    "${link_to_binary}"
  then
    echo "Failed to download ${link_to_binary}"
    return ${RETURN_CODE_ERROR}
  fi
  set -e

  # make executable
  ${arg} chmod +x "${location}/kubectl"

  if [ "${verbose}" = true ]; then
    echo "Successfully completed installation to ${location}/kubectl"
  fi
  return ${RETURN_CODE_SUCCESS}
}

#===============================================================
# UNIT TESTS
#===============================================================

_test() {
    local make_api_calls="${MAKE_API_CALLS:-false}"
    printf "%s\n\n" "Running tests.."

    # check_env_vars
    # -----------------------------------
    # - Test 0 returned when variable set
    printf "%s\n" "Running 'check_env_vars PATH HOME'"
    rc=${RETURN_CODE_SUCCESS}
    check_env_vars PATH HOME >/dev/null 2>&1 || rc=$?
    assert_pass "${rc}"
    printf "%s\n\n" "✅ PASS"

    # - Test non 0 returned when variable not set
    printf "%s\n" "Running 'check_env_vars FGDFGDFGH'"
    rc=${RETURN_CODE_SUCCESS}
    check_env_vars FGDFGDFGH >/dev/null 2>&1 || rc=$?
    assert_fail "${rc}"
    printf "%s\n\n" "✅ PASS"

    # check_required_bins
    # -----------------------------------
    # - Test 0 returned when binaries found
    printf "%s\n" "Running 'check_env_vars echo'"
    rc=${RETURN_CODE_SUCCESS}
    check_required_bins echo >/dev/null 2>&1 || rc=$?
    assert_pass "${rc}"
    printf "%s\n\n" "✅ PASS"

    # - Test non 0 returned when binaries not found
    printf "%s\n" "Running 'check_env_vars dfdsfdsag'"
    rc=${RETURN_CODE_SUCCESS}
    check_required_bins dfdsfdsag >/dev/null 2>&1 || rc=$?
    assert_fail "${rc}"
    printf "%s\n\n" "✅ PASS"

    # is_boolean
    # -----------------------------------
    # - Test valid booleans
    for i in "true" "false" "True" "False"; do
      printf "%s\n" "Running 'is_boolean $i'"
      rc=${RETURN_CODE_SUCCESS}
      is_boolean $i >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"
    done

    # - Test non valid boolean
    printf "%s\n" "Running 'is_boolean not_a_boolean'"
    rc=${RETURN_CODE_SUCCESS}
    is_boolean not_a_boolean >/dev/null 2>&1 || rc=$?
    assert_fail "${rc}"
    printf "%s\n\n" "✅ PASS"

    # install_jq
    # -----------------------------------
    if [ "${make_api_calls}" = true ]; then
      # Check if jq already exists on $PATH
      local jq_installed=true
      check_required_bins jq || jq_installed=false

      # - Test installing jq using defaults (when it does not already exist)
      if [ ${jq_installed} = false ]; then
        printf "%s\n" "Running 'install_jq' (when jq does not already exists)"
        rc=${RETURN_CODE_SUCCESS}
        install_jq >/dev/null 2>&1 || rc=$?
        assert_pass "${rc}"
        printf "%s\n\n" "✅ PASS"
      fi

      # - Test installing it when jq already exists with default args (should be skipped)
      printf "%s\n" "Running 'install_jq' (when jq already exists - install will be skipped)"
      rc=${RETURN_CODE_SUCCESS}
      install_jq >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test installing exact version to /tmp even if jq already detected on $PATH
      printf "%s\n" "Running 'install_jq 1.8.1 /tmp false'"
      rc=${RETURN_CODE_SUCCESS}
      install_jq "1.8.1" "/tmp" "false" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"
    fi

    # install_kubectl
    # -----------------------------------
    if [ "${make_api_calls}" = true ]; then
      # Check if kubectl already exists on $PATH
      local kubectl_installed=true
      check_required_bins kubectl || kubectl_installed=false

      # - Test installing kubectl using defaults (when it does not already exist)
      if [ ${kubectl_installed} = false ]; then
        printf "%s\n" "Running 'install_kubectl' (when kubectl does not already exists)"
        rc=${RETURN_CODE_SUCCESS}
        install_kubectl >/dev/null 2>&1 || rc=$?
        assert_pass "${rc}"
        printf "%s\n\n" "✅ PASS"
      fi

      # - Test installing it when kubectl already exists with default args (should be skipped)
      printf "%s\n" "Running 'install_kubectl' (when kubectl already exists - install will be skipped)"
      rc=${RETURN_CODE_SUCCESS}
      install_kubectl >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"

      # - Test installing exact version to /tmp even if kubectl already detected on $PATH
      printf "%s\n" "Running 'install_kubectl v1.34.2 /tmp false'"
      rc=${RETURN_CODE_SUCCESS}
      install_kubectl "v1.34.2" "/tmp" "false" >/dev/null 2>&1 || rc=$?
      assert_pass "${rc}"
      printf "%s\n\n" "✅ PASS"
    fi

    # install_python_package
    # -----------------------------------
    # - Test with missing arguments (should fail)
    printf "%s\n" "Running 'install_python_package' (missing arguments - should fail)"
    rc=${RETURN_CODE_SUCCESS}
    install_python_package >/dev/null 2>&1 || rc=$?
    assert_fail "${rc}"
    printf "%s\n\n" "✅ PASS"

    # - Test with missing directory argument (should fail)
    printf "%s\n" "Running 'install_python_package requests' (missing directory - should fail)"
    rc=${RETURN_CODE_SUCCESS}
    install_python_package "requests" >/dev/null 2>&1 || rc=$?
    assert_fail "${rc}"
    printf "%s\n\n" "✅ PASS"

    # - Test installing a Python package to /tmp
    printf "%s\n" "Running 'install_python_package requests>=2.31.0 /tmp'"
    rc=${RETURN_CODE_SUCCESS}
    install_python_package "requests>=2.31.0" "/tmp" >/dev/null 2>&1 || rc=$?
    assert_pass "${rc}"
    printf "%s\n\n" "✅ PASS"

    # - Verify the package was installed
    printf "%s\n" "Verifying requests package was installed to /tmp"
    rc=${RETURN_CODE_SUCCESS}
    python3 -c "import sys; sys.path.insert(0, '/tmp'); import requests; print(requests.__version__)" >/dev/null 2>&1 || rc=$?
    assert_pass "${rc}"
    printf "%s\n\n" "✅ PASS"

    # - Test that the package directory exists in /tmp
    printf "%s\n" "Verifying requests package directory exists in /tmp"
    rc=${RETURN_CODE_SUCCESS}
    if [ -d "/tmp/requests" ]; then
      rc=${RETURN_CODE_SUCCESS}
    else
      rc=${RETURN_CODE_ERROR}
    fi
    assert_pass "${rc}"
    printf "%s\n\n" "✅ PASS"

    # -----------------------------------
echo "✅ All tests passed!"
}

#===============================================================
# FUNCTION: install_python_package
# DESCRIPTION: Install a Python package using pip to a specified directory.
#
# ARGUMENTS:
#   - $1: Package specification (e.g., "requests>=2.31.0") (required)
#   - $2: Target directory for installation (required)
#
# RETURNS:
#   0 - Success (package installed successfully)
#   1 - Failure (installation failed)
#   2 - Failure (incorrect usage of function)
#
# USAGE: install_python_package "requests>=2.31.0" "/tmp"
#===============================================================
install_python_package() {
  local package=${1:-""}
  local directory=${2:-""}
  local verbose=${VERBOSE:-false}

  # Validate arguments
  if [ -z "${package}" ]; then
    echo "Error: install_python_package requires package specification as first argument" >&2
    echo "Usage: install_python_package <package> <directory>" >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  if [ -z "${directory}" ]; then
    echo "Error: install_python_package requires target directory as second argument" >&2
    echo "Usage: install_python_package <package> <directory>" >&2
    return ${RETURN_CODE_ERROR_INCORRECT_USAGE}
  fi

  # Check if python3 is available, install if not
  if ! command -v python3 &> /dev/null; then
    echo "Python3 not found. Attempting to install..." >&2

    # Detect OS and install Python3
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS
      if command -v brew &> /dev/null; then
        echo "Installing Python3 via Homebrew..." >&2
        brew install python3 || {
          echo "Error: Failed to install Python3 via Homebrew" >&2
          return ${RETURN_CODE_ERROR}
        }
      else
        echo "Error: Homebrew not found. Please install Python3 manually." >&2
        return ${RETURN_CODE_ERROR}
      fi
    elif [[ -f /etc/debian_version ]]; then
      # Debian/Ubuntu
      echo "Installing Python3 via apt..." >&2
      if ! sudo apt-get update; then
        echo "Error: Failed to update apt" >&2
        return ${RETURN_CODE_ERROR}
      fi
      if ! sudo apt-get install -y python3 python3-pip; then
        echo "Error: Failed to install Python3 via apt" >&2
        return ${RETURN_CODE_ERROR}
      fi
    elif [[ -f /etc/redhat-release ]]; then
      # RHEL/CentOS/Fedora
      echo "Installing Python3 via yum/dnf..." >&2
      if command -v dnf &> /dev/null; then
        sudo dnf install -y python3 python3-pip || {
          echo "Error: Failed to install Python3 via dnf" >&2
          return ${RETURN_CODE_ERROR}
        }
      else
        sudo yum install -y python3 python3-pip || {
          echo "Error: Failed to install Python3 via yum" >&2
          return ${RETURN_CODE_ERROR}
        }
      fi
    else
      echo "Error: Unsupported OS. Please install Python3 manually." >&2
      return ${RETURN_CODE_ERROR}
    fi

    echo "Python3 installed successfully" >&2
  fi

  # Check if pip is available, install if not
  if ! python3 -m pip --version &> /dev/null; then
    echo "pip not found. Attempting to install..." >&2

    # Try to install pip using ensurepip
    if python3 -m ensurepip --default-pip &> /dev/null; then
      echo "pip installed successfully via ensurepip" >&2
    else
      # Fallback: download and install pip using get-pip.py
      echo "Attempting to install pip via get-pip.py..." >&2
      curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py || {
        echo "Error: Failed to download get-pip.py" >&2
        return ${RETURN_CODE_ERROR}
      }

      python3 /tmp/get-pip.py --user || {
        echo "Error: Failed to install pip via get-pip.py" >&2
        rm -f /tmp/get-pip.py
        return ${RETURN_CODE_ERROR}
      }

      rm -f /tmp/get-pip.py
      echo "pip installed successfully via get-pip.py" >&2
    fi

    # Verify pip is now available
    if ! python3 -m pip --version &> /dev/null; then
      echo "Error: pip installation failed. Cannot install Python packages." >&2
      return ${RETURN_CODE_ERROR}
    fi
  fi

  if [ "${verbose}" = true ]; then
    echo "Installing Python package: ${package} to ${directory}"
  fi

  # Install the package to the specified directory
  if ! python3 -m pip install --target="${directory}" "${package}" --quiet; then
    echo "Error: Failed to install Python package: ${package}" >&2
    return ${RETURN_CODE_ERROR}
  fi

  if [ "${verbose}" = true ]; then
    echo "Successfully installed Python package: ${package}"
  fi

  return ${RETURN_CODE_SUCCESS}
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
