# Common Bash Library

A library of bash functions for common tasks.

## [common](common)
<details>
  <summary>assert_eq</summary>

Assert that two input argument strings are equal.

**Arguments:**
- `$1`: First input argument string (required)
- `$2`: Second input argument string (required)

**Returns:**
- `0` - Success (strings are equal)
- `1` - Failure (exit if strings are not equal)
- `2` - Failure (incorrect usage of function)

**Usage:**
```bash
assert_eq "test" "test"
```
</details>

<!------------------------------------------------>

<details>
  <summary>assert_pass</summary>

Assert that input argument is 0.

**Arguments:**
- `$1`: Return code to check (required)

**Returns:**
- `0` - Success (input argument is 0)
- `1` - Failure (exit if input argument is not 0)
- `2` - Failure (incorrect usage of function)

**Usage:**
```bash
assert_pass 0
```
</details>

<!------------------------------------------------>

<details>
  <summary>assert_fail</summary>

Assert that input argument is not 0.

**Arguments:**
- `$1`: Return code to check (required)

**Returns:**
- `0` - Success (input argument is not 0)
- `1` - Failure (exit if input argument is 0)
- `2` - Failure (incorrect usage of function)

**Usage:**
```bash
assert_fail 1
```
</details>

<!------------------------------------------------>

<details>
  <summary>check_env_vars</summary>

Checks if environment variables are set.

**Environment Variables:**
- `VERBOSE`: If set to true, print verbose output (optional, defaults to false)

**Arguments:**
- `$1..n`: environment variables to check

**Returns:**
- `0` - Success (all environment variables are set)
- `1` - Failure (if any of the environment variables are not set)
- `2` - Failure (incorrect usage of function)

**Usage:**
```bash
check_env_vars PATH HOME
```
</details>

<!------------------------------------------------>

<details>
  <summary>check_required_bins</summary>

Checks if binary exists by running `command -v <binary>`.

**Environment Variables:**
- `VERBOSE`: If set to true, print verbose output (optional, defaults to false)

**Arguments:**
- `$1..n`: binaries to check

**Returns:**
- `0` - Success (all binaries are found)
- `1` - Failure (if any of the binaries are not found)
- `2` - Failure (incorrect usage of function)

**Usage:**
```bash
check_required_bins git jq
```
</details>

<!------------------------------------------------>

<details>
  <summary>install_jq</summary>

Installs jq binary.

**Environment Variables:**
- `VERBOSE`: If set to true, print verbose output (optional, defaults to false)

**Arguments:**
- `$1`: version of jq to install (optional, defaults to latest). Example format of valid version is "1.8.1"
- `$2`: location to install jq to (optional, defaults to /usr/local/bin)
- `$3`: if set to true, skips installation if jq is already detected (optional, defaults to true)
- `$4`: the exact url to download jq from (optional, defaults to https://github.com/jqlang/jq/releases/latest/download/jq-${os}-${arch})

**Returns:**
- `0` - Success (jq installed successfully)
- `1` - Failure (installation failed)
- `2` - Failure (incorrect usage of function)

**Usage:**
```bash
install_jq "latest" "/usr/local/bin" "true"
```
</details>

<!------------------------------------------------>

<details>
  <summary>install_kubectl</summary>

Installs the kubectl binary.

**Environment Variables:**
- `VERBOSE`: If set to true, print verbose output (optional, defaults to false)

**Arguments:**
- `$1`: version of kubectl to install (optional, defaults to current latest stable). Example format: "v1.34.2"
- `$2`: location to install kubectl (optional, defaults to /usr/local/bin)
- `$3`: if set to true, skips installation if kubectl is already detected (optional, defaults to true)
- `$4`: the exact URL to download kubectl from (optional, defaults to https://dl.k8s.io/release/<version>/bin/<os>/<arch>/kubectl)

**Returns:**
- `0` - Success (kubectl installation successful)
- `1` - Failure (kubectl installation failed)
- `2` - Failure (incorrect usage of function)

**Usage:**
```bash
install_kubectl "latest" "/usr/local/bin" "true"
```
</details>

<!------------------------------------------------>
<details>
  <summary>is_boolean</summary>

Determine if value is a boolean.

**Arguments:**
- `$1`: value to check (required)

**Returns:**
- `0` - Success (value is a boolean - true, True, false or False)
- `1` - Failure (value is not a boolean)
- `2` - Failure (incorrect usage of function)

**Usage:**
```bash
is_boolean "true"
```
</details>

<!------------------------------------------------>

<details>
  <summary>return_mac_architecture</summary>

Returns the architecture of the MacOS.

**Arguments:** n/a

**Returns:**
- `0` - Success
  - `"amd64"` - if the OS is macOS and the CPU is Intel
  - `"arm64"` - if the OS is macOS and the CPU is Apple Silicon
- `2` - Failure (Did not detect MacOS)

**Usage:**
```bash
arch=$(return_mac_architecture)
```
</details>

<!------------------------------------------------>

## [ibmcloud/iam](ibmcloud/iam.sh)
<details>
  <summary>generate_iam_bearer_token</summary>

Generates an IBM Cloud IAM bearer token from an API key.

**Environment Variables:**
- `IBMCLOUD_API_KEY`: IBM Cloud API key (required)
- `IBMCLOUD_IAM_API_ENDPOINT`: IBM Cloud IAM API endpoint (optional, defaults to https://iam.cloud.ibm.com)

**Arguments:** n/a

**Returns:**
- `0` - Success (token printed to stdout)
- `1` - Failure (error message printed to stderr)

**Usage:**
```bash
IBMCLOUD_API_KEY=XXX; token=$(generate_iam_bearer_token)
```
</details>

<!------------------------------------------------>

## [ibmcloud/cli](ibmcloud/cli.sh)
<details>
  <summary>install_ibmcloud</summary>

Installs the IBM Cloud CLI (ibmcloud).

**Environment Variables:**
- `VERBOSE`: If set to true, prints verbose output (optional, defaults to false)

**Arguments:**
- `$1`: version of IBM Cloud CLI to install (optional, defaults to "latest"). Example format: `"2.41.0"` or `"latest"`
- `$2`: location to install ibmcloud binary (optional, defaults to /tmp)
- `$3`: skip installation if ibmcloud is already detected (optional, defaults to "true"). Accepts `"true"` or `"false"`
- `$4`: exact installer URL (optional, overrides automatic URL construction)

**Returns:**
- `0` - Success (IBM Cloud CLI installed successfully or skipped if already present)
- `1` - Failure (installation failed)
- `2` - Failure (incorrect usage of function, e.g., invalid boolean for $3)

**Usage:**
```bash
# Install latest version
install_ibmcloud

# Install specific version
install_ibmcloud "2.41.0" "/usr/local/bin" "true"
```
</details>

<!------------------------------------------------>

## Usage

### Sourcing the Library

To use the common functions in your bash scripts, source the library:

```bash
source /path/to/common/common.sh
```

For IBM Cloud specific functions, source the respective modules:

```bash
# For IBM Cloud CLI functions
source /path/to/ibmcloud/cli.sh

# For IBM Cloud IAM functions
source /path/to/ibmcloud/iam.sh
```

Note: The ibmcloud modules automatically source `common/common.sh`, so you don't need to source it separately when using ibmcloud functions.

### Running Tests

The library includes built-in unit tests. To run them, execute this script:

```bash
tests/run-tests.sh
```

NOTE: Some unit tests are configured to make api calls. These are disabled by default, but can be enabled by setting `MAKE_API_CALLS=true`. This will require setting environment variable `IBMCLOUD_API_KEY` with a valid IBM Cloud API key.
