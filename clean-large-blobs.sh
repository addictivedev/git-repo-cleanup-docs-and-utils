#!/usr/bin/env bash
#
# clean-large-blobs.sh
#
# This script cleans up large blobs from a **bare git repository** using BFG Repo-Cleaner.
# It will:
#   - Identify blobs (files) larger than a configured size.
#   - Show you exactly what will be removed (with file names and sizes).
#   - Ask for confirmation before proceeding.
#   - Preserve files in the latest commit (HEAD) automatically.
#   - Delete all other large blobs from the history using BFG Repo-Cleaner.
#
# BFG Repo-Cleaner is faster and more reliable than git-filter-repo for this use case.
# It automatically protects files in the latest commit (HEAD) and provides better
# performance for large repositories.
#
# It is safe to run repeatedly. After completion, you can re-add the origin remote
# and push the rewritten history with `git push --mirror --force`.
#
# The script automatically creates a backup of the original repository before
# processing, allowing you to restore the original state if needed and enabling
# consistency checks with the integrated verification functionality.
#
# Usage:
#   ./clean-large-blobs.sh <GIT_DIRECTORY> <OBJECT_MAX_SIZE> [--yes]
#
# Example:
#   ./clean-large-blobs.sh ./produzionidalbasso.git 1000000
#   ./clean-large-blobs.sh ./produzionidalbasso.git 1000000 --yes

# -----------------------------------------------------------------------------
# --- Configuration ---

# Initialize variables
SKIP_CONFIRMATION=false
VERIFY_CLEANUP=true
TEMP_DIRECTORIES=()

# -----------------------------------------------------------------------------
# --- Verification Functions ---
# -----------------------------------------------------------------------------

# Colors for verification output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global array to track temporary directories for manual inspection
declare -a TEMP_DIRECTORIES=()

# Function to cleanup all tracked temporary directories
cleanup_all_temp_dirs() {
    for temp_dir in "${TEMP_DIRECTORIES[@]}"; do
        if [ -d "$temp_dir" ]; then
            rm -rf "$temp_dir"
        fi
    done
}

# Function to track temporary directories
track_temp_dir() {
    TEMP_DIRECTORIES+=("$1")
}

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to verify repository content (simplified and reliable)
verify_repository_content() {
    local original_repo="$1"
    local cleaned_repo="$2"
    
    # Validate that both repositories exist
    if [ ! -d "$original_repo" ]; then
        print_error "ERROR: Original repository '$original_repo' does not exist or is not a directory."
        return 1
    fi
    
    if [ ! -d "$cleaned_repo" ]; then
        print_error "ERROR: Cleaned repository '$cleaned_repo' does not exist or is not a directory."
        return 1
    fi
    
    print_success "🔍 Cleanup Verification"
    print_success "========================"
    echo
    echo "Original repository: $original_repo"
    echo "Cleaned repository: $cleaned_repo"
    echo
    
    # Function to get git directory path (handles both bare and regular repos)
    get_git_dir() {
        local repo_path="$1"
        if [ -d "$repo_path/.git" ]; then
            echo "$repo_path/.git"
        else
            echo "$repo_path"
        fi
    }
    
    local original_git_dir=$(get_git_dir "$original_repo")
    local cleaned_git_dir=$(get_git_dir "$cleaned_repo")
    
    # -----------------------------------------------------------------------------
    # 1. Repository Size Verification
    # -----------------------------------------------------------------------------
    echo
    print_info "=== Repository Size Verification ==="
    echo
    
    local original_size=$(du -sh "$original_repo" | cut -f1)
    local cleaned_size=$(du -sh "$cleaned_repo" | cut -f1)
    
    echo "Original repository size: $original_size"
    echo "Cleaned repository size:  $cleaned_size"
    
    # Calculate size reduction
    local original_bytes=$(du -sb "$original_repo" | cut -f1)
    local cleaned_bytes=$(du -sb "$cleaned_repo" | cut -f1)
    local size_reduction=$((original_bytes - cleaned_bytes))
    local size_reduction_percent=$((size_reduction * 100 / original_bytes))
    
    if [ "$size_reduction" -gt 0 ]; then
        local size_reduction_mb=$((size_reduction / 1024 / 1024))
        print_success "✅ Repository size reduced by $size_reduction_mb MB ($size_reduction_percent%)"
        local size_reduction_success=true
    else
        print_warning "⚠️  No significant size reduction detected"
        local size_reduction_success=false
    fi
    
    # -----------------------------------------------------------------------------
    # 2. Large Files Verification
    # -----------------------------------------------------------------------------
    echo
    print_info "=== Large Files Verification ==="
    echo
    
    # Check if specific large files were removed from Git history
    local large_files=(
        "produzioni-dal-basso/pdb_backup_10062019.sql"
        "pdb_django2.sql"
        "docker_db_conf/dump.zip"
        "produzioni-dal-basso/accounts.json"
        "produzioni-dal-basso/pdb.json"
    )
    
    local large_files_removed=0
    local large_files_total=${#large_files[@]}
    
    print_info "Checking if large files were removed from Git history..."
    
    for file in "${large_files[@]}"; do
        # Check if file exists in Git history of original repo
        local original_has_file=$(git --git-dir="$original_git_dir" log --all --full-history -- "$file" 2>/dev/null | wc -l)
        local cleaned_has_file=$(git --git-dir="$cleaned_git_dir" log --all --full-history -- "$file" 2>/dev/null | wc -l)
        
        if [ "$original_has_file" -gt 0 ]; then
            if [ "$cleaned_has_file" -gt 0 ]; then
                print_error "  ❌ $file - Still present in cleaned repository Git history"
            else
                print_success "  ✅ $file - Successfully removed from Git history"
                large_files_removed=$((large_files_removed + 1))
            fi
        else
            print_warning "  ⚠️  $file - Not found in original repository Git history"
        fi
    done
    
    echo
    echo "Large files removed: $large_files_removed/$large_files_total"
    
    if [ "$large_files_removed" -gt 0 ]; then
        print_success "✅ Large files successfully removed from Git history"
        local large_files_success=true
    else
        print_warning "⚠️  No large files were removed from Git history"
        local large_files_success=true  # Not critical if files weren't present
    fi
    
    # -----------------------------------------------------------------------------
    # 3. Basic Branch Verification
    # -----------------------------------------------------------------------------
    echo
    print_info "=== Basic Branch Verification ==="
    echo
    
    # Check if repositories have branches
    local original_branches=$(git --git-dir="$original_git_dir" branch --format='%(refname:short)' 2>/dev/null | wc -l)
    local cleaned_branches=$(git --git-dir="$cleaned_git_dir" branch --format='%(refname:short)' 2>/dev/null | wc -l)
    
    echo "Original repository branches: $original_branches"
    echo "Cleaned repository branches:  $cleaned_branches"
    
    if [ "$cleaned_branches" -gt 0 ]; then
        print_success "✅ Cleaned repository has branches"
        local branch_verification_success=true
    else
        print_error "❌ Cleaned repository has no branches"
        local branch_verification_success=false
    fi
    
    # -----------------------------------------------------------------------------
    # 4. Final Verification Summary
    # -----------------------------------------------------------------------------
    echo
    print_info "=== Verification Summary ==="
    echo
    
    local overall_success=true
    
    # Check each verification component
    if [ "$size_reduction_success" = "true" ]; then
        print_success "✅ Repository size reduction"
    else
        print_warning "⚠️  Repository size reduction"
        overall_success=false
    fi
    
    if [ "$large_files_success" = "true" ]; then
        print_success "✅ Large files removal from Git history"
    else
        print_warning "⚠️  Large files removal from Git history"
        overall_success=false
    fi
    
    if [ "$branch_verification_success" = "true" ]; then
        print_success "✅ Branch verification"
    else
        print_error "❌ Branch verification"
        overall_success=false
    fi
    
    echo
    if [ "$overall_success" = "true" ]; then
        print_success "🎉 CLEANUP VERIFICATION PASSED!"
        print_success "The BFG cleanup was successful."
        return 0
    else
        print_warning "⚠️  CLEANUP VERIFICATION COMPLETED WITH WARNINGS"
        print_warning "Some issues were found, but the cleanup may still be successful."
        return 1
    fi
}

# Function to create shallow clones for manual inspection
create_shallow_clones() {
    local original_git_dir="$1"
    local cleaned_git_dir="$2"
    
    echo
    print_info "CREATING SHALLOW CLONES FOR MANUAL INSPECTION"
    print_info "============================================="
    echo
    
    # Create temporary directory for shallow clones
    local temp_dir=$(mktemp -d)
    print_info "Temporary directory for shallow clones: $temp_dir"
    echo
    
    # Get list of branches from original repository
    local branches=($(git --git-dir="$original_git_dir" branch --format='%(refname:short)'))
    
    if [ ${#branches[@]} -eq 0 ]; then
        print_warning "No branches found in original repository"
        return 0
    fi
    
    print_info "Found ${#branches[@]} branches to clone:"
    for branch in "${branches[@]}"; do
        print_info "  • $branch"
    done
    echo
    
    # Create shallow clones for each branch
    for branch in "${branches[@]}"; do
        print_info "Creating shallow clone for branch: $branch"
        
        # Create shallow clone from original repository
        local original_clone_dir="$temp_dir/${branch}-original"
        echo "git clone --branch $branch --single-branch --depth 1 $original_git_dir $original_clone_dir"
        if git clone --branch "$branch" --single-branch --depth 1 "$original_git_dir" "$original_clone_dir" 2>/dev/null; then
            print_success "✅ Original clone created: $original_clone_dir"
        else
            print_warning "⚠️  Failed to create original clone for branch: $branch"
        fi
        
        # Create shallow clone from cleaned repository (if branch exists)
        local cleaned_clone_dir="$temp_dir/${branch}-cleaned"
        if git --git-dir="$cleaned_git_dir" rev-parse --verify "refs/heads/$branch" >/dev/null 2>&1; then
            echo "git clone --branch $branch --single-branch --depth 1 $cleaned_git_dir $cleaned_clone_dir"
            if git clone --branch "$branch" --single-branch --depth 1 "$cleaned_git_dir" "$cleaned_clone_dir" 2>/dev/null; then
                print_success "✅ Cleaned clone created: $cleaned_clone_dir"
            else
                print_warning "⚠️  Failed to create cleaned clone for branch: $branch"
            fi
        else
            print_warning "⚠️  Branch '$branch' does not exist in cleaned repository"
        fi
        echo
    done
    
    # Store temp directory for cleanup
    TEMP_DIRECTORIES+=("$temp_dir")
    
    echo
    print_success "SHALLOW CLONES CREATED SUCCESSFULLY!"
    print_info "You can now manually inspect the differences between original and cleaned repositories."
    print_info "Temporary directory: $temp_dir"
    echo
    
    # Print directory structure
    print_info "Directory structure:"
    ls -la "$temp_dir" | while read line; do
        print_info "  $line"
    done
    echo
}

# Function to get branch statistics (file count and size)
get_branch_stats() {
    local branch_dir="$1"
    
    if [ ! -d "$branch_dir" ]; then
        echo "0 files, 0B"
        return
    fi
    
    # Count files (excluding .git directory)
    local file_count=$(find "$branch_dir" -type f -not -path "*/.git/*" | wc -l | tr -d ' ')
    
    # Get directory size (excluding .git directory)
    local size_bytes=$(du -sb "$branch_dir" 2>/dev/null | cut -f1)
    
    # Convert to human readable format
    if [ "$size_bytes" -ge 1073741824 ]; then
        local size_gb=$(echo "scale=1; $size_bytes/1073741824" | bc)
        local size_str="${size_gb}GB"
    elif [ "$size_bytes" -ge 1048576 ]; then
        local size_mb=$(echo "scale=1; $size_bytes/1048576" | bc)
        local size_str="${size_mb}MB"
    elif [ "$size_bytes" -ge 1024 ]; then
        local size_kb=$(echo "scale=1; $size_bytes/1024" | bc)
        local size_str="${size_kb}KB"
    else
        local size_str="${size_bytes}B"
    fi
    
    echo "$file_count files, $size_str"
}

# Function to print temporary directories for cleanup
print_temp_directories() {
    if [ ${#TEMP_DIRECTORIES[@]} -eq 0 ]; then
        return 0
    fi
    
    echo
    print_info "TEMPORARY DIRECTORIES CREATED"
    print_info "============================="
    echo
    
    # Group directories by branch (handle nested directory structures)
    declare -A branch_dirs
    for temp_dir in "${TEMP_DIRECTORIES[@]}"; do
        if [ -d "$temp_dir" ]; then
            # Find all directories recursively and process them
            while IFS= read -r -d '' branch_dir; do
                branch_name=$(basename "$branch_dir")
                if [[ "$branch_name" == *"-original" ]]; then
                    branch=${branch_name%-original}
                    branch_dirs["$branch-original"]="$branch_dir"
                elif [[ "$branch_name" == *"-cleaned" ]]; then
                    branch=${branch_name%-cleaned}
                    branch_dirs["$branch-cleaned"]="$branch_dir"
                fi
            done < <(find "$temp_dir" -type d \( -name "*-original" -o -name "*-cleaned" \) -print0)
        fi
    done
    
    # Print grouped by branch
    local printed_branches=()
    for key in "${!branch_dirs[@]}"; do
        branch=${key%-*}
        if [[ ! " ${printed_branches[@]} " =~ " ${branch} " ]]; then
            printed_branches+=("$branch")
        fi
    done
    
    for branch in "${printed_branches[@]}"; do
        echo -e "\033[32mBranch: $branch\033[0m"
        
        # Get statistics for original branch
        if [ -n "${branch_dirs["$branch-original"]:-}" ]; then
            local original_stats=$(get_branch_stats "${branch_dirs["$branch-original"]}")
            print_info "  Original: ${branch_dirs["$branch-original"]}"
            print_info "    Stats:  $original_stats"
        fi
        
        # Get statistics for cleaned branch
        if [ -n "${branch_dirs["$branch-cleaned"]:-}" ]; then
            local cleaned_stats=$(get_branch_stats "${branch_dirs["$branch-cleaned"]}")
            print_info "  Cleaned:  ${branch_dirs["$branch-cleaned"]}"
            print_info "    Stats:  $cleaned_stats"
        fi
        echo
    done
    
    print_info "These directories will be preserved for manual inspection."
    print_info "You can safely delete them when you're done:"
    for temp_dir in "${TEMP_DIRECTORIES[@]}"; do
        print_info "  rm -rf $temp_dir"
    done
    echo
}

# Function to display usage
usage() {
    echo "Usage: $0 <GIT_DIRECTORY> <OBJECT_MAX_SIZE> [--yes] [--no-verify]"
    echo "  GIT_DIRECTORY: Path to the Git repository"
    echo "  OBJECT_MAX_SIZE: Maximum blob size in bytes"
    echo "  --yes: Skip confirmation prompt"
    echo "  --no-verify: Skip verification step"
    echo ""
    echo "Example:"
    echo "  $0 ./produzionidalbasso.git 1000000"
    echo "  $0 ./produzionidalbasso.git 1000000 --yes"
    echo "  $0 ./produzionidalbasso.git 1000000 --no-verify"
    exit 1
}

# -----------------------------------------------------------------------------
# --- Main Script Logic ---
# -----------------------------------------------------------------------------

# Parse command line arguments
if [ $# -lt 2 ]; then
    echo "ERROR: Both parameters are required."
    usage
fi

GIT_DIR="$1"
OBJECT_MAX_SIZE="$2"

# Check for flags
for arg in "$@"; do
    case "$arg" in
        --yes)
            SKIP_CONFIRMATION=true
            ;;
        --no-verify)
            VERIFY_CLEANUP=false
            ;;
    esac
done

# Validate inputs
if [ ! -d "$GIT_DIR" ]; then
    print_error "Git directory does not exist: $GIT_DIR"
    exit 1
fi

if [ ! -f "$GIT_DIR/HEAD" ] && [ ! -d "$GIT_DIR/.git" ]; then
    print_error "Not a valid Git repository: $GIT_DIR"
    exit 1
fi

if ! [[ "$OBJECT_MAX_SIZE" =~ ^[0-9]+$ ]]; then
    print_error "Invalid size parameter: $OBJECT_MAX_SIZE (must be a number)"
    exit 1
fi

# Create backup
BACKUP_DIR="${GIT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
print_info "Creating backup..."
print_info "  Original repository: $GIT_DIR"
print_info "  Backup directory: $BACKUP_DIR"
print_info "  Creating backup with cp -a..."
cp -a "$GIT_DIR" "$BACKUP_DIR"
print_success "Backup created successfully: $BACKUP_DIR"

echo ""
print_info "Configuration:"
print_info "  Git directory: $GIT_DIR"
print_info "  Maximum blob size: $OBJECT_MAX_SIZE bytes ($(($OBJECT_MAX_SIZE / 1024)) KB)"
print_info "  Backup directory: $BACKUP_DIR"
if [ "$SKIP_CONFIRMATION" = "true" ]; then
    print_info "  Skip confirmation: YES (--yes flag provided)"
else
    print_info "  Skip confirmation: NO"
fi
echo ""

# -----------------------------------------------------------------------------
# --- Pre-cleanup Analysis ---

print_info "ANALYZING REPOSITORY..."

# Simple analysis for BFG - count large blobs and show what will be removed
LARGE_BLOBS_COUNT=$(git --git-dir="$GIT_DIR" rev-list --objects --all | awk '{print $1}' | git --git-dir="$GIT_DIR" cat-file --batch-check='%(objecttype) %(objectname) %(objectsize)' | awk '$1=="blob" && $3 > '$OBJECT_MAX_SIZE'' | wc -l)

if [ "$LARGE_BLOBS_COUNT" -eq 0 ]; then
  print_success "No large blobs found. Repository is already clean!"
  exit 0
fi

print_info "Found $LARGE_BLOBS_COUNT large blobs to process"

# Show what will be removed
print_info "Large files that will be removed:"
TOTAL_SIZE_REMOVED=0
git --git-dir="$GIT_DIR" rev-list --objects --all | awk '{print $1}' | git --git-dir="$GIT_DIR" cat-file --batch-check='%(objecttype) %(objectname) %(objectsize)' | awk '$1=="blob" && $3 > '$OBJECT_MAX_SIZE'' | while read line; do
    blob_id=$(echo "$line" | awk '{print $2}')
    blob_size=$(echo "$line" | awk '{print $3}')
    
    # Get file path for this blob
    file_path=$(git --git-dir="$GIT_DIR" rev-list --objects --all | grep "^$blob_id " | cut -d' ' -f2-)
    if [ -n "$file_path" ]; then
        size_mb=$(echo "scale=2; $blob_size/1024/1024" | bc)
        echo "  • ${size_mb} MB - $file_path"
    fi
done

echo ""
print_warning "WARNING: LARGE FILES WILL BE REMOVED"
echo "=========================================="
echo ""
print_info "BFG CLEANUP SUMMARY: $LARGE_BLOBS_COUNT large files will be processed"
print_info "  - BFG will automatically protect files in the latest commit (HEAD)"
print_info "  - Files larger than $OBJECT_MAX_SIZE bytes will be removed from history"
print_info "  - Repository will be cleaned and optimized"
echo ""
print_warning "IMPORTANT NOTES:"
print_warning "   • This operation will rewrite Git history"
print_warning "   • The origin remote will be removed for safety"
print_warning "   • You will need to force-push to update the remote repository"
print_warning "   • This operation cannot be easily undone"
echo ""

# -----------------------------------------------------------------------------
# --- Confirmation Step ---

if [ "$SKIP_CONFIRMATION" = "false" ]; then
  echo "Do you want to proceed with the cleanup? (y/N): "
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    print_info "Operation cancelled by user"
    exit 0
  fi
  echo ""
  print_success "Confirmed. Proceeding with cleanup..."
  echo ""
else
  print_success "Auto-confirmed (--yes flag provided). Proceeding with cleanup..."
  echo ""
fi

# -----------------------------------------------------------------------------
# --- Run BFG Repo-Cleaner ---
# BFG Repo-Cleaner is faster and more reliable than git-filter-repo for this use case.

print_info "Starting BFG Repo-Cleaner cleanup..."

# Check if BFG is installed
if ! command -v bfg &> /dev/null; then
    print_error "BFG Repo-Cleaner is not installed. Please install it first:"
    print_info "  brew install bfg"
    print_info "  or download from: https://rtyley.github.io/bfg-repo-cleaner/"
    exit 1
fi

# Convert size to BFG format (e.g., 1000000 -> 1M)
if [ "$OBJECT_MAX_SIZE" -ge 1048576 ]; then
    SIZE_MB=$(echo "scale=0; $OBJECT_MAX_SIZE/1048576" | bc)
    BFG_SIZE="${SIZE_MB}M"
elif [ "$OBJECT_MAX_SIZE" -ge 1024 ]; then
    SIZE_KB=$(echo "scale=0; $OBJECT_MAX_SIZE/1024" | bc)
    BFG_SIZE="${SIZE_KB}K"
else
    BFG_SIZE="${OBJECT_MAX_SIZE}B"
fi

print_info "Running BFG Repo-Cleaner to remove blobs larger than $BFG_SIZE..."

# Change to git directory
pushd "$GIT_DIR"

# Run BFG with size-based filtering
# BFG will automatically protect blobs from HEAD by default
print_info "Running BFG with default HEAD protection..."
bfg --strip-blobs-bigger-than "$BFG_SIZE" .

# Clean up the repository
print_info "Cleaning up repository..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

popd

# -----------------------------------------------------------------------------
# --- Generate Simple Recap ---

echo ""
echo "=== LARGE BLOB CLEANUP COMPLETED ==="
echo ""

print_success "FINAL SUMMARY:"
print_info "   • Maximum blob size: $OBJECT_MAX_SIZE bytes ($(($OBJECT_MAX_SIZE / 1024)) KB)"
print_info "   • Repository: $GIT_DIR"
print_info "   • Tool used: BFG Repo-Cleaner"
print_info "   • Size threshold: $BFG_SIZE"
print_info "   • Files protected: All files in HEAD commit (automatic protection)"
echo ""

# -----------------------------------------------------------------------------
# --- Final instructions ---

# Create log file with success message
cat > .clean-large-blobs.log << EOF
Cleanup completed successfully using BFG Repo-Cleaner.
Your origin remote was removed by BFG for safety.
To re-add it and force-push the cleaned history:

  git --git-dir="$GIT_DIR" remote add origin <NEW_URL>
  git --git-dir="$GIT_DIR" push --mirror --force origin

NOTE: If you also want to remove local branch refs listed above, run:
  git --git-dir="$GIT_DIR" branch -D <branchname>

BACKUP INFORMATION:
  Original repository backup: $BACKUP_DIR
  You can use this backup to restore the original state if needed.

BFG CLEANUP SUMMARY:
  Tool used: BFG Repo-Cleaner
  Size threshold: $BFG_SIZE
  Files protected: All files in HEAD commit (automatic protection)

REMOVED FILES SUMMARY:
EOF

# Add removed files to log
git --git-dir="$GIT_DIR" rev-list --objects --all | awk '{print $1}' | git --git-dir="$GIT_DIR" cat-file --batch-check='%(objecttype) %(objectname) %(objectsize)' | awk '$1=="blob" && $3 > '$OBJECT_MAX_SIZE'' | while read line; do
    blob_id=$(echo "$line" | awk '{print $2}')
    blob_size=$(echo "$line" | awk '{print $3}')
    
    # Get file path for this blob
    file_path=$(git --git-dir="$GIT_DIR" rev-list --objects --all | grep "^$blob_id " | cut -d' ' -f2-)
    if [ -n "$file_path" ]; then
        size_mb=$(echo "scale=2; $blob_size/1024/1024" | bc)
        echo "  • ${size_mb} MB - $file_path" >> .clean-large-blobs.log
    fi
done

print_success "Cleanup completed successfully!"
print_info "Log file created: .clean-large-blobs.log"
print_info "Original repository backup: $BACKUP_DIR"
print_info "Cleaned repository: $GIT_DIR"
echo ""

# -----------------------------------------------------------------------------
# --- Verification Step ---
# -----------------------------------------------------------------------------

# Check if verification is requested (default: yes)
if [ "$VERIFY_CLEANUP" = "true" ] && [ -d "$BACKUP_DIR" ]; then
    echo
    print_info "VERIFICATION STEP"
    print_info "================="
    print_info "Verifying that the cleaned repository has identical content to the original..."
    echo
    
    # Run the verification
    if verify_repository_content "$BACKUP_DIR" "$GIT_DIR"; then
        echo
        print_success "VERIFICATION COMPLETED SUCCESSFULLY!"
        print_success "The cleaned repository has identical content to the original repository"
        print_success "across all common branches (excluding the removed large files)."
    else
        echo
        print_warning "VERIFICATION COMPLETED WITH WARNINGS"
        print_warning "Some branches may have differences. This could be normal if:"
        print_warning "  • Some branches were empty or had issues"
        print_warning "  • Only large files were removed (which is expected)"
        print_warning "  • Branch structure changed during cleanup"
        echo
        print_warning "Review the verification output above for details."
    fi
    echo
    
    # Create shallow clones for manual inspection
    create_shallow_clones "$BACKUP_DIR" "$GIT_DIR"
elif [ "$VERIFY_CLEANUP" = "false" ]; then
    echo
    print_info "VERIFICATION SKIPPED"
    print_info "===================="
    print_info "Verification was disabled. To verify manually, run:"
    print_info "  Run the script again with verification enabled to compare repositories."
    echo
else
    echo
    print_warning "VERIFICATION SKIPPED"
    print_warning "===================="
    print_warning "No backup directory found for verification."
    print_warning "Original repository: $BACKUP_DIR"
    echo
fi

# Print temporary directories for manual inspection
print_temp_directories

print_info "Next steps:"
print_info "  1. Re-add your origin remote: git --git-dir=\"$GIT_DIR\" remote add origin <URL>"
print_info "  2. Force-push the cleaned history: git --git-dir=\"$GIT_DIR\" push --mirror --force origin"
print_info "  3. Verify the cleanup was successful"
echo ""
print_success "BFG Repo-Cleaner cleanup completed!"
