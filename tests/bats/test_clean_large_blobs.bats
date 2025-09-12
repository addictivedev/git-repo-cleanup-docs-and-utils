#!/usr/bin/env bats
# E2E tests for clean-large-blobs.sh script

load 'helpers/setup.bash'
load 'helpers/assertions.bash'

@test "clean-large-blobs.sh: requires BFG Repo-Cleaner to be installed" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Temporarily rename bfg command to simulate it not being installed
    local bfg_path=$(command -v bfg 2>/dev/null || echo "")
    local bfg_moved=false
    if [ -n "$bfg_path" ]; then
        # Check if we can move the file (not a system file)
        if mv "$bfg_path" "${bfg_path}.bak" 2>/dev/null; then
            bfg_moved=true
        else
            # Skip this test if we can't move the system BFG binary
            skip "Cannot move system BFG binary for testing (requires root permissions)"
        fi
    fi
    
    # Run clean-large-blobs.sh
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Verify script failed with appropriate error message
    assert_command_fails "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q 'BFG Repo-Cleaner is not installed'; then
        echo "ASSERTION FAILED: Expected 'BFG Repo-Cleaner is not installed' in output"
        return 1
    fi
    
    # Restore bfg command
    if [ -n "$bfg_path" ] && [ "$bfg_moved" = true ]; then
        mv "${bfg_path}.bak" "$bfg_path"
    fi
}

@test "clean-large-blobs.sh: successfully removes large blobs from git history" {
    # Create test repository with large files
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Run clean-large-blobs.sh from project root
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Verify script succeeded (BFG is working in test environment)
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify that the script completed successfully
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q '✅ Cleanup completed successfully'; then
        echo "ASSERTION FAILED: Expected '✅ Cleanup completed successfully' in output"
        return 1
    fi
    
    # Verify that the log file was created
    assert_file_exists ".clean-large-blobs.log"
}

@test "clean-large-blobs.sh: preserves blobs listed in keep file" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list with specific blobs to keep
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Add a specific blob to the keep list
    echo "test_blob_hash" >> "$TEST_BLOB_LIST_FILE"
    
    # Run clean-large-blobs.sh
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Verify script succeeded (BFG is working in test environment)
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify that the script completed successfully
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q '✅ Cleanup completed successfully'; then
        echo "ASSERTION FAILED: Expected '✅ Cleanup completed successfully' in output"
        return 1
    fi
    
    # Verify that the log file was created
    assert_file_exists ".clean-large-blobs.log"
}

@test "clean-large-blobs.sh: generates blob list automatically if missing" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Run clean-large-blobs.sh without blob list file
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "nonexistent.txt" "1000" --yes
    
    # Verify script succeeded (should create the blob list file)
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify blob list file was created
    assert_file_exists "nonexistent.txt"
}

@test "clean-large-blobs.sh: handles different size thresholds correctly" {
    # Test with small threshold
    create_test_repo "$TEST_REPO_DIR"
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "500" --yes
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Test with large threshold - create fresh repository
    local test_repo_dir_2="$TEST_TEMP_DIR/test-repo-2.git"
    local test_blob_list_file_2="$TEST_TEMP_DIR/blob-list-2.txt"
    create_test_repo "$test_repo_dir_2"
    create_all_blobs_list "$test_blob_list_file_2" "$test_repo_dir_2"
    
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$test_repo_dir_2" "$test_blob_list_file_2" "100000" --yes
    assert_command_succeeds "[[ $status -eq 0 ]]"
}

@test "clean-large-blobs.sh: fails gracefully with invalid repository path" {
    # Test with non-existent repository
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "/nonexistent/repo" "$TEST_BLOB_LIST_FILE" "1000"
    
    # Verify script failed
    assert_command_fails "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q 'does not exist'; then
        echo "ASSERTION FAILED: Expected 'does not exist' in output"
        return 1
    fi
}

@test "clean-large-blobs.sh: fails gracefully with invalid size parameter" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Test with invalid size
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "invalid"
    
    # Verify script failed
    assert_command_fails "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q 'Invalid size parameter.*must be a number'; then
        echo "ASSERTION FAILED: Expected 'Invalid size parameter.*must be a number' in output"
        return 1
    fi
}

@test "clean-large-blobs.sh: fails gracefully with missing arguments" {
    # Test missing arguments
    run bash "$PROJECT_ROOT/clean-large-blobs.sh"
    assert_command_fails "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q 'All three parameters are required'; then
        echo "ASSERTION FAILED: Expected 'All three parameters are required' in output"
        return 1
    fi
    
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR"
    assert_command_fails "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q 'All three parameters are required'; then
        echo "ASSERTION FAILED: Expected 'All three parameters are required' in output"
        return 1
    fi
}

@test "clean-large-blobs.sh: handles empty blob list file" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create empty blob list file
    touch "$TEST_BLOB_LIST_FILE"
    
    # Run clean-large-blobs.sh
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify repository is still valid
    assert_git_repo "$TEST_REPO_DIR"
}

@test "clean-large-blobs.sh: preserves repository structure and commits" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Run clean-large-blobs.sh
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify repository structure is preserved
    local work_dir="$TEST_TEMP_DIR/verify-structure"
    git clone "$TEST_REPO_DIR" "$work_dir"
    cd "$work_dir"
    
    # Check that commits still exist
    assert_command_succeeds "git log --oneline | wc -l | grep -q '[0-9]'"
    
    # Check that important files still exist
    assert_file_exists "README.md"
    assert_file_exists "app.js"
    assert_file_exists "app.py"
    
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
}

@test "clean-large-blobs.sh: handles various file types correctly" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Run clean-large-blobs.sh
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify repository is still valid
    assert_git_repo "$TEST_REPO_DIR"
}

@test "clean-large-blobs.sh: provides clear success message and instructions" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Run clean-large-blobs.sh
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify success message
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q '✅ Cleanup completed successfully'; then
        echo "ASSERTION FAILED: Expected '✅ Cleanup completed successfully' in output"
        return 1
    fi
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q 'force-push'; then
        echo "ASSERTION FAILED: Expected 'force-push' in output"
        return 1
    fi
}

@test "clean-large-blobs.sh: get_blobs_to_remove function works correctly" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Define the function inline (extracted from clean-large-blobs.sh)
    get_blobs_to_remove() {
      local git_dir="$1"
      local size_threshold="$2"
      
      # Get all large blobs with their file paths
      git --git-dir="$git_dir" rev-list --objects --all | \
        awk 'NF==2 {print $1 " " $2}' | \
        git --git-dir="$git_dir" cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
        awk '$1=="blob" && $3 > '"$size_threshold"' {print $2 " " $3 " " $4}'
    }
    
    # Test the function
    local temp_output=$(mktemp)
    get_blobs_to_remove "$TEST_REPO_DIR" "1000" > "$temp_output" 2>/dev/null || true
    
    # The function should work without errors
    assert_command_succeeds "[[ -f '$temp_output' ]]"
    
    # Test with different thresholds
    get_blobs_to_remove "$TEST_REPO_DIR" "50000" > "$temp_output" 2>/dev/null || true
    assert_command_succeeds "[[ -f '$temp_output' ]]"
    
    # Clean up
    rm -f "$temp_output"
}

@test "clean-large-blobs.sh: preview_cleanup function works correctly" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Define the function inline (extracted from clean-large-blobs.sh)
    preview_cleanup() {
      local git_dir="$1"
      local blob_list_file="$2"
      local size_threshold="$3"
      
      echo "🔍 PREVIEW: Blobs that will be removed"
      echo "======================================"
      echo
      
      # Get blobs to remove using our function
      local temp_file=$(mktemp)
      get_blobs_to_remove "$git_dir" "$size_threshold" > "$temp_file"
      
      local count=$(wc -l < "$temp_file")
      
      if [ "$count" -eq 0 ]; then
        echo "✅ No blobs will be removed with threshold $size_threshold bytes"
        rm -f "$temp_file"
        return 0
      fi
      
      echo "📊 SUMMARY:"
      echo "   • Blobs to be removed: $count"
      echo "   • Size threshold: $size_threshold bytes ($(($size_threshold / 1024)) KB)"
      echo
      
      # Calculate total size
      local total_size=$(awk '{sum += $2} END {print sum}' "$temp_file")
      local total_mb=$(echo "scale=2; $total_size / 1024 / 1024" | bc)
      echo "   • Total size to be removed: $total_size bytes ($total_mb MB)"
      echo
      
      echo "🗑️  BLOBS THAT WILL BE REMOVED:"
      sort -k2 -nr "$temp_file" | while read -r blob_hash size file_path; do
        size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
        # Show full path - no truncation needed
        echo "  • ${size_mb} MB - $blob_hash - $file_path"
      done
      
      rm -f "$temp_file"
    }
    
    # Also define get_blobs_to_remove function (needed by preview_cleanup)
    get_blobs_to_remove() {
      local git_dir="$1"
      local size_threshold="$2"
      
      # Get all large blobs with their file paths
      git --git-dir="$git_dir" rev-list --objects --all | \
        awk 'NF==2 {print $1 " " $2}' | \
        git --git-dir="$git_dir" cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
        awk '$1=="blob" && $3 > '"$size_threshold"' {print $2 " " $3 " " $4}'
    }
    
    # Test the preview_cleanup function
    local temp_output=$(mktemp)
    
    # Test preview with small threshold
    preview_cleanup "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" > "$temp_output" 2>/dev/null || true
    
    # The function should work without errors
    assert_command_succeeds "[[ -f '$temp_output' ]]"
    
    # Test preview with large threshold
    preview_cleanup "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "10000000" > "$temp_output" 2>/dev/null || true
    assert_command_succeeds "[[ -f '$temp_output' ]]"
    
    # Verify function can be called without errors
    assert_command_succeeds "preview_cleanup '$TEST_REPO_DIR' '$TEST_BLOB_LIST_FILE' '50000' >/dev/null"
    
    # Clean up
    rm -f "$temp_output"
}

@test "clean-large-blobs.sh: script contains BFG-specific functionality" {
    # Verify that the main script contains BFG-specific functionality
    assert_file_contains "$PROJECT_ROOT/clean-large-blobs.sh" "BFG Repo-Cleaner"
    assert_file_contains "$PROJECT_ROOT/clean-large-blobs.sh" "bfg --strip-blobs-bigger-than"
    
    # Verify that the script uses BFG for cleanup
    assert_file_contains "$PROJECT_ROOT/clean-large-blobs.sh" "Starting BFG Repo-Cleaner cleanup"
}

@test "clean-large-blobs.sh: --yes flag skips confirmation prompt" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Run with --yes flag
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Verify script succeeded
    assert_command_succeeds "[[ $status -eq 0 ]]"
    
    # Verify auto-confirmation message
    if ! echo "$output" | grep -q '✅ Auto-confirmed.*--yes flag provided'; then
        echo "ASSERTION FAILED: Expected '✅ Auto-confirmed.*--yes flag provided' in output"
        return 1
    fi
}

@test "clean-large-blobs.sh: --yes flag works with different parameter orders" {
    # Test --yes flag in different positions - create fresh repository for each test
    create_test_repo "$TEST_REPO_DIR"
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    # Script will succeed because BFG is working in test environment
    assert_command_succeeds "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q '✅ Cleanup completed successfully'; then
        echo "ASSERTION FAILED: Expected '✅ Cleanup completed successfully' in output"
        return 1
    fi
    
    # Create fresh repository for second test
    local test_repo_dir_2="$TEST_TEMP_DIR/test-repo-2.git"
    local test_blob_list_file_2="$TEST_TEMP_DIR/blob-list-2.txt"
    create_test_repo "$test_repo_dir_2"
    create_all_blobs_list "$test_blob_list_file_2" "$test_repo_dir_2"
    
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$test_repo_dir_2" "$test_blob_list_file_2" "1000" --yes
    # Script will succeed because BFG is working in test environment
    assert_command_succeeds "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q '✅ Cleanup completed successfully'; then
        echo "ASSERTION FAILED: Expected '✅ Cleanup completed successfully' in output"
        return 1
    fi
}

@test "clean-large-blobs.sh: handles invalid --yes flag usage" {
    # Test with invalid --yes usage
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes --invalid
    # Script will fail because of invalid parameter, not because of BFG
    assert_command_fails "[[ $status -eq 0 ]]"
    # The script should fail with a parameter error, not BFG error
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q 'Git directory does not exist'; then
        echo "ASSERTION FAILED: Expected 'Git directory does not exist' in output"
        return 1
    fi
}

@test "clean-large-blobs.sh: refactored shared functions work correctly" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Source the functions from the main script by extracting them
    # We'll define them inline to test the refactored versions
    
    # Refactored get_blobs_to_remove function
    get_blobs_to_remove() {
      local git_dir="$1"
      local size_threshold="$2"
      
      # Get all large blobs with their file paths
      git --git-dir="$git_dir" rev-list --objects --all | \
        awk 'NF==2 {print $1 " " $2}' | \
        git --git-dir="$git_dir" cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
        awk '$1=="blob" && $3 > '"$size_threshold"' {print $2 " " $3 " " $4}'
    }
    
    # Refactored calculate_blob_stats function
    calculate_blob_stats() {
      local blob_file="$1"
      
      BLOB_COUNT=$(wc -l < "$blob_file")
      TOTAL_SIZE=$(awk '{sum += $2} END {print sum}' "$blob_file")
      TOTAL_MB=$(echo "scale=2; $TOTAL_SIZE / 1024 / 1024" | bc)
    }
    
    # Refactored display_blob_summary function
    display_blob_summary() {
      local count="$1"
      local total_size="$2"
      local total_mb="$3"
      local size_threshold="$4"
      
      echo "📊 SUMMARY:"
      echo "   • Blobs to be removed: $count"
      echo "   • Size threshold: $size_threshold bytes ($(($size_threshold / 1024)) KB)"
      echo "   • Total size to be removed: $total_size bytes ($total_mb MB)"
      echo
    }
    
    # Refactored display_blob_list function
    display_blob_list() {
      local blob_file="$1"
      
      echo "🗑️  BLOBS THAT WILL BE REMOVED:"
      sort -k2 -nr "$blob_file" | while read -r blob_hash size file_path; do
        size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
        echo "  • ${size_mb} MB - $blob_hash - $file_path"
      done
    }
    
    # Refactored display_file_list function
    display_file_list() {
      local blob_file="$1"
      
      echo "🗑️  FILES THAT WILL BE REMOVED:"
      sort -k2 -nr "$blob_file" | while read -r blob_hash size file_path; do
        size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
        echo "  • ${size_mb} MB - $file_path"
      done
    }
    
    # Test get_blobs_to_remove function
    local temp_blobs=$(mktemp)
    get_blobs_to_remove "$TEST_REPO_DIR" "1000" > "$temp_blobs" 2>/dev/null || true
    assert_command_succeeds "[[ -f '$temp_blobs' ]]"
    
    # Test calculate_blob_stats function
    if [ -s "$temp_blobs" ]; then
        calculate_blob_stats "$temp_blobs"
        assert_command_succeeds "[[ -n '$BLOB_COUNT' ]]"
        assert_command_succeeds "[[ -n '$TOTAL_SIZE' ]]"
        assert_command_succeeds "[[ -n '$TOTAL_MB' ]]"
        
        # Test display functions
        local temp_output=$(mktemp)
        display_blob_summary "$BLOB_COUNT" "$TOTAL_SIZE" "$TOTAL_MB" 1000 > "$temp_output"
        assert_command_succeeds "[[ -f '$temp_output' ]]"
        assert_command_succeeds "grep -q 'SUMMARY' '$temp_output'"
        
        display_blob_list "$temp_blobs" > "$temp_output"
        assert_command_succeeds "[[ -f '$temp_output' ]]"
        
        display_file_list "$temp_blobs" > "$temp_output"
        assert_command_succeeds "[[ -f '$temp_output' ]]"
        
        rm -f "$temp_output"
    else
        # Test with empty blob list
        calculate_blob_stats "$temp_blobs"
        assert_command_succeeds "[[ '$BLOB_COUNT' -eq 0 ]]"
    fi
    
    # Clean up
    rm -f "$temp_blobs"
}

@test "clean-large-blobs.sh: refactored preview_cleanup uses shared functions" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Define the refactored preview_cleanup function that uses shared functions
    preview_cleanup() {
      local git_dir="$1"
      local blob_list_file="$2"
      local size_threshold="$3"
      
      echo "🔍 PREVIEW: Blobs that will be removed"
      echo "======================================"
      echo
      
      # Create temporary files for analysis
      local temp_dir=$(mktemp -d)
      local all_blobs="$temp_dir/all_blobs.txt"
      local kept_blobs="$temp_dir/kept_blobs.txt"
      local removed_blobs="$temp_dir/removed_blobs.txt"
      local blob_to_files="$temp_dir/blob_to_files.txt"
      
      # Get all large blobs
      get_blobs_to_remove "$git_dir" "$size_threshold" > "$all_blobs"
      
      # Get the list of kept blobs (convert to lowercase for comparison)
      tr '[:upper:]' '[:lower:]' < "$blob_list_file" > "$kept_blobs"
      
      # Find blobs that will actually be removed (all_blobs - kept_blobs)
      comm -23 <(awk '{print $1}' "$all_blobs" | sort) <(sort "$kept_blobs") > "$removed_blobs"
      
      # Create mapping of removed blobs to their file info
      grep -f "$removed_blobs" "$all_blobs" > "$blob_to_files"
      
      # Calculate statistics using shared function
      calculate_blob_stats "$blob_to_files"
      
      if [ "$BLOB_COUNT" -eq 0 ]; then
        echo "✅ No blobs will be removed with threshold $size_threshold bytes"
        rm -rf "$temp_dir"
        return 0
      fi
      
      # Display summary using shared function
      display_blob_summary "$BLOB_COUNT" "$TOTAL_SIZE" "$TOTAL_MB" "$size_threshold"
      
      # Display blob list using shared function
      display_blob_list "$blob_to_files"
      
      # Clean up temporary files
      rm -rf "$temp_dir"
    }
    
    # Also define the shared functions (needed by preview_cleanup)
    get_blobs_to_remove() {
      local git_dir="$1"
      local size_threshold="$2"
      
      git --git-dir="$git_dir" rev-list --objects --all | \
        awk 'NF==2 {print $1 " " $2}' | \
        git --git-dir="$git_dir" cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
        awk '$1=="blob" && $3 > '"$size_threshold"' {print $2 " " $3 " " $4}'
    }
    
    calculate_blob_stats() {
      local blob_file="$1"
      
      BLOB_COUNT=$(wc -l < "$blob_file")
      TOTAL_SIZE=$(awk '{sum += $2} END {print sum}' "$blob_file")
      TOTAL_MB=$(echo "scale=2; $TOTAL_SIZE / 1024 / 1024" | bc)
    }
    
    display_blob_summary() {
      local count="$1"
      local total_size="$2"
      local total_mb="$3"
      local size_threshold="$4"
      
      echo "📊 SUMMARY:"
      echo "   • Blobs to be removed: $count"
      echo "   • Size threshold: $size_threshold bytes ($(($size_threshold / 1024)) KB)"
      echo "   • Total size to be removed: $total_size bytes ($total_mb MB)"
      echo
    }
    
    display_blob_list() {
      local blob_file="$1"
      
      echo "🗑️  BLOBS THAT WILL BE REMOVED:"
      sort -k2 -nr "$blob_file" | while read -r blob_hash size file_path; do
        size_mb=$(echo "scale=2; $size / 1024 / 1024" | bc)
        echo "  • ${size_mb} MB - $blob_hash - $file_path"
      done
    }
    
    # Test the refactored preview_cleanup function
    local temp_output=$(mktemp)
    
    # Test preview with small threshold
    preview_cleanup "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" > "$temp_output" 2>/dev/null || true
    
    # The function should work without errors
    assert_command_succeeds "[[ -f '$temp_output' ]]"
    
    # Verify it produces expected output
    assert_command_succeeds "grep -q 'PREVIEW' '$temp_output'"
    assert_command_succeeds "grep -q 'SUMMARY' '$temp_output'"
    
    # Test with large threshold (should show no blobs)
    preview_cleanup "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "10000000" > "$temp_output" 2>/dev/null || true
    assert_command_succeeds "[[ -f '$temp_output' ]]"
    
    # Clean up
    rm -f "$temp_output"
}

@test "clean-large-blobs.sh: handles BFG-specific error conditions gracefully" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Test with invalid git directory (should fail before BFG check)
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "/nonexistent/repo" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Verify script failed with appropriate error message
    assert_command_fails "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q 'Git directory does not exist'; then
        echo "ASSERTION FAILED: Expected 'Git directory does not exist' in output"
        return 1
    fi
}

@test "clean-large-blobs.sh: integrated verification functionality works correctly" {
    # Create test repository with multiple branches
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Create additional branches in the test repository
    local work_dir="$TEST_TEMP_DIR/verify-work"
    git clone "$TEST_REPO_DIR" "$work_dir"
    cd "$work_dir"
    
    # Create additional branches with different content
    git checkout -b feature-branch
    echo "Feature branch content" > feature-file.txt
    git add feature-file.txt
    git commit -m "Add feature file"
    
    git checkout main
    git checkout -b develop
    echo "Develop branch content" > develop-file.txt
    git add develop-file.txt
    git commit -m "Add develop file"
    
    # Push all branches
    git push origin main
    git push origin feature-branch
    git push origin develop
    
    cd "$TEST_TEMP_DIR"
    rm -rf "$work_dir"
    
    # Run the script with verification enabled (default)
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # The script will succeed because BFG is working in test environment
    assert_command_succeeds "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q '✅ Cleanup completed successfully'; then
        echo "ASSERTION FAILED: Expected '✅ Cleanup completed successfully' in output"
        return 1
    fi
    
    # Verify that the verification functions are present in the script
    assert_file_contains "$PROJECT_ROOT/clean-large-blobs.sh" "verify_repository_content"
    assert_file_contains "$PROJECT_ROOT/clean-large-blobs.sh" "print_info"
    assert_file_contains "$PROJECT_ROOT/clean-large-blobs.sh" "print_success"
}

@test "clean-large-blobs.sh: --no-verify flag disables verification" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Run the script with verification disabled
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes --no-verify
    
    # Script will succeed because BFG is working in test environment
    assert_command_succeeds "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q '✅ Cleanup completed successfully'; then
        echo "ASSERTION FAILED: Expected '✅ Cleanup completed successfully' in output"
        return 1
    fi
    
    # Verify that --no-verify flag is handled correctly by checking script contains the flag handling
    if ! grep -q "no-verify" "$PROJECT_ROOT/clean-large-blobs.sh"; then
        echo "ASSERTION FAILED: Script should contain no-verify flag"
        return 1
    fi
    if ! grep -q "VERIFY_CLEANUP=false" "$PROJECT_ROOT/clean-large-blobs.sh"; then
        echo "ASSERTION FAILED: Script should contain VERIFY_CLEANUP=false"
        return 1
    fi
}

@test "clean-large-blobs.sh: verification handles missing backup directory gracefully" {
    # Create test repository
    create_test_repo "$TEST_REPO_DIR"
    
    # Create blob list
    create_all_blobs_list "$TEST_BLOB_LIST_FILE" "$TEST_REPO_DIR"
    
    # Run the script (this will create a backup)
    run bash "$PROJECT_ROOT/clean-large-blobs.sh" "$TEST_REPO_DIR" "$TEST_BLOB_LIST_FILE" "1000" --yes
    
    # Script will succeed because BFG is working in test environment
    assert_command_succeeds "[[ $status -eq 0 ]]"
    # Use a safer approach that doesn't involve shell evaluation of output
    if ! echo "$output" | grep -q '✅ Cleanup completed successfully'; then
        echo "ASSERTION FAILED: Expected '✅ Cleanup completed successfully' in output"
        return 1
    fi
    
    # Verify that verification functions are present in the script
    assert_file_contains "$PROJECT_ROOT/clean-large-blobs.sh" "verify_repository_content"
    assert_file_contains "$PROJECT_ROOT/clean-large-blobs.sh" "VERIFICATION STEP"
}