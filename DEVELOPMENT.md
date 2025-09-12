# Development Guide

This document contains development and testing information for the Git repository migration and security tools.

## Testing

This repository includes comprehensive end-to-end (e2e) tests using the [Bats](https://github.com/bats-core/bats-core) testing framework.

### Quick Start

```bash
# Run all tests
just test-all

# Run tests with verbose output
just test-verbose

# Run specific test suites
just test-secrets
just test-blobs

# Run all tests from a specific BATS file
just test-file-single tests/bats/test_clean_secrets.bats
just test-file-single tests/bats/test_clean_large_blobs.bats

# Run all tests from a specific BATS file with verbose output
just test-file-single tests/bats/test_clean_secrets.bats "-v"
just test-file-single tests/bats/test_clean_large_blobs.bats "-v"

# Run individual tests from specific files
just test-file-single tests/bats/test_clean_secrets.bats "clean-secrets.sh: successfully removes secrets from git history"
just test-file-single tests/bats/test_clean_large_blobs.bats "clean-large-blobs.sh: successfully removes large blobs from git history"

# Run individual tests with verbose output
just test-file-single tests/bats/test_clean_secrets.bats "clean-secrets.sh: handles multiple secrets in same file" "-v"
```

### Running Individual Tests

You can run individual test functions using the `test-file-single` command:

```bash
# Run all tests from a specific BATS file
just test-file-single tests/bats/test_clean_secrets.bats

# Run a specific test from a specific BATS file
just test-file-single tests/bats/test_clean_secrets.bats "test-name"

# Run with verbose output
just test-file-single tests/bats/test_clean_secrets.bats "test-name" "-v"

# Run with trace output
just test-file-single tests/bats/test_clean_secrets.bats "test-name" "-t"

# Run with both verbose and trace output
just test-file-single tests/bats/test_clean_secrets.bats "test-name" "-v -t"
```

### Available Test Commands

The justfile provides several flexible test commands:

```bash
# Run a specific BATS file (all tests)
just test-file tests/bats/test_clean_secrets.bats

# Run a specific BATS file with verbose output
just test-file tests/bats/test_clean_secrets.bats "-v"

# Run a specific BATS file with trace output
just test-file tests/bats/test_clean_secrets.bats "-t"

# Run a specific BATS file with both verbose and trace
just test-file tests/bats/test_clean_secrets.bats "-v -t"

# Run all tests from a specific file (same as test-file)
just test-file-single tests/bats/test_clean_secrets.bats

# Run a single test from a specific file
just test-file-single tests/bats/test_clean_secrets.bats "test-name"

# Run a single test with verbose output
just test-file-single tests/bats/test_clean_secrets.bats "test-name" "-v"

# Run a single test with trace output
just test-file-single tests/bats/test_clean_secrets.bats "test-name" "-t"

# Run a single test with both verbose and trace
just test-file-single tests/bats/test_clean_secrets.bats "test-name" "-v -t"
```

**Available test cases:**

To see all available test cases with descriptions, run:

```bash
just list-tests
```

This command dynamically extracts test information from the BATS files, ensuring the list is always up-to-date when tests are added or modified.

### Running Tests Directly with Bats

You can also run tests directly using bats commands:

```bash
# Run all tests
bats tests/bats/

# Run specific test suites
bats tests/bats/test_clean_secrets.bats
bats tests/bats/test_clean_large_blobs.bats

# Run individual tests
bats tests/bats/test_clean_secrets.bats -f "successfully removes secrets"

# Run with verbose output
bats tests/bats/ -v

# Run with trace output
bats tests/bats/ -t

# Run with both verbose and trace
bats tests/bats/ -v -t
```

### Prerequisites

```bash
# macOS
brew install git jq bats-core bfg gitleaks
pip3 install git-filter-repo

# Ubuntu/Debian
sudo apt-get install -y git python3 python3-pip jq bats
# Install BFG from: https://rtyley.github.io/bfg-repo-cleaner/
curl -s https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | bash
pip3 install git-filter-repo
```

#### Install Gitleaks

Gitleaks is used for detecting secrets and sensitive information in repositories.

```bash
# Mac
brew install gitleaks

# Linux
curl -s https://raw.githubusercontent.com/gitleaks/gitleaks/master/install.sh | bash

# Verify installation
gitleaks version
```

### Test Coverage

The test suite validates:
- **Secret removal**: Removes sensitive data from git history using gitleaks analysis
- **Blob cleanup**: Removes large files while preserving important files
- **Error handling**: Graceful failure with invalid inputs
- **Progress tracking**: Statistics and logging functionality
- **Edge cases**: Empty files, malformed data, missing arguments

For detailed testing documentation, see [tests/README.md](tests/README.md).

### CI/CD

Tests run automatically on GitHub Actions for:
- Push to main/develop branches
- Pull requests to main branch
- Manual workflow dispatch

## Development Workflow

### Project Structure

The project is organized with:
- **Script files** in the root directory: `clean-large-blobs.sh`, `clean-secrets.sh`
- **Python callbacks** in `clean-secrets-callbacks/` for git-filter-repo secret cleanup operations
- **BATS tests** in `tests/bats/` for automated testing

### Safety Guidelines

**CRITICAL**: Never run these cleanup tools against the repository containing the script code itself. This project contains repository migration and cleanup scripts.

#### Safe Testing Practices

1. **Always Use Temporary Directories**
   ```bash
   # ✅ SAFE - Use existing test repo
   cd produzionidalbasso.git
   ./clean-large-blobs.sh . blobs-to-keep.txt 1000000 --yes
   
   # ✅ SAFE - Create random temporary directory
   export TEST_REPO_DIR=$(mktemp -d)
   cd "$TEST_REPO_DIR"
   git clone /path/to/source-repo .
   ./clean-large-blobs.sh . blobs-to-keep.txt 1000000 --yes
   # Cleanup when done
   rm -rf "$TEST_REPO_DIR"
   ```

2. **Use Environment Variables for Cleanup**
   ```bash
   # Create and track temp directories
   export TEMP_REPO=$(mktemp -d)
   export TEMP_ANALYSIS=$(mktemp -d)
   
   # Cleanup function
   cleanup_temp_dirs() {
       rm -rf "$TEMP_REPO" "$TEMP_ANALYSIS"
       unset TEMP_REPO TEMP_ANALYSIS
   }
   
   # Set trap for automatic cleanup on exit
   trap cleanup_temp_dirs EXIT
   ```

### Tool Usage

#### BFG Repo-Cleaner Usage (`clean-large-blobs.sh`)
- Always work on fresh clones of repositories
- Use `--strip-blobs-bigger-than` for size-based filtering
- BFG automatically protects blobs from HEAD by default
- Clean up reflogs and garbage collect after operations

#### git-filter-repo Usage (`clean-secrets.sh`)
- Always work on fresh clones of repositories
- Use Python callbacks for complex content analysis and modification
- Integrate with gitleaks for sophisticated secret detection
- Clean up reflogs and garbage collect after operations

#### Gitleaks Usage
- Run gitleaks before cleanup operations to generate scan results
- Use custom configuration files for project-specific rules
- Generate reports for audit trails
- Integrate with pre-commit hooks for ongoing security

### Troubleshooting

- Check logs in `clean-secrets.log` and `commit-progress.log`
- Use debug BATS tests for detailed analysis
- Verify BFG operations with `git cat-file` commands
- Verify git-filter-repo operations with `git cat-file` commands
- Check gitleaks configuration and rules

### Security Considerations

- Never commit actual secrets to version control
- Use environment variables for sensitive configuration
- Regularly audit repository history for accidental commits
- Implement pre-commit hooks to prevent future issues
- Maintain audit logs of all cleanup operations

## MDC Files and Cursor 7 Integration

This project includes MDC (Markdown Documentation Context) files that provide enhanced context for AI-powered development tools like Cursor 7. These files contain structured documentation and rules that help AI assistants understand the project's architecture, workflows, and safety requirements.

### MDC Files in This Project

The following MDC files are present and provide context for AI tools:

- **Project rules and safety guidelines** - Embedded in workspace configuration
- **Repository cleanup safety rules** - Critical safety requirements for repository operations
- **Tool integration guidelines** - Best practices for BFG Repo-Cleaner, git-filter-repo, and gitleaks usage

### Updating Rules with Cursor 7

When updating or modifying the tools in this project, it's recommended to also update the corresponding MDC rules to ensure AI assistants have accurate context:

#### 1. Tool Updates
When you modify any of the core scripts (`clean-large-blobs.sh`, `clean-secrets.sh`) or Python callbacks:

```bash
# After updating scripts, consider updating MDC rules
# Review the safety guidelines in workspace rules
# Update any tool-specific instructions if behavior changes
```

#### 2. New Tool Integration
If you add new tools or modify the workflow:

- **Update safety rules** - Ensure new tools follow the same safety principles
- **Document new commands** - Add new justfile commands to MDC context
- **Update test coverage** - Ensure new functionality is covered in BATS tests

#### 3. Configuration Changes
When modifying configuration files or adding new ones:

- **Update project structure documentation** - Reflect new files in MDC context
- **Document new environment variables** - Add to safety guidelines if needed
- **Update prerequisites** - Include new dependencies in installation instructions

#### 4. Best Practices for MDC Updates

- **Keep rules current** - Regularly review and update MDC content
- **Test with AI tools** - Verify that updated rules provide accurate context
- **Maintain consistency** - Ensure MDC rules align with actual project behavior
- **Document breaking changes** - Clearly indicate when rules change significantly

### Benefits of MDC Integration

- **Enhanced AI assistance** - Better context for code generation and debugging
- **Consistent safety practices** - AI tools understand critical safety requirements
- **Improved development workflow** - Faster onboarding and tool usage
- **Reduced errors** - AI assistants can warn about unsafe operations

### Example MDC Rule Update

If you modify the `clean-large-blobs.sh` script to support new file types:

```markdown
# Update the safety rules to include new file type handling
# Add new file patterns to the safety guidelines
# Update the BFG tool usage examples in MDC context
```

This ensures that AI assistants working with the updated tools have the most current and accurate information about the project's capabilities and safety requirements.

### Example Prompt for Updating Rules with Cursor 7

When you need to update the MDC rules after modifying tools, you can use this prompt with Cursor 7 and MCP Context7:

```
I've updated the external tool documentation and configuration for this project. Please help me update the MDC rules to reflect these changes:

1. Update the safety guidelines to include the new external tool capabilities
2. Add the new tool usage examples to the documentation
3. Update the project structure documentation to reflect any new external tool integrations
4. Ensure the repository cleanup safety rules mention the new external tool features
5. Update the test coverage section to include testing for the new external tool functionality

The external tools now include:
- Updated BFG Repo-Cleaner configuration with new options
- Enhanced git-filter-repo integration with Python callbacks
- Enhanced gitleaks integration with additional rules
- New external tool dependencies and their configurations
- Updated environment variables for external tool customization

Tool IDs to reference:
- BFG Repo-Cleaner: /rtyley/bfg-repo-cleaner
- git-filter-repo: /git/git-filter-repo
- gitleaks: /gitleaks/gitleaks
- bats: /bats-core/bats-core

Please review the current MDC rules and suggest specific updates to maintain consistency with these external tool changes.
```

#### Alternative Prompt for Specific Rule Updates

For more targeted updates, you can use this focused prompt:

```
I need to update the MDC rules for external tool integration. The project now includes updated external tool configurations:

- Updated BFG Repo-Cleaner configuration with new safety options
- Enhanced git-filter-repo integration with Python callbacks for secret cleanup
- Enhanced gitleaks rules and detection patterns
- New external tool environment variables for configuration
- Modified external tool integration with enhanced error handling

Tool IDs to reference:
- BFG Repo-Cleaner: /rtyley/bfg-repo-cleaner
- git-filter-repo: /git/git-filter-repo
- gitleaks: /gitleaks/gitleaks

Please help me update the safety rules to:
1. Include the new external tool configurations in the safety guidelines
2. Add the new environment variables to the external tool documentation
3. Update the cleanup examples to include the new external tool functionality
4. Ensure the "Never run cleanup tools against the repository containing the script code itself" rule is still prominent
5. Document any new safety considerations for the enhanced external tool features

Use the MCP Context7 to fetch the current rules and suggest specific line-by-line updates.
```

#### Using MCP Context7 for Rule Updates

When working with Cursor 7, you can leverage MCP Context7 to:

1. **Fetch current rules**: Get the existing MDC content to understand current state
2. **Compare changes**: Identify what needs updating based on your tool modifications
3. **Generate updates**: Create specific rule updates that maintain consistency
4. **Validate changes**: Ensure new rules don't conflict with existing safety guidelines

Example workflow:
```bash
# 1. Make your tool changes
git add clean-large-blobs.sh
git commit -m "Add archive file support to clean-large-blobs.sh"

# 2. Use Cursor 7 with the prompt above to update MDC rules
# 3. Review the suggested updates
# 4. Apply the rule changes
# 5. Test that AI assistants understand the new capabilities
```

This approach ensures that your MDC rules stay synchronized with your tool updates, providing accurate context for AI-powered development assistance.
