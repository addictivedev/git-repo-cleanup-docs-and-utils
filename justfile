# Justfile for Git Repository Cleaning Scripts E2E Testing

# Default recipe - run all tests
default:
    @just --list

# Run all tests
test-all:
    @just check-prerequisites
    @just make-executable
    @just test-secrets
    @just test-blobs
    @echo "✅ All tests completed successfully"

# Run only Python tests
test-python:
    @just check-prerequisites
    @echo "🐍 Running Python tests..."
    @python3 tests/test_blob_callback.py
    @echo "✅ Python tests passed"

# Run only clean-secrets.sh tests
test-secrets:
    @just check-prerequisites
    @just make-executable
    @echo "🧪 Running clean-secrets.sh tests..."
    @bats tests/bats/test_clean_secrets.bats
    @echo "✅ clean-secrets.sh tests passed"

# Run only clean-large-blobs.sh tests  
test-blobs:
    @just check-prerequisites
    @just make-executable
    @echo "🧪 Running clean-large-blobs.sh tests..."
    @bats tests/bats/test_clean_large_blobs.bats
    @echo "✅ clean-large-blobs.sh tests passed"

# Run tests with verbose output
test-verbose:
    @just check-prerequisites
    @just make-executable
    @echo "🧪 Running all tests with verbose output..."
    @bats -v tests/bats/test_clean_secrets.bats
    @bats -v tests/bats/test_clean_large_blobs.bats
    @echo "✅ All tests completed successfully"

# Run only clean-secrets.sh tests with verbose output
test-secrets-verbose:
    @just check-prerequisites
    @just make-executable
    @echo "🧪 Running clean-secrets.sh tests with verbose output..."
    @bats -v tests/bats/test_clean_secrets.bats
    @echo "✅ clean-secrets.sh tests passed"

# Run only clean-large-blobs.sh tests with verbose output
test-blobs-verbose:
    @just check-prerequisites
    @just make-executable
    @echo "🧪 Running clean-large-blobs.sh tests with verbose output..."
    @bats -v tests/bats/test_clean_large_blobs.bats
    @echo "✅ clean-large-blobs.sh tests passed"

# Run a specific BATS file
test-file bats-file flags="":
    @just check-prerequisites
    @just make-executable
    @echo "🧪 Running BATS file: {{bats-file}}..."
    @bats {{flags}} "{{bats-file}}"
    @echo "✅ BATS file '{{bats-file}}' completed"

# Run a single test by name from a specific BATS file (or all tests if no name provided)
test-file-single bats-file test-name="" flags="":
    @just check-prerequisites
    @just make-executable
    if [ -n "{{test-name}}" ]; then \
        echo "🧪 Running single test '{{test-name}}' from file: {{bats-file}}..."; \
        bats {{flags}} -f "{{test-name}}" "{{bats-file}}"; \
        echo "✅ Test '{{test-name}}' from '{{bats-file}}' completed"; \
    else \
        echo "🧪 Running all tests from file: {{bats-file}}..."; \
        bats {{flags}} "{{bats-file}}"; \
        echo "✅ All tests from '{{bats-file}}' completed"; \
    fi

# Check prerequisites
check-prerequisites:
    @echo "🔍 Checking prerequisites..."
    @command -v git > /dev/null || (echo "❌ git is required" && exit 1)
    @command -v python3 > /dev/null || (echo "❌ python3 is required" && exit 1)
    @command -v jq > /dev/null || (echo "❌ jq is required" && exit 1)
    @command -v bats > /dev/null || (echo "❌ bats-core is required" && exit 1)
    @command -v bfg > /dev/null || (echo "❌ BFG Repo-Cleaner is required" && exit 1)
    @command -v git-filter-repo > /dev/null || (echo "❌ git-filter-repo is required" && exit 1)
    @echo "✅ All prerequisites satisfied"

# List all available test cases with descriptions
list-tests:
    @echo "📋 Available test cases:"
    @echo ""
    @echo "**clean-secrets.sh tests:**"
    @grep -h '^@test' tests/bats/test_clean_secrets.bats | sed 's/@test "\(.*\)" {/- `\1`/'
    @echo ""
    @echo "**clean-large-blobs.sh tests:**"
    @grep -h '^@test' tests/bats/test_clean_large_blobs.bats | sed 's/@test "\(.*\)" {/- `\1`/'
    @echo ""

# Make scripts executable
make-executable:
    @echo "🔧 Making scripts executable..."
    @chmod +x clean-secrets.sh clean-large-blobs.sh
    @chmod +x tests/bats/helpers/*.bash
    @chmod +x tests/bats/*.bats

# Show help
help:
    @echo "E2E Test Runner for Git Repository Cleaning Scripts"
    @echo ""
    @echo "Usage: just [RECIPE]"
    @echo ""
    @echo "Recipes:"
    @echo "    test-all                Run all tests (default)"
    @echo "    test-secrets           Run only clean-secrets.sh tests"
    @echo "    test-blobs             Run only clean-large-blobs.sh tests"
    @echo "    test-verbose           Run all tests with verbose output"
    @echo "    test-secrets-verbose   Run clean-secrets.sh tests with verbose output"
    @echo "    test-blobs-verbose     Run clean-large-blobs.sh tests with verbose output"
    @echo "    test-file <file> [flags]      Run a specific BATS file"
    @echo "    test-file-single <file> [name] [flags]  Run a single test from a specific BATS file (or all tests if no name)"
    @echo "    list-tests             List all available test cases with descriptions"
    @echo "    check-prerequisites    Check if all required dependencies are installed"
    @echo "    make-executable        Make all scripts executable"
    @echo "    help                   Show this help message"
    @echo ""
    @echo "Prerequisites:"
    @echo "    - git"
    @echo "    - python3"
    @echo "    - jq"
    @echo "    - BFG Repo-Cleaner"
    @echo "    - git-filter-repo"
    @echo "    - bats-core"
    @echo ""
    @echo "Installation:"
    @echo "    # macOS"
    @echo "    brew install git jq bats-core bfg gitleaks"
    @echo "    pip3 install git-filter-repo"
    @echo ""
    @echo "    # Ubuntu/Debian"
    @echo "    sudo apt-get install -y git python3 python3-pip jq bats"
    @echo "    # Install BFG from: https://rtyley.github.io/bfg-repo-cleaner/"
    @echo "    curl -s https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | bash"
    @echo "    pip3 install git-filter-repo"
    @echo "Examples:"
    @echo "    # Run all tests"
    @echo "    just test-all"
    @echo ""
    @echo "    # List all available test cases"
    @echo "    just list-tests"
    @echo ""
    @echo "    # Run a specific BATS file"
    @echo "    just test-file tests/bats/test_clean_secrets.bats"
    @echo ""
    @echo "    # Run a specific BATS file with verbose output"
    @echo "    just test-file tests/bats/test_clean_secrets.bats \"-v\""
    @echo ""
    @echo "    # Run a specific BATS file with trace output"
    @echo "    just test-file tests/bats/test_clean_secrets.bats \"-t\""
    @echo ""
    @echo "    # Run a specific BATS file with both verbose and trace"
    @echo "    just test-file tests/bats/test_clean_secrets.bats \"-v -t\""
    @echo ""
    @echo "    # Run all tests from a specific file"
    @echo "    just test-file-single tests/bats/test_clean_secrets.bats"
    @echo ""
    @echo "    # Run a single test from a specific file"
    @echo "    just test-file-single tests/bats/test_clean_secrets.bats \"clean-secrets.sh: successfully removes secrets from git history\""
    @echo ""
    @echo "    # Run a single test with verbose output"
    @echo "    just test-file-single tests/bats/test_clean_secrets.bats \"clean-secrets.sh: successfully removes secrets from git history\" \"-v\""
    @echo ""
    @echo "    # Run a single test with trace output"
    @echo "    just test-file-single tests/bats/test_clean_secrets.bats \"clean-secrets.sh: successfully removes secrets from git history\" \"-t\""
    @echo ""
    @echo "    # Run a single test with both verbose and trace"
    @echo "    just test-file-single tests/bats/test_clean_secrets.bats \"clean-secrets.sh: successfully removes secrets from git history\" \"-v -t\""
