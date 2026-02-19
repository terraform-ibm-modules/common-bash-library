#!/usr/bin/env bash

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the cli.sh file
source "${SCRIPT_DIR}/cli.sh"

# Set verbose mode
export VERBOSE=true

echo "=========================================="
echo "Testing IBM Cloud Plugin Installation"
echo "=========================================="
echo ""

# Test 1: Install single plugin using array with one element
echo "Test 1: Installing single plugin (code-engine)"
echo "------------------------------------------"
DIRECTORY="/tmp/ibmcloud-test"
single_plugin=("code-engine")
install_ibmcloud_plugins single_plugin "latest" "${DIRECTORY}" "true"
echo ""
echo ""

# Test 2: Install multiple plugins using array
echo "Test 2: Installing multiple plugins using array"
echo "------------------------------------------"
plugins=("container-service" "cloud-object-storage" "container-registry")
install_ibmcloud_plugins plugins "latest" "${DIRECTORY}" "true"
echo ""
echo ""

# Test 3: Try to install again (should skip)
echo "Test 3: Re-installing same plugins (should skip)"
echo "------------------------------------------"
install_ibmcloud_plugins plugins "latest" "${DIRECTORY}" "true"
echo ""
echo ""

# Test 4: Force reinstall (skip_if_detected = false)
echo "Test 4: Force reinstall single plugin"
echo "------------------------------------------"
install_ibmcloud_plugins single_plugin "latest" "${DIRECTORY}" "false"
echo ""
echo ""

echo "=========================================="
echo "All tests completed!"
echo "=========================================="
echo ""

# Set IBMCLOUD_HOME to the test directory
if [ -n "${DIRECTORY}" ]; then
    export IBMCLOUD_HOME="${DIRECTORY}"
fi

echo "Installed plugins in ${DIRECTORY}:"
ibmcloud plugin list
echo ""
echo ""

# Test 5: Verify 'ce' command is working from the custom directory
echo "Test 5: Verifying 'ce' command is available in ${DIRECTORY}"
echo "------------------------------------------"
echo "IBMCLOUD_HOME is set to: ${IBMCLOUD_HOME}"
if ibmcloud ce version >/dev/null 2>&1; then
    echo "✅ SUCCESS: 'ce' command is working!"
    ibmcloud ce version
else
    echo "❌ FAILED: 'ce' command is not available"
    echo "This means the code-engine plugin was not installed correctly in ${DIRECTORY}"
    exit 1
fi

# Made with Bob
