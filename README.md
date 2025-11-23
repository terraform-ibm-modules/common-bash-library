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

## Usage

### Sourcing the Library

To use these functions in your bash scripts, source the library:

```bash
source /path/to/common.sh
```

### Running Tests

The library includes built-in unit tests. To run them, execute this script:

```bash
tests/run-tests.sh
```

NOTE: Some unit tests are configured to make api calls. These are disabled by default, but can be enabled by setting `MAKE_API_CALLS=true`. This will require setting environment variable `IBMCLOUD_API_KEY` with a valid IBM Cloud API key.
