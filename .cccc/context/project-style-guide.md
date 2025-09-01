---
created: 2025-08-27T15:01:27Z
last_updated: 2025-09-01T16:35:00Z
version: 1.1
author: Claude Code CC System
---

# Project Style Guide

## Coding Standards

### File Naming Conventions

#### Commands
- **Format**: Kebab-case (e.g., `context-create.md`, `prd-parse.md`)
- **Structure**: `{verb}-{noun}.md` or single `{verb}.md`
- **Location**: `.claude/commands/{namespace}/{command}.md`

#### Documentation
- **System Docs**: UPPERCASE (e.g., `CLAUDE.md`, `AGENTS.md`, `README.md`)
- **Package Files**: Kebab-case YAML (e.g., `prism-package.yaml`)
- **Context Files**: Kebab-case (e.g., `project-overview.md`, `tech-context.md`)
- **PRDs**: Feature-based kebab-case (e.g., `user-auth.md`, `payment-v2.md`)
- **Config Files**: Kebab-case with extension (e.g., `cccc-config.yml`, `sync-state.yaml`)

#### Directories
- **Hidden Dirs**: Lowercase with dot prefix (e.g., `.cccc/`, `.claude/`, `.prism/`)
- **Subdirs**: Lowercase, no spaces (e.g., `context/`, `prds/`, `commands/`)
- **Archive Dirs**: Descriptive suffix (e.g., `.cccc_frozen/`, `.backup/`)

### Markdown Formatting

#### Frontmatter Structure
```yaml
---
created: 2025-08-27T15:01:27Z      # ISO 8601 UTC timestamp
last_updated: 2025-08-27T15:01:27Z # ISO 8601 UTC timestamp
version: 1.0                       # Semantic versioning
author: Claude Code CC System       # System identifier
---
```

#### Section Headers
```markdown
# Main Title (H1 - One per file)
## Major Section (H2 - Primary divisions)
### Subsection (H3 - Secondary divisions)
#### Detail Level (H4 - Specific topics)
```

#### Lists and Formatting
- **Bullet Points**: Use `-` for unordered lists
- **Numbered Lists**: Use `1.` with proper indentation
- **Bold Text**: Use `**text**` for emphasis
- **Code Inline**: Use \`backticks\` for code
- **Code Blocks**: Use triple backticks with language identifier

### PRISM Package Standards

#### Package Definition Structure
```yaml
# prism-package.yaml structure
name: package-name
version: semantic-version  
description: clear-description
author: author-name
license: license-type
repository: repo-url
keywords: [relevant, tags]

claudeCode:
  minVersion: minimum-version

structure:
  commands: [mapping-definitions]
  scripts: [mapping-definitions]
  agents: [mapping-definitions]

variants:
  minimal: [variant-definition]
  standard: [variant-definition]
  full: [variant-definition]

hooks:
  preInstall: |script|
  postInstall: |script|
```

### Command Structure Pattern

#### Required Sections
1. **Frontmatter**: Tool permissions and metadata
2. **Title**: Clear command description
3. **Required Rules**: References to shared rules
4. **Preflight Checklist**: Validation steps
5. **Instructions**: Core execution logic
6. **Error Handling**: Recovery strategies

#### Command Template
```markdown
---
allowed-tools: Bash, Read, Write, LS
---

# Command Name

Brief description of what this command does.

## Required Rules
**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/rule-name.md` - Rule description

## Preflight Checklist
[Validation steps]

## Instructions
[Core logic]
```

### Status Indicators

#### Emoji Usage
- ✅ Success/Completed
- ❌ Error/Failed
- ⚠️ Warning/Caution
- 📁 Directory/File reference
- 📋 List/Summary
- 🔄 Update/Refresh
- 💡 Tip/Suggestion
- 🎯 Goal/Target
- 🚧 In Progress/Development
- 📅 Planned/Future

#### Status Colors (Staleness)
- 🟢 Fresh (≤3 days)
- 🟡 Getting Stale (4-7 days)
- 🟠 Stale (8-14 days)
- 🔴 Very Stale (>14 days)

### Package Distribution Standards

#### Installation Variants
- **minimal**: Essential context management (10 commands)
- **standard**: Full workflows excluding MR management (25 commands)
- **full**: Complete system with all features (40+ commands)

#### Dependency Management
- System dependencies defined in `dependencies.system`
- Auto-installation via package hooks
- Version requirements clearly specified
- Graceful degradation when optional tools missing

### Git Commit Messages

#### Format
```
<type>: <description>

[optional body]

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

#### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code restructuring
- `test`: Test additions/changes
- `chore`: Maintenance tasks
- `package`: PRISM package updates

### Bash Command Standards

#### Safety Practices
- Always check file existence before operations
- Use `2>/dev/null` to suppress expected errors
- Quote variables and paths with spaces
- Use `&&` for dependent operations
- Provide fallbacks with `||`

#### Common Patterns
```bash
# Check and create directory
mkdir -p /path/to/dir

# Safe file test
test -f "file.txt" && echo "exists" || echo "missing"

# Git status check
git status 2>/dev/null || echo "not a git repo"

# Date generation
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

### Error Message Format

#### Structure
```
❌ <Error Type>: <Specific Issue>
   Solution: <Actionable Steps>
   Example: <Correct Usage>
```

#### Examples
```
❌ Validation Error: Feature name must be kebab-case
   Solution: Use lowercase letters, numbers, and hyphens only
   Example: user-auth, payment-v2, notification-system
```

### Documentation Comments

#### Command Documentation
- Explain WHY, not just WHAT
- Include examples for complex operations
- Document edge cases and limitations
- Provide troubleshooting guidance

#### Code Comments
- Minimal inline comments (code should be self-documenting)
- Comments only for complex logic or workarounds
- Use TODO/FIXME/NOTE prefixes for special comments

### Validation Patterns

#### Input Validation
```bash
# Feature name validation
echo "$name" | grep -E '^[a-z][a-z0-9-]*$' || error "Invalid name"

# File existence
test -f "$file" || error "File not found"

# Directory writable
test -w "$dir" || error "No write permission"
```

#### Output Validation
- Check command exit codes
- Verify file creation
- Validate file content structure
- Confirm state changes

### Summary Format

#### Success Summary Template
```
✅ <Action> Complete

📊 Statistics:
  - Metric 1: value
  - Metric 2: value

📝 Details:
  - Specific outcome 1
  - Specific outcome 2

💡 Next Steps:
  - Suggested action
```

### Code Organization

#### Logical Grouping
1. Imports/Dependencies
2. Configuration/Constants
3. Validation Functions
4. Core Logic
5. Error Handling
6. Output/Summary

#### Function Patterns
- Single responsibility principle
- Clear input/output contracts
- Error handling at boundaries
- Descriptive function names

### Testing Conventions

#### Test Organization
- One test file per command
- Clear test descriptions
- Setup/teardown patterns
- Isolated test environment

#### Test Naming
```
test_<command>_<scenario>_<expected_outcome>
```

### Performance Guidelines

#### Efficiency Practices
- Process files in parallel when possible
- Use early returns for validation
- Cache repeated calculations
- Limit file read operations
- Show progress for long operations

#### Resource Limits
- Max file size: 100KB for context files
- Max line length: 2000 characters
- Max frontmatter fields: 10
- Command timeout: 30 seconds default

### Package Lifecycle Standards

#### Installation Process
1. Pre-install validation (git repo, permissions)
2. Directory structure creation (.cccc/, .cccc_frozen/)
3. Configuration file generation (cccc-config.yml)
4. Dependency installation (yq, jq, gh/glab)
5. .gitignore updates for CCCC files
6. Post-install validation and guidance

#### Uninstallation Process
1. Data backup creation (.cccc.backup/)
2. Active work detection and warnings
3. File removal with confirmation
4. Manual cleanup instructions
5. Registry cleanup preparation

### Security Practices

#### File Operations
- Always validate paths are within project
- Check permissions before writing
- Never execute user input directly
- Sanitize filenames and content

#### Information Handling
- No sensitive data in commits
- No credentials in context files
- Local storage only
- Clear error messages without exposing internals
- Package distribution security validation