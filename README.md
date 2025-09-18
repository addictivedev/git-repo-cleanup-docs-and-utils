# Git Repository Migration and Security Tools

This project provides tools for migrating and securing Git repositories by removing large files and sensitive data from repository history.

## Tools

- **`clean-large-blobs.sh`** - Removes large files from Git history using BFG Repo-Cleaner
- **`clean-secrets.sh`** - Removes sensitive data from Git history using git-filter-repo with gitleaks analysis

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

## Quick Start

```bash
# Install prerequisites
brew install git jq bats-core bfg gitleaks
pip3 install git-filter-repo

# Clean large files from a repository (files > 1MB)
./clean-large-blobs.sh /path/to/repo.git 1000000

# Clean large files with branch protection
./clean-large-blobs.sh /path/to/repo.git 1000000 --protect-blobs-from "main,develop"

# Create gitleaks scan for secrets (run from within the repo)
cd /path/to/repo.git && gitleaks git -v --log-level trace --report-format json > ../repo-secrets-scan.json

# Clean secrets from a repository  
./clean-secrets.sh /path/to/repo.git /path/to/gitleaks-scan.json
```

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

## Creating Scans

Before cleaning secrets from your repository, you need to create a gitleaks scan to identify sensitive data. Here's how to create comprehensive scans:

### Basic Secret Scan

```bash
# Navigate to your repository
cd /path/to/your/repository

# Create a basic scan (outputs to console)
gitleaks git -v

# Save scan results to file
gitleaks git -v --log-level info --log-format json > secrets-scan.json
```

### Advanced Scan Options

```bash
# Scan with custom configuration
gitleaks git -v --config .gitleaks.toml --log-level info --log-format json > secrets-scan.json

# Scan specific branches only
gitleaks git -v --branch main --log-level info --log-format json > secrets-scan.json

# Scan with baseline (compare against previous scan)
gitleaks git -v --baseline-path previous-scan.json --log-level info --log-format json > secrets-scan.json

# Scan excluding certain paths
gitleaks git -v --exclude-path "*.log,*.tmp" --log-level info --log-format json > secrets-scan.json
```

### Scan Analysis

After creating a scan, analyze the results:

```bash
# View scan results in human-readable format
gitleaks git -v

# Count total secrets found
jq '. | length' secrets-scan.json

# List unique secret types
jq -r '.[].rule' secrets-scan.json | sort | uniq -c

# Show secrets by file
jq -r '.[] | "\(.file):\(.line): \(.rule)"' secrets-scan.json | sort
```

### Scan Validation

Before proceeding with cleanup, validate your scan:

```bash
# Check if scan file is valid JSON
jq empty secrets-scan.json && echo "Scan file is valid JSON"

# Verify scan contains expected data
jq '.[0] | keys' secrets-scan.json

# Count secrets by severity/type
jq 'group_by(.rule) | map({rule: .[0].rule, count: length}) | sort_by(.count) | reverse' secrets-scan.json
```

### Complete Scan Workflow

```bash
# 1. Create initial scan
gitleaks git -v --log-level info --log-format json > initial-scan.json

# 2. Analyze results
echo "Total secrets found: $(jq '. | length' initial-scan.json)"
echo "Secret types: $(jq -r '.[].rule' initial-scan.json | sort | uniq | wc -l)"

# 3. Review specific findings
jq -r '.[] | "\(.file):\(.line): \(.rule) - \(.match)"' initial-scan.json | head -20

# 4. Proceed with cleanup
./clean-secrets.sh ./my-repo.git ./initial-scan.json --cleanup

# 5. Create post-cleanup verification scan
gitleaks git -v --log-level info --log-format json > post-cleanup-scan.json

# 6. Compare results
echo "Secrets before cleanup: $(jq '. | length' initial-scan.json)"
echo "Secrets after cleanup: $(jq '. | length' post-cleanup-scan.json)"
```

### Scan Configuration

For custom scan rules, create a `.gitleaks.toml` file:

```toml
# Example .gitleaks.toml
title = "Custom Secret Detection"

[[rules]]
description = "Custom API Key Pattern"
regex = '''api[_-]?key[_-]?[=:]\s*['"]?[a-zA-Z0-9]{32,}['"]?'''
tags = ["api", "key"]

[[rules]]
description = "Database Connection String"
regex = '''(?:mysql|postgresql|mongodb)://[^\s]+'''
tags = ["database", "connection"]
```

Then run the scan with your custom config:

```bash
gitleaks git -v --config .gitleaks.toml --log-level info --log-format json > custom-scan.json
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

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for development and testing information.

## Safety Guidelines

**⚠️ CRITICAL**: Never run these tools against the repository containing the script code itself. Always work on copies or clones of your target repositories.

### Safe Usage
```bash
# ✅ SAFE - Work on a copy
cp -r original-repo.git backup-repo.git
./clean-large-blobs.sh backup-repo.git 1000000

# ✅ SAFE - Protect important branches
./clean-large-blobs.sh original-repo.git 1000000 --protect-blobs-from "main,develop"
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
