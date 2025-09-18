#!/usr/bin/env bash
# Test setup and teardown functions for e2e bats testing

# Generate a test secret with a consistent pattern for testing
generate_test_secret() {
    local secret_type="$1"
    local timestamp=$(date +%s)
    local random_part=$(printf "%08x" $((RANDOM * RANDOM)))
    echo "test_${secret_type}_${timestamp}_${random_part}"
}

# Global test variables
TEST_TEMP_DIR=""
TEST_REPO_DIR=""
TEST_GITLEAKS_FILE=""
TEST_BLOB_LIST_FILE=""

# Setup function called before each test
setup() {
    # Create temporary directory for this test
    TEST_TEMP_DIR=$(mktemp -d)
    TEST_REPO_DIR="$TEST_TEMP_DIR/test-repo.git"
    TEST_GITLEAKS_FILE="$TEST_TEMP_DIR/gitleaks-output.json"
    TEST_BLOB_LIST_FILE="$TEST_TEMP_DIR/blob-list.txt"
    
    # Get absolute path to project root
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    
    # Ensure we're in the project root
    cd "$PROJECT_ROOT"
    
    # Debug: verify we're in the right place
    if [[ ! -f "clean-secrets.sh" ]]; then
        echo "ERROR: clean-secrets.sh not found in $(pwd)" >&2
        echo "BATS_TEST_DIRNAME: $BATS_TEST_DIRNAME" >&2
        echo "PROJECT_ROOT: $PROJECT_ROOT" >&2
        exit 1
    fi
}

# Teardown function called after each test
teardown() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Create a test git repository with secrets and large files (optimized for speed)
create_test_repo() {
    local repo_dir="$1"
    
    # Initialize bare repository
    git init --bare "$repo_dir"
    
    # Clone to working directory for commits
    local work_dir="$TEST_TEMP_DIR/work-repo"
    git clone "$repo_dir" "$work_dir"
    cd "$work_dir"
    
    # Configure git user for commits
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Configure default branch to avoid warnings
    git config init.defaultBranch main
    
    # Create initial commit with normal files
    echo "# Test Project" > README.md
    echo "console.log('Hello World');" > app.js
    echo "def hello(): pass" > app.py
    git add README.md app.js app.py
    git commit -m "Initial commit: Add basic project files"
    
    # Rename branch from master to main
    git branch -m main
    
    # Add commit with API keys and secrets
    echo "DATABASE_URL=postgresql://user:$(generate_test_secret 'db_pass')@localhost:5432/mydb" > .env
    echo "API_KEY=$(generate_test_secret 'api_key')" >> .env
    echo "TWITTER_TOKEN=$(generate_test_secret 'twitter_token')" >> .env
    echo "AWS_SECRET_KEY=$(generate_test_secret 'aws_key')" >> .env
    git add .env
    git commit -m "Add environment configuration with API keys"
    
    # Add commit with more secrets in different files
    echo "// Configuration file" > config.js
    echo "const API_KEY = '$(generate_test_secret 'openai_key')';" >> config.js
    echo "const SECRET_TOKEN = '$(generate_test_secret 'github_token')';" >> config.js
    echo "const DATABASE_PASSWORD = '$(generate_test_secret 'db_password')';" >> config.js
    git add config.js
    git commit -m "Add JavaScript configuration with GitHub and OpenAI keys"
    
    # Add commit with two large files of the same size
    dd if=/dev/zero of=important-database-backup.sql bs=1K count=100 2>/dev/null
    dd if=/dev/zero of=unnecessary-log-archive.zip bs=1K count=100 2>/dev/null
    git add important-database-backup.sql unnecessary-log-archive.zip
    git commit -m "Add important database backup and unnecessary log archive"
    
    # Add commit removing the unnecessary file (keeping the important one)
    git rm unnecessary-log-archive.zip
    git commit -m "Remove unnecessary log archive, keep important database backup"
    
    # Add commit modifying existing secret file
    echo "# Updated configuration" > .env
    echo "DATABASE_URL=postgresql://user:$(generate_test_secret 'db_pass_v2')@localhost:5432/mydb" >> .env
    echo "API_KEY=$(generate_test_secret 'api_key_v2')" >> .env
    echo "NEW_SECRET=$(generate_test_secret 'new_secret')" >> .env
    git add .env
    git commit -m "Update environment configuration with new secrets"
    
    # Add commit with secrets in Python file
    echo "import os" > settings.py
    echo "SECRET_KEY = '$(generate_test_secret 'django_secret')'" >> settings.py
    echo "EMAIL_PASSWORD = '$(generate_test_secret 'email_password')'" >> settings.py
    echo "REDIS_PASSWORD = '$(generate_test_secret 'redis_password')'" >> settings.py
    git add settings.py
    git commit -m "Add Django settings with secret keys"
    
    # Add commit with mixed content (secrets + normal code)
    echo "#!/bin/bash" > deploy.sh
    echo "echo 'Deploying application...'" >> deploy.sh
    echo "export DEPLOY_TOKEN='$(generate_test_secret 'deploy_token')'" >> deploy.sh
    echo "export BUILD_SECRET='$(generate_test_secret 'build_secret')'" >> deploy.sh
    echo "echo 'Deployment complete'" >> deploy.sh
    git add deploy.sh
    git commit -m "Add deployment script with embedded secrets"
    
    # Push all commits to bare repository
    git push origin main
    
    # Set HEAD reference in bare repository to point to main branch
    git --git-dir="$repo_dir" symbolic-ref HEAD refs/heads/main
    
    # Clean up working directory
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
}

# Create gitleaks output JSON for testing using real gitleaks
create_gitleaks_output() {
    local output_file="$1"
    
    echo "DEBUG: create_gitleaks_output called with: $output_file"
    echo "DEBUG: TEST_REPO_DIR: $TEST_REPO_DIR"
    echo "DEBUG: TEST_TEMP_DIR: $TEST_TEMP_DIR"
    
    # Check if gitleaks is available
    if ! command -v gitleaks >/dev/null 2>&1; then
        echo "ERROR: gitleaks not found. Please install gitleaks to run tests." >&2
        return 1
    fi
    
    # Create a temporary working directory for gitleaks
    local temp_work_dir="$TEST_TEMP_DIR/gitleaks-work"
    echo "DEBUG: Creating temp work dir: $temp_work_dir"
    mkdir -p "$temp_work_dir"
    
    # Check if the repository exists before trying to clone it
    if [[ ! -d "$TEST_REPO_DIR" ]]; then
        echo "ERROR: Test repository '$TEST_REPO_DIR' does not exist" >&2
        return 1
    fi
    
    # Clone the test repository to the temp directory
    echo "DEBUG: Cloning repo from $TEST_REPO_DIR to $temp_work_dir"
    if ! git clone "$TEST_REPO_DIR" "$temp_work_dir" 2>/dev/null; then
        echo "ERROR: Failed to clone repository '$TEST_REPO_DIR'" >&2
        return 1
    fi
    cd "$temp_work_dir"
    
    # Run gitleaks to generate real output
    echo "DEBUG: Running gitleaks in $(pwd)"
    echo "DEBUG: Files in directory: $(ls -la)"
    
    # Run gitleaks and capture both stdout and stderr
    echo "DEBUG: About to run gitleaks command"
    if gitleaks detect --source . --report-format json --report-path "$output_file" 2>&1; then
        echo "DEBUG: gitleaks completed successfully"
    else
        local exit_code=$?
        echo "DEBUG: gitleaks exited with code $exit_code (expected for test data with secrets)"
    fi
    
    echo "DEBUG: Checking if output file exists and has content"
    if [[ -f "$output_file" ]]; then
        echo "DEBUG: Output file exists at: $output_file"
        echo "DEBUG: File size: $(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null) bytes"
        echo "DEBUG: First 100 characters of file:"
        head -c 100 "$output_file" | cat -v
        echo ""
        echo "DEBUG: Last 100 characters of file:"
        tail -c 100 "$output_file" | cat -v
        echo ""
    else
        echo "ERROR: Output file not created: $output_file" >&2
        cd "$TEST_TEMP_DIR"
        rm -rf "$temp_work_dir"
        return 1
    fi
    
    # Clean up
    cd "$TEST_TEMP_DIR"
    rm -rf "$temp_work_dir"
    
    # Verify the output file is valid JSON
    if ! jq empty "$output_file" 2>/dev/null; then
        echo "ERROR: Generated gitleaks output is not valid JSON" >&2
        echo "DEBUG: First 200 characters of malformed file:" >&2
        head -c 200 "$output_file" | cat -v >&2
        echo "" >&2
        cd "$TEST_TEMP_DIR"
        rm -rf "$temp_work_dir"
        return 1
    fi
    
    local secret_count=$(jq length "$output_file" 2>/dev/null || echo "0")
    echo "Successfully generated real gitleaks output with $secret_count secrets"
    echo "DEBUG: First commit hash: $(jq -r '.[0].Commit // "NO_COMMITS"' "$output_file" 2>/dev/null)"
}

# Create blob list file with all repository blobs for testing
create_all_blobs_list() {
    local output_file="$1"
    local repo_dir="$2"
    
    # Get all blob IDs from the repository using --all to include all refs
    git --git-dir="$repo_dir" rev-list --objects --all \
        | git --git-dir="$repo_dir" cat-file --batch-check='%(objecttype) %(objectname)' \
        | awk '$1=="blob"{print $2}' > "$output_file"
}

# Verify that secrets were removed from repository
verify_secrets_removed() {
    local repo_dir="$1"
    local work_dir="$2"
    local gitleaks_file="${3:-$TEST_GITLEAKS_FILE}"
    
    # Clone the cleaned repository
    git clone "$repo_dir" "$work_dir"
    cd "$work_dir"
    
    # Check that secret lines are empty or removed by looking for test secret patterns
    local secrets_found=0
    
    # If gitleaks file is provided, check for specific secrets that were detected
    if [[ -f "$gitleaks_file" ]]; then
        # Extract secrets from gitleaks output and check if they still exist
        while IFS= read -r secret; do
            if [[ -n "$secret" ]]; then
                if grep -r "$secret" . >/dev/null 2>&1; then
                    echo "ERROR: Secret '$secret' still found in repository"
                    secrets_found=1
                fi
            fi
        done < <(jq -r '.[].Secret' "$gitleaks_file" 2>/dev/null)
    else
        # Fallback: Look for any test secrets that might still be present
        # Test secrets follow the pattern: test_<type>_<timestamp>_<random>
        if grep -r "test_.*_[0-9]\{10\}_[0-9a-f]\{8\}" . >/dev/null 2>&1; then
            echo "ERROR: Test secrets still found in repository"
            secrets_found=1
        fi
        
        # Also check for common secret patterns that gitleaks would detect
        if grep -r "sk-[a-zA-Z0-9]\{48\}" . >/dev/null 2>&1; then
            echo "ERROR: API keys still found in repository"
            secrets_found=1
        fi
        
        if grep -r "ghp_[a-zA-Z0-9]\{36\}" . >/dev/null 2>&1; then
            echo "ERROR: GitHub tokens still found in repository"
            secrets_found=1
        fi
    fi
    
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
    
    return $secrets_found
}

# Verify that large files were removed
verify_large_files_removed() {
    local repo_dir="$1"
    local work_dir="$2"
    
    # Clone the cleaned repository
    git clone "$repo_dir" "$work_dir"
    cd "$work_dir"
    
    local large_files_found=0
    
    # Check if large files still exist
    if [[ -f "important-database-backup.sql" ]]; then
        local size=$(stat -f%z "important-database-backup.sql" 2>/dev/null || stat -c%s "important-database-backup.sql" 2>/dev/null)
        if [[ $size -gt 100000 ]]; then  # 100KB threshold
            echo "ERROR: Important database backup file still exists (size: $size bytes)"
            large_files_found=1
        fi
    fi
    
    if [[ -f "unnecessary-log-archive.zip" ]]; then
        local size=$(stat -f%z "unnecessary-log-archive.zip" 2>/dev/null || stat -c%s "unnecessary-log-archive.zip" 2>/dev/null)
        if [[ $size -gt 100000 ]]; then  # 100KB threshold
            echo "ERROR: Unnecessary log archive file still exists (size: $size bytes)"
            large_files_found=1
        fi
    fi
    
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
    
    return $large_files_found
}

# Verify that important files are preserved
verify_important_files_preserved() {
    local repo_dir="$1"
    local work_dir="$2"
    
    # Clone the cleaned repository
    git clone "$repo_dir" "$work_dir"
    cd "$work_dir"
    
    local missing_files=0
    
    # Check that important files still exist
    for file in "README.md" "app.js" "app.py"; do
        if [[ ! -f "$file" ]]; then
            echo "ERROR: Important file $file is missing"
            missing_files=1
        fi
    done
    
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
    
    return $missing_files
}

# Create a test repository with multiple branches containing large files for protection testing
create_test_repo_with_branches() {
    local repo_dir="$1"
    
    # Initialize bare repository
    git init --bare "$repo_dir"
    
    # Clone to working directory for commits
    local work_dir="$TEST_TEMP_DIR/work-repo"
    git clone "$repo_dir" "$work_dir"
    cd "$work_dir"
    
    # Configure git user for commits
    git config user.name "Test User"
    git config user.email "test@example.com"
    git config init.defaultBranch main
    
    # Create initial commit with normal files
    echo "# Test Project" > README.md
    echo "console.log('Hello World');" > app.js
    echo "def hello(): pass" > app.py
    git add README.md app.js app.py
    git commit -m "Initial commit: Add basic project files"
    
    # Rename branch from master to main
    git branch -m main
    
    # Create feature branch with large file (should be protected)
    git checkout -b feature-branch
    dd if=/dev/zero of=protected-file-feature.sql bs=1K count=100 2>/dev/null
    git add protected-file-feature.sql
    git commit -m "Add protected large file to feature branch"
    
    # Create develop branch with large file (should be removed)
    git checkout main
    git checkout -b develop
    dd if=/dev/zero of=unprotected-file-develop.sql bs=1K count=100 2>/dev/null
    git add unprotected-file-develop.sql
    git commit -m "Add unprotected large file to develop branch"
    
    # Add more commits to make the large files not in the most recent commits
    echo "Additional content" > additional-file.txt
    git add additional-file.txt
    git commit -m "Add additional file to develop branch"
    
    # Go back to feature branch and add more commits
    git checkout feature-branch
    echo "Additional content" > additional-file-feature.txt
    git add additional-file-feature.txt
    git commit -m "Add additional file to feature branch"
    
    # Push all branches
    git push origin main
    git push origin feature-branch
    git push origin develop
    
    # Set HEAD reference in bare repository to point to main branch
    git --git-dir="$repo_dir" symbolic-ref HEAD refs/heads/main
    
    # Clean up working directory
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
}

# Verify that a specific file is protected (still exists) in a branch
verify_files_protected_in_branch() {
    local repo_dir="$1"
    local branch="$2"
    local filename="$3"
    
    # Clone the specific branch
    local work_dir="$TEST_TEMP_DIR/verify-protected-$branch"
    git clone --branch "$branch" --single-branch "$repo_dir" "$work_dir"
    cd "$work_dir"
    
    local file_protected=0
    if [[ -f "$filename" ]]; then
        local size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null)
        if [[ $size -gt 50000 ]]; then  # 50KB threshold
            echo "✅ File $filename is protected in branch $branch (size: $size bytes)"
            file_protected=0  # Success - file is protected
        else
            echo "ERROR: File $filename exists but is too small in branch $branch (size: $size bytes)"
            file_protected=1  # Failure - file is not properly protected
        fi
    else
        echo "ERROR: File $filename is missing from protected branch $branch"
        file_protected=1  # Failure - file is missing
    fi
    
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
    
    return $file_protected
}

# Verify that a specific file is removed from a branch
verify_files_removed_from_branch() {
    local repo_dir="$1"
    local branch="$2"
    local filename="$3"
    
    # Clone the specific branch
    local work_dir="$TEST_TEMP_DIR/verify-removed-$branch"
    git clone --branch "$branch" --single-branch "$repo_dir" "$work_dir"
    cd "$work_dir"
    
    local file_removed=0
    if [[ ! -f "$filename" ]]; then
        echo "✅ File $filename is correctly removed from branch $branch"
        file_removed=0  # Success - file is removed
    else
        local size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null)
        if [[ $size -lt 50000 ]]; then  # File exists but is small (removed from history)
            echo "✅ File $filename is removed from Git history in branch $branch (current size: $size bytes)"
            file_removed=0  # Success - file is removed from history
        else
            echo "ERROR: File $filename still exists and is large in branch $branch (size: $size bytes)"
            file_removed=1  # Failure - file is not removed
        fi
    fi
    
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
    
    return $file_removed
}
