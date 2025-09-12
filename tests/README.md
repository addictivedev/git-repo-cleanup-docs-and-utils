# E2E Testing Documentation

This directory contains comprehensive end-to-end (e2e) tests for the git repository cleaning scripts using the [Bats](https://github.com/bats-core/bats-core) testing framework.

## Overview

The test suite validates both main scripts:
- **`clean-secrets.sh`** - Removes sensitive data from git history using gitleaks analysis
- **`clean-large-blobs.sh`** - Removes large files from git history while preserving important files

## Test Structure

```
tests/
├── bats/
│   ├── test_clean_secrets.bats      # E2E tests for clean-secrets.sh
│   ├── test_clean_large_blobs.bats  # E2E tests for clean-large-blobs.sh
│   └── helpers/
│       ├── setup.bash               # Test setup and teardown functions
│       └── assertions.bash          # Custom assertion functions
└── README.md                        # This documentation
```

## Prerequisites

### Required Tools

- **git** - Version control system
- **python3** - For git-filter-repo callbacks
- **jq** - JSON processing
- **git-filter-repo** - Git history rewriting tool
- **bats-core** - Testing framework

### Installation

#### macOS
```bash
# Install dependencies
brew install git jq bats-core
pip3 install git-filter-repo
```

#### Ubuntu/Debian
```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y git python3 python3-pip jq bats
pip3 install git-filter-repo
```

#### Verify Installation
```bash
git --version
python3 --version
jq --version
bats --version
git-filter-repo --version
```

## Test Cases

### clean-secrets.sh Tests

| Test Case | Description |
|-----------|-------------|
| `successfully removes secrets from git history` | Validates basic secret removal functionality |
| `handles multiple secrets in same file` | Tests removal of multiple secrets from single file |
| `preserves non-secret content in files with secrets` | Ensures non-secret content is preserved |
| `generates progress and statistics correctly` | Validates progress tracking and logging |
| `fails gracefully with invalid repository path` | Tests error handling for invalid inputs |
| `fails gracefully with invalid gitleaks file` | Tests error handling for malformed JSON |
| `handles empty gitleaks file` | Tests behavior with no secrets to remove |
| `performs cleanup when --cleanup flag is provided` | Validates cleanup functionality |
| `shows help message with --help flag` | Tests help message display |
| `handles missing arguments gracefully` | Tests argument validation |

### clean-large-blobs.sh Tests

| Test Case | Description |
|-----------|-------------|
| `successfully removes large blobs from git history` | Validates basic blob removal functionality |
| `preserves blobs listed in keep file` | Tests preservation of important files |
| `generates blob list automatically if missing` | Tests automatic blob list generation |
| `handles different size thresholds correctly` | Tests various size threshold scenarios |
| `fails gracefully with invalid repository path` | Tests error handling for invalid inputs |
| `fails gracefully with invalid size parameter` | Tests parameter validation |
| `fails gracefully with missing arguments` | Tests argument validation |
| `handles empty blob list file` | Tests behavior with empty keep list |
| `preserves repository structure and commits` | Validates commit history preservation |
| `handles various file types correctly` | Tests different file type handling |
| `provides clear success message and instructions` | Validates output messages |

## Test Fixtures

Tests generate realistic test data on-the-fly:

### Test Repository Contents
- **Normal files**: README.md, app.js, app.py
- **Secret files**: .env, config.js, settings.py, deploy.sh
- **Large files**: large-binary.bin (2MB), large-text.txt (1000+ lines)
- **Multiple commits**: 6 commits with meaningful messages

### Secret Types Tested
- **API Keys**: OpenAI, GitHub, Twitter tokens
- **Database credentials**: PostgreSQL connection strings
- **Django secrets**: Secret keys and passwords
- **Deployment tokens**: Build and deploy secrets

### Gitleaks Output Format
Tests use realistic gitleaks JSON output with:
- Multiple secret types
- Various file locations
- Different line numbers
- Proper metadata (author, date, commit hash)

## Test Helpers

### Setup Functions (`setup.bash`)
- `create_test_repo()` - Creates realistic test repository
- `create_gitleaks_output()` - Generates gitleaks JSON output
- `create_all_blobs_list()` - Creates blob preservation list with all repository blobs using --all
- `verify_secrets_removed()` - Validates secret removal
- `verify_large_files_removed()` - Validates blob removal
- `verify_important_files_preserved()` - Validates file preservation

### Assertion Functions (`assertions.bash`)
- `assert_file_exists()` - File existence validation
- `assert_git_repo()` - Git repository validation
- `assert_valid_json()` - JSON format validation
- `assert_file_contains()` - File content validation
- `assert_command_succeeds()` - Command success validation
- `assert_secret_not_found()` - Secret removal validation

## CI/CD Integration

### GitHub Actions
Tests run automatically on:
- **Push** to main/develop branches
- **Pull requests** to main branch
- **Manual trigger** via workflow_dispatch

### Workflow Jobs
1. **test-clean-secrets** - Tests clean-secrets.sh functionality
2. **test-clean-large-blobs** - Tests clean-large-blobs.sh functionality  
3. **test-integration** - Comprehensive integration tests

### Artifacts
On test failure, logs are uploaded as artifacts:
- `.clean-secrets.log` - Main execution log
- `.clean-secrets-commit-stats.json` - Processing statistics
- `.clean-secrets-callbacks.log` - Callback execution log

## Troubleshooting

### Common Issues

#### Permission Denied
```bash
# Make scripts executable
chmod +x clean-secrets.sh clean-large-blobs.sh
chmod +x tests/bats/helpers/*.bash
```

#### Missing Dependencies
```bash
# Install missing tools
sudo apt-get install -y git python3 jq bats
pip3 install git-filter-repo
```

#### Test Failures
1. Check test logs in `.clean-secrets.log`
2. Verify all dependencies are installed
3. Ensure scripts are executable
4. Check disk space (tests create temporary files)

### Debug Mode
```bash
# Run tests with debug output
bats tests/bats/ -v --tap
```

### Manual Testing
```bash
# Test individual components
./clean-secrets.sh --help
./clean-large-blobs.sh /path/to/repo /path/to/blobs 50000
```

## Contributing

### Adding New Tests
1. Create test case in appropriate `.bats` file
2. Use existing helper functions when possible
3. Add meaningful test descriptions
4. Include both success and failure scenarios

### Test Guidelines
- **Isolation**: Each test should be independent
- **Cleanup**: Use teardown functions to clean temporary files
- **Realistic**: Use realistic test data and scenarios
- **Clear**: Write clear, descriptive test names and assertions

### Running Tests Before Committing
```bash
# Run full test suite
bats tests/bats/

# Check for any issues
echo $?
```

## Performance

### Test Execution Time
- **Individual tests**: ~10-30 seconds each
- **Full suite**: ~5-10 minutes
- **CI/CD**: ~15-20 minutes (including setup)

### Resource Usage
- **Disk space**: ~100MB per test (temporary files)
- **Memory**: ~50MB per test
- **CPU**: Moderate usage during git operations

### Optimization Tips
- Tests run in parallel where possible
- Temporary files are cleaned up automatically
- Large files are generated efficiently using `dd`
