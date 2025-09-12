#!/usr/bin/env bash
# Custom assertion functions for e2e bats testing

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-File $file should exist}"
    
    if [[ ! -f "$file" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "File $file does not exist"
        return 1
    fi
}

# Assert that a file does not exist
assert_file_not_exists() {
    local file="$1"
    local message="${2:-File $file should not exist}"
    
    if [[ -f "$file" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "File $file exists but should not"
        return 1
    fi
}

# Assert that a directory exists
assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory $dir should exist}"
    
    if [[ ! -d "$dir" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "Directory $dir does not exist"
        return 1
    fi
}

# Assert that a git repository is valid
assert_git_repo() {
    local repo_dir="$1"
    local message="${2:-$repo_dir should be a valid git repository}"
    
    if ! git -C "$repo_dir" rev-parse --is-bare-repository > /dev/null 2>&1 && \
       ! git -C "$repo_dir" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "ASSERTION FAILED: $message"
        echo "Directory $repo_dir is not a valid git repository"
        return 1
    fi
}

# Assert that a JSON file is valid
assert_valid_json() {
    local json_file="$1"
    local message="${2:-$json_file should contain valid JSON}"
    
    if ! jq empty "$json_file" > /dev/null 2>&1; then
        echo "ASSERTION FAILED: $message"
        echo "File $json_file does not contain valid JSON"
        return 1
    fi
}

# Assert that a file contains specific content
assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local message="${3:-File $file should contain pattern $pattern}"
    
    if ! grep -q "$pattern" "$file"; then
        echo "ASSERTION FAILED: $message"
        echo "File $file does not contain pattern: $pattern"
        return 1
    fi
}

# Assert that a file does not contain specific content
assert_file_not_contains() {
    local file="$1"
    local pattern="$2"
    local message="${3:-File $file should not contain pattern $pattern}"
    
    if grep -q "$pattern" "$file"; then
        echo "ASSERTION FAILED: $message"
        echo "File $file contains pattern but should not: $pattern"
        return 1
    fi
}

# Assert that a command succeeds
assert_command_succeeds() {
    local command="$1"
    local message="${2:-Command should succeed: $command}"
    
    if ! eval "$command"; then
        echo "ASSERTION FAILED: $message"
        echo "Command failed: $command"
        return 1
    fi
}

# Assert that a command fails
assert_command_fails() {
    local command="$1"
    local message="${2:-Command should fail: $command}"
    
    if eval "$command"; then
        echo "ASSERTION FAILED: $message"
        echo "Command succeeded but should have failed: $command"
        return 1
    fi
}

# Assert that a file has expected size (within range)
assert_file_size() {
    local file="$1"
    local min_size="$2"
    local max_size="$3"
    local message="${4:-File $file should be between $min_size and $max_size bytes}"
    
    if [[ ! -f "$file" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "File $file does not exist"
        return 1
    fi
    
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    
    if [[ $size -lt $min_size || $size -gt $max_size ]]; then
        echo "ASSERTION FAILED: $message"
        echo "File $file size is $size bytes, expected between $min_size and $max_size"
        return 1
    fi
}

# Assert that a git repository has expected number of commits
assert_commit_count() {
    local repo_dir="$1"
    local expected_count="$2"
    local message="${3:-Repository should have $expected_count commits}"
    
    local actual_count=$(git -C "$repo_dir" rev-list --all --count)
    
    if [[ $actual_count -ne $expected_count ]]; then
        echo "ASSERTION FAILED: $message"
        echo "Repository has $actual_count commits, expected $expected_count"
        return 1
    fi
}

# Assert that a log file contains expected progress information
assert_progress_log() {
    local log_file="$1"
    local message="${2:-Progress log should contain commit processing information}"
    
    if [[ ! -f "$log_file" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "Progress log file $log_file does not exist"
        return 1
    fi
    
    if ! grep -q "processed" "$log_file"; then
        echo "ASSERTION FAILED: $message"
        echo "Progress log does not contain processing information"
        return 1
    fi
}

# Assert that statistics file contains expected data
assert_stats_file() {
    local stats_file="$1"
    local message="${2:-Statistics file should contain valid data}"
    
    if [[ ! -f "$stats_file" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "Statistics file $stats_file does not exist"
        return 1
    fi
    
    if ! jq -e '.total_commits' "$stats_file" > /dev/null 2>&1; then
        echo "ASSERTION FAILED: $message"
        echo "Statistics file does not contain total_commits field"
        return 1
    fi
}

# Assert that a secret is not found in any file in the repository
assert_secret_not_found() {
    local repo_dir="$1"
    local secret="$2"
    local message="${3:-Secret $secret should not be found in repository}"
    
    local work_dir="$TEST_TEMP_DIR/verify-secret"
    git clone "$repo_dir" "$work_dir"
    
    local found=0
    if grep -r "$secret" "$work_dir" > /dev/null 2>&1; then
        found=1
    fi
    
    rm -rf "$work_dir"
    
    if [[ $found -eq 1 ]]; then
        echo "ASSERTION FAILED: $message"
        echo "Secret $secret was found in the repository"
        return 1
    fi
}

# Assert that a file exists in the repository
assert_file_in_repo() {
    local repo_dir="$1"
    local file_path="$2"
    local message="${3:-File $file_path should exist in repository}"
    
    local work_dir="$TEST_TEMP_DIR/verify-file"
    git clone "$repo_dir" "$work_dir"
    
    if [[ ! -f "$work_dir/$file_path" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "File $file_path does not exist in repository"
        rm -rf "$work_dir"
        return 1
    fi
    
    rm -rf "$work_dir"
}

# Assert that a file does not exist in the repository
assert_file_not_in_repo() {
    local repo_dir="$1"
    local file_path="$2"
    local message="${3:-File $file_path should not exist in repository}"
    
    local work_dir="$TEST_TEMP_DIR/verify-file"
    git clone "$repo_dir" "$work_dir"
    
    if [[ -f "$work_dir/$file_path" ]]; then
        echo "ASSERTION FAILED: $message"
        echo "File $file_path exists in repository but should not"
        rm -rf "$work_dir"
        return 1
    fi
    
    rm -rf "$work_dir"
}

# Assert that the output contains specific content
assert_output_contains() {
    local pattern="$1"
    local message="${2:-Output should contain pattern $pattern}"
    
    if ! echo "$output" | grep -q "$pattern"; then
        echo "ASSERTION FAILED: $message"
        echo "Output does not contain pattern: $pattern"
        echo "Actual output:"
        echo "$output"
        return 1
    fi
}

# Assert that the output does not contain specific content
assert_output_not_contains() {
    local pattern="$1"
    local message="${2:-Output should not contain pattern $pattern}"
    
    if echo "$output" | grep -q "$pattern"; then
        echo "ASSERTION FAILED: $message"
        echo "Output contains pattern but should not: $pattern"
        echo "Actual output:"
        echo "$output"
        return 1
    fi
}
