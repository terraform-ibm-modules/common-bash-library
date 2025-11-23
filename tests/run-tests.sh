#!/usr/bin/env bash

#===============================================================
# Test Runner for Common Bash Library
#
# This script automatically discovers and executes all bash scripts
# in the repository that contain test functions.
#
# DESCRIPTION:
#   - Recursively finds all .sh files in the repository
#   - Excludes the test runner itself
#   - Executes each script and captures results
#   - Reports pass/fail status for each script
#   - Provides summary of test results
#
# USAGE:
#   ./tests/run-tests.sh
#
# ENVIRONMENT VARIABLES:
#   - MAKE_API_CALLS: Set to "true" to enable tests that make API calls (optional, defaults to false)
#===============================================================

set -euo pipefail

#===============================================================
# GLOBAL VARIABLES
#===============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RETURN_CODE_SUCCESS=0
RETURN_CODE_ERROR=1

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
declare -a PASSED_TESTS=()
declare -a FAILED_TESTS=()
declare -a SKIPPED_TESTS=()

#===============================================================
# FUNCTION: print_header
# DESCRIPTION: Prints a formatted header
#===============================================================
print_header() {
    local message="$1"
    echo ""
    echo "================================================================"
    echo "${message}"
    echo "================================================================"
}

#===============================================================
# FUNCTION: print_section
# DESCRIPTION: Prints a formatted section header
#===============================================================
print_section() {
    local message="$1"
    echo ""
    echo "----------------------------------------"
    echo "${message}"
    echo "----------------------------------------"
}

#===============================================================
# FUNCTION: is_executable_script
# DESCRIPTION: Checks if a file is an executable bash script
#===============================================================
is_executable_script() {
    local file="$1"

    # Check if file exists and is readable
    [[ -f "${file}" ]] || return 1
    [[ -r "${file}" ]] || return 1

    # Check if file has bash shebang
    head -n 1 "${file}" | grep -qE '^#!/.*bash' || return 1

    return 0
}

#===============================================================
# FUNCTION: should_skip_script
# DESCRIPTION: Determines if a script should be skipped
#===============================================================
should_skip_script() {
    local file="$1"
    local script_name
    script_name="$(basename "${file}")"

    # Skip the test runner itself
    [[ "${script_name}" == "run-tests.sh" ]] && return 0

    # Skip if file doesn't contain a _test function or main function
    if ! grep -q "^_test()" "${file}" && ! grep -q "^main()" "${file}"; then
        return 0
    fi

    return 1
}

#===============================================================
# FUNCTION: run_script_tests
# DESCRIPTION: Executes a single bash script and captures results
#===============================================================
run_script_tests() {
    local script_path="$1"
    local script_name
    script_name="$(basename "${script_path}")"
    local script_dir
    script_dir="$(dirname "${script_path}")"

    print_section "Testing: ${script_name}"

    # Change to script directory to handle relative paths
    local original_dir
    original_dir="$(pwd)"
    cd "${script_dir}" || return 1

    # Execute the script and capture output
    local output
    local exit_code=0

    if output=$(bash "${script_name}" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    # Return to original directory
    cd "${original_dir}" || return 1

    # Display output
    echo "${output}"

    # Check result
    if [[ ${exit_code} -eq 0 ]]; then
        echo -e "${GREEN}✅ PASSED: ${script_name}${NC}"
        PASSED_TESTS+=("${script_path}")
        return 0
    else
        echo -e "${RED}❌ FAILED: ${script_name} (exit code: ${exit_code})${NC}"
        FAILED_TESTS+=("${script_path}")
        return 1
    fi
}

#===============================================================
# FUNCTION: find_and_run_tests
# DESCRIPTION: Discovers and executes all test scripts
#===============================================================
find_and_run_tests() {
    # Find all .sh files in the repository
    local scripts=()
    while IFS= read -r -d '' file; do
        if is_executable_script "${file}"; then
            if should_skip_script "${file}"; then
                local script_name
                script_name="$(basename "${file}")"
                SKIPPED_TESTS+=("${file}")
            else
                scripts+=("${file}")
            fi
        fi
    done < <(find "${REPO_ROOT}" -type f -name "*.sh" -print0)

    # Check if any test scripts were found
    if [[ ${#scripts[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠ No test scripts found${NC}"
        return 0
    fi

    print_header "Running Tests"
    echo "Found ${#scripts[@]} test script(s) to execute"

    # Execute each script
    for script in "${scripts[@]}"; do
        run_script_tests "${script}" || true  # Continue even if a test fails
    done
}

#===============================================================
# FUNCTION: print_summary
# DESCRIPTION: Prints a summary of test results
#===============================================================
print_summary() {
    print_header "Test Summary"

    local total_tests=$((${#PASSED_TESTS[@]} + ${#FAILED_TESTS[@]}))

    echo "Total Scripts Executed: ${total_tests}"
    echo -e "${GREEN}Passed: ${#PASSED_TESTS[@]}${NC}"
    echo -e "${RED}Failed: ${#FAILED_TESTS[@]}${NC}"

    # List failed tests if any
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed Tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo "  - ${test}"
        done
    fi

    echo ""

    # Return appropriate exit code
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return ${RETURN_CODE_SUCCESS}
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        return ${RETURN_CODE_ERROR}
    fi
}

#===============================================================
# MAIN
#===============================================================
main() {
    print_header "Common Bash Library - Test Runner"

    echo "Repository Root: ${REPO_ROOT}"
    echo "MAKE_API_CALLS: ${MAKE_API_CALLS:-false}"

    # Find and run all tests
    find_and_run_tests

    # Print summary and exit with appropriate code
    print_summary
}

# Execute main function
main "$@"
