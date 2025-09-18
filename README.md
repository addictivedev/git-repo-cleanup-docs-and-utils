# Git Repository Migration and Security Tools

This project provides tools for migrating and securing Git repositories by removing large files and sensitive data from repository history.

## Tools

- **`clean-large-blobs.sh`** - Removes large files from Git history using BFG Repo-Cleaner
- **`clean-secrets.sh`** - Removes sensitive data from Git history using git-filter-repo with gitleaks analysis

## Quick Start

```bash
# Install prerequisites
brew install git jq bats-core bfg gitleaks
pip3 install git-filter-repo

# Run tests to verify everything works
just test-all

# Clean large files from a repository (files > 1MB)
./clean-large-blobs.sh /path/to/repo.git 1000000

# Clean large files with branch protection
./clean-large-blobs.sh /path/to/repo.git 1000000 --protect-blobs-from "main,develop"

# Clean secrets from a repository  
./clean-secrets.sh /path/to/repo.git /path/to/gitleaks-scan.json
```

## Prerequisites

### macOS
```bash
brew install git jq bats-core bfg gitleaks
pip3 install git-filter-repo
```

### Ubuntu/Debian
```bash
sudo apt-get install -y git python3 python3-pip jq bats
# Install BFG from: https://rtyley.github.io/bfg-repo-cleaner/
curl -s https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | bash
pip3 install git-filter-repo
```

### Verify Installation
```bash
git --version
bfg --version
gitleaks version
git-filter-repo --version
bats --version
```

## Tool Architecture

This project uses **two specialized tools** for different cleanup tasks:

### BFG Repo-Cleaner (`clean-large-blobs.sh`)
- **Purpose**: Remove large files from Git history
- **Why BFG**: Excellent performance for size-based filtering, simple configuration
- **Features**: Size thresholds, automatic HEAD protection, branch-specific protection

### git-filter-repo (`clean-secrets.sh`)  
- **Purpose**: Remove sensitive data using sophisticated content analysis
- **Why git-filter-repo**: Advanced callback system for complex content modifications
- **Features**: gitleaks integration, line-by-line secret removal, commit message redaction

### Why Two Tools?

Each tool excels at its specific use case:
- **BFG** is optimized for simple, fast blob removal based on size
- **git-filter-repo** provides the callback flexibility needed for complex secret analysis and removal

This dual approach gives us the best of both worlds: **performance** for large file cleanup and **precision** for secret removal.

## Usage

### Clean Large Files

Remove files larger than a specified size from Git history while preserving files in specified branches:

```bash
./clean-large-blobs.sh <git-directory> <max-size-bytes> [--yes] [--no-verify] [--protect-blobs-from <refs>]
```

**Parameters:**
- `git-directory`: Path to the Git repository
- `max-size-bytes`: Maximum file size in bytes (e.g., 1000000 for 1MB)
- `--yes`: Skip confirmation prompt
- `--no-verify`: Skip verification step
- `--protect-blobs-from <refs>`: Protect blobs from specified refs (default: HEAD)
  - `<refs>` can be a comma-separated list of refs (e.g., HEAD,main,develop)

**Examples:**

Basic usage (protects HEAD by default):
```bash
./clean-large-blobs.sh ./my-repo.git 1000000
```

Protect specific branches:
```bash
./clean-large-blobs.sh ./my-repo.git 1000000 --protect-blobs-from "main,develop"
```

Skip confirmation and verification:
```bash
./clean-large-blobs.sh ./my-repo.git 1000000 --yes --no-verify
```

**Multi-branch Protection Example:**
```bash
# Protect main and feature branches while removing large files from other branches
./clean-large-blobs.sh ./my-repo.git 50000000 --protect-blobs-from "main,feature/important,release/v1.0"
```

### Clean Secrets

Remove sensitive data from Git history using gitleaks analysis and git-filter-repo:

```bash
./clean-secrets.sh <git-directory> <gitleaks-json-file> [--cleanup]
```

**Parameters:**
- `git-directory`: Path to the `.git` directory  
- `gitleaks-json-file`: JSON file containing gitleaks scan results
- `--cleanup`: Perform final cleanup (reflog expire, git gc, delete temp files)

**Example:**
```bash
# First, scan for secrets
gitleaks git -v --log-level info --log-format json > secrets-scan.json

# Then clean the repository
./clean-secrets.sh ./my-repo.git ./secrets-scan.json --cleanup
```

## Testing

This project includes comprehensive tests using the Bats testing framework:

```bash
# Run all tests
just test-all

# Run specific test suites
just test-blobs      # Test clean-large-blobs.sh
just test-secrets     # Test clean-secrets.sh

# Run with verbose output
just test-verbose

# List all available tests
just list-tests
```

## Safety Guidelines

**⚠️ CRITICAL**: Never run these tools against the repository containing the script code itself. Always work on copies or clones of your target repositories.

### Safe Usage
```bash
# ✅ SAFE - Work on a copy
cp -r original-repo.git backup-repo.git
./clean-large-blobs.sh backup-repo.git 1000000

# ✅ SAFE - Use existing test repositories
cd produzionidalbasso.git
./clean-large-blobs.sh . 1000000

# ✅ SAFE - Protect important branches
./clean-large-blobs.sh backup-repo.git 1000000 --protect-blobs-from "main,develop"
```

## Project Structure

- **`clean-large-blobs.sh`** - Main script for removing large files
- **`clean-secrets.sh`** - Main script for removing secrets
- **`tests/bats/`** - BATS test files
- **`tests/fixtures/`** - Test data and fixtures
- **`justfile`** - Task runner for testing and development

## Contributing

1. Make changes to the scripts
2. Run tests: `just test-all`
3. Ensure all tests pass
4. Commit your changes

## License

See LICENSE file for details.
