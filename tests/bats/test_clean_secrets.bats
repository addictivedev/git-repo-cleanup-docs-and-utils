#!/usr/bin/env bats
# E2E tests for clean-secrets.sh script

load 'helpers/setup.bash'
load 'helpers/assertions.bash'

@test "clean-secrets.sh: successfully removes secrets from git history" {
    # Create test repository with secrets
    create_test_repo "$TEST_REPO_DIR"
    
    # Create gitleaks output
    create_gitleaks_output "$TEST_GITLEAKS_FILE"
    
    # Run clean-secrets.sh from project root
    run bash "$PROJECT_ROOT/clean-secrets.sh" "$TEST_REPO_DIR" "$TEST_GITLEAKS_FILE"
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify repository is still valid
    assert_git_repo "$TEST_REPO_DIR"
    
    # Verify secrets were removed
    local work_dir="$TEST_TEMP_DIR/verify-secrets"
    assert_command_succeeds "verify_secrets_removed '$TEST_REPO_DIR' '$work_dir' '$TEST_GITLEAKS_FILE'"
    
    # Verify important files are preserved
    assert_command_succeeds "verify_important_files_preserved '$TEST_REPO_DIR' '$work_dir'"
    
    # Verify log files were created
    assert_file_exists ".clean-secrets.log"
    assert_file_exists ".clean-secrets-commit-stats.json"
    assert_file_exists ".clean-secrets-callbacks.log"
    
    # Verify statistics file is valid
    assert_valid_json ".clean-secrets-commit-stats.json"
    assert_stats_file ".clean-secrets-commit-stats.json"
}

@test "clean-secrets.sh: handles multiple secrets in same file" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create gitleaks output with multiple secrets in same file
    create_gitleaks_output "$TEST_GITLEAKS_FILE"
    
    # Run clean-secrets.sh
    run bash "$PROJECT_ROOT/clean-secrets.sh" "$TEST_REPO_DIR" "$TEST_GITLEAKS_FILE"
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify secrets were removed by checking the gitleaks output
    local work_dir="$TEST_TEMP_DIR/verify-multiple-secrets"
    assert_command_succeeds "verify_secrets_removed '$TEST_REPO_DIR' '$work_dir' '$TEST_GITLEAKS_FILE'"
}

@test "clean-secrets.sh: preserves non-secret content in files with secrets" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create gitleaks output
    create_gitleaks_output "$TEST_GITLEAKS_FILE"
    
    # Run clean-secrets.sh
    run bash "$PROJECT_ROOT/clean-secrets.sh" "$TEST_REPO_DIR" "$TEST_GITLEAKS_FILE"
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify that files still exist (but secrets are removed)
    assert_file_in_repo "$TEST_REPO_DIR" ".env"
    assert_file_in_repo "$TEST_REPO_DIR" "config.js"
    assert_file_in_repo "$TEST_REPO_DIR" "settings.py"
    assert_file_in_repo "$TEST_REPO_DIR" "deploy.sh"
    
    # Verify that non-secret content is preserved
    local work_dir="$TEST_TEMP_DIR/verify-content"
    git clone "$TEST_REPO_DIR" "$work_dir"
    cd "$work_dir"
    
    # Check that non-secret content is still there
    # Note: Lines containing secrets are completely removed by clean-secrets.sh
    if [[ -f "config.js" ]]; then
        assert_file_contains "config.js" "Configuration file"
    fi
    
    if [[ -f "settings.py" ]]; then
        assert_file_contains "settings.py" "import os"
    fi
    
    if [[ -f "deploy.sh" ]]; then
        assert_file_contains "deploy.sh" "Deploying application"
    fi
    
    # Check that files still exist (even if secret lines were removed)
    assert_file_exists ".env"
    assert_file_exists "config.js"
    assert_file_exists "settings.py"
    assert_file_exists "deploy.sh"
    
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
}

@test "clean-secrets.sh: generates progress and statistics correctly" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create gitleaks output
    create_gitleaks_output "$TEST_GITLEAKS_FILE"
    
    # Run clean-secrets.sh
    run bash "$PROJECT_ROOT/clean-secrets.sh" "$TEST_REPO_DIR" "$TEST_GITLEAKS_FILE"
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify statistics file contains expected data
    assert_file_exists ".clean-secrets-commit-stats.json"
    assert_valid_json ".clean-secrets-commit-stats.json"
    
    # Verify log files contain progress information
    assert_file_exists ".clean-secrets.log"
    assert_file_contains ".clean-secrets.log" "Started at"
    assert_file_contains ".clean-secrets.log" "Completed at"
    
    # Verify callback log exists
    assert_file_exists ".clean-secrets-callbacks.log"
}

@test "clean-secrets.sh: fails gracefully with invalid repository path" {
    # Create minimal gitleaks output for error testing
    echo '[]' > "$TEST_GITLEAKS_FILE"
    
    # Run clean-secrets.sh with invalid repository
    run bash "$PROJECT_ROOT/clean-secrets.sh" "/nonexistent/repo" "$TEST_GITLEAKS_FILE"
    
    # Verify script failed
    assert_command_fails "[[ $status -eq 0 ]]"
    assert_command_succeeds "[[ $status -ne 0 ]]"
    
    # Verify error message
    assert_file_contains ".clean-secrets.log" "not a Git repository"
}

@test "clean-secrets.sh: fails gracefully with invalid gitleaks file" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create invalid gitleaks file
    echo "invalid json content" > "$TEST_GITLEAKS_FILE"
    
    # Run clean-secrets.sh
    run bash "$PROJECT_ROOT/clean-secrets.sh" "$TEST_REPO_DIR" "$TEST_GITLEAKS_FILE"
    
    # Verify script failed
    assert_command_fails "[[ $status -eq 0 ]]"
    assert_command_succeeds "[[ $status -ne 0 ]]"
}

@test "clean-secrets.sh: validates repository path correctly" {
    # Test with non-existent repository
    run bash "$PROJECT_ROOT/clean-secrets.sh" "/nonexistent/repo" "$TEST_GITLEAKS_FILE"
    
    # Verify script failed
    assert_command_fails "[[ $status -eq 0 ]]"
    assert_command_succeeds "echo '$output' | grep -q 'not a Git repository'"
}

@test "clean-secrets.sh: validates gitleaks file exists" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Test with non-existent gitleaks file
    run bash "$PROJECT_ROOT/clean-secrets.sh" "$TEST_REPO_DIR" "/nonexistent/gitleaks.json"
    
    # Verify script failed
    assert_command_fails "[[ $status -eq 0 ]]"
    assert_command_succeeds "echo '$output' | grep -q 'not found'"
}

@test "clean-secrets.sh: handles empty gitleaks file" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create empty gitleaks file
    echo "[]" > "$TEST_GITLEAKS_FILE"
    
    # Run clean-secrets.sh
    run bash "$PROJECT_ROOT/clean-secrets.sh" "$TEST_REPO_DIR" "$TEST_GITLEAKS_FILE"
    
    # Verify script succeeded (no secrets to remove)
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify repository is still valid
    assert_git_repo "$TEST_REPO_DIR"
}

@test "clean-secrets.sh: performs cleanup when --cleanup flag is provided" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create gitleaks output
    create_gitleaks_output "$TEST_GITLEAKS_FILE"
    
    # Run clean-secrets.sh with cleanup
    run bash "$PROJECT_ROOT/clean-secrets.sh" "$TEST_REPO_DIR" "$TEST_GITLEAKS_FILE" --cleanup
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify cleanup was performed
    assert_file_contains ".clean-secrets.log" "Performing final cleanup"
    
    # Verify temp files were cleaned up
    assert_file_not_exists "$TEST_REPO_DIR/full-scan.json"
}

@test "clean-secrets.sh: shows help message with --help flag" {
    # Test help flag variations
    run bash "$PROJECT_ROOT/clean-secrets.sh" --help
    assert_command_succeeds "[[ $status -eq 0 ]]"
    assert_command_succeeds "echo '$output' | grep -q 'Usage:'"
    
    run bash "$PROJECT_ROOT/clean-secrets.sh" "" --help
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    run bash "$PROJECT_ROOT/clean-secrets.sh" "" "" --help
    assert_command_succeeds "[[ $status -eq 0 ]]"
}

@test "clean-secrets.sh: handles missing arguments gracefully" {
    # Test missing arguments
    run bash "$PROJECT_ROOT/clean-secrets.sh"
    assert_command_fails "[[ $status -eq 0 ]]"
    assert_command_succeeds "echo '$output' | grep -q 'Missing arguments'"
    
    run bash "$PROJECT_ROOT/clean-secrets.sh" "$TEST_REPO_DIR"
    assert_command_fails "[[ $status -eq 0 ]]"
    assert_command_succeeds "echo '$output' | grep -q 'Missing arguments'"
}
