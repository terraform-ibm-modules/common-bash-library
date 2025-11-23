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
    echo "Missing binaries: ${missing[*]}" >&2
    return ${RETURN_CODE_ERROR}
  fi

  if [ "${verbose}" = true ]; then
    echo "All required binaries are installed."
  fi
  return ${RETURN_CODE_SUCCESS}
}

#===============================================================
# UNIT TESTS
#===============================================================

_test() {
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

    # -----------------------------------
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
