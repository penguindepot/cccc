# CCCC (Claude Code Command Center)

A sophisticated command and context management system that solves AI coding session context loss through persistent session management, complete PRD-to-implementation workflow automation, and deep GitLab/GitHub integration.

## Overview

CCCC provides a complete end-to-end development workflow that maintains context across AI coding sessions and automates the journey from Product Requirements Document (PRD) to implementation.

### Key Features

- **Persistent Context Management**: Never lose project context between AI sessions
- **Complete Workflow Automation**: PRD → Epic → Issue → Implementation → Review
- **Dual Platform Integration**: GitLab and GitHub support with bidirectional sync
- **Intelligent Issue Management**: Dependency-aware prioritization and automation
- **MR Feedback Workflows**: Automated fix implementation from review feedback
- **Performance Optimized**: 7-phase parallel execution (1.65x speedup)

## Quick Start

### Prerequisites

- Claude Code CLI installed and configured
- Git repository with GitLab or GitHub remote
- Platform CLI tools (`gh` for GitHub, `glab` for GitLab)
- `yq` and `jq` for YAML/JSON processing

### Initialize Project Context

```bash
# Create initial project context
/context:create

# Prime context for new sessions
/context:prime

# Update context with recent changes
/context:update
```

## Core Workflows

### 1. PRD-to-Implementation Workflow

```bash
# Initialize CCCC system (first time only)
/cccc:init

# Create PRD from requirements
/cccc:prd:new

# Generate implementation epic from PRD
/cccc:prd:parse

# Analyze and break down epic into issues
/cccc:epic:analyze

# Sync issues to GitLab/GitHub
/cccc:epic:sync
```

### 2. Development Workflow

```bash
# Check which issues are ready to work on
/cccc:epic:next-issue

# Create merge request for an issue
/cccc:issue:mr {issue-number}

# Start implementation work on the MR
/cccc:mr:start

# Update with latest MR feedback
/cccc:mr:update

# Implement specific fixes from feedback
/cccc:mr:fix

# Clean up after MR is merged
/cccc:mr:cleanup {epic-name} {issue-number}
```

### 3. Context Management

```bash
# Validate current context integrity
/context:validate

# Update context with recent changes
/context:update

# Close session and preserve context
/context:close
```

## Architecture

### Core Components

- **Command Layer** (`.claude/commands/`): Modular command system with validation-first approach
- **Context Layer** (`.cccc/context/`): 9 specialized context files for comprehensive project understanding
- **Scripts Layer** (`.claude/scripts/`): Complex automation logic and platform integrations
- **Rules Layer** (`.claude/rules/`): Shared behavioral patterns and conventions

### Key Patterns

- **Hybrid Storage**: YAML for machine data + Markdown for human content (30-40% token efficiency)
- **Script Separation**: Commands handle validation, scripts handle complex logic
- **Validation-First**: Comprehensive checks before any operation
- **API Integration**: Multi-platform support with graceful degradation
- **Sub-agent Delegation**: Specialized agents for file analysis, code analysis, and test execution

## Context Files

The `.cccc/context/` directory contains 9 specialized files:

1. **project-overview.md** - High-level project understanding
2. **project-brief.md** - Core purpose and goals
3. **tech-context.md** - Technical stack and dependencies
4. **progress.md** - Current status and recent work
5. **project-structure.md** - Directory and file organization
6. **system-patterns.md** - Architecture and design patterns
7. **product-context.md** - User needs and requirements
8. **project-style-guide.md** - Coding conventions
9. **project-vision.md** - Long-term direction

## Commands Reference

### CCCC Commands (Epic & Issue Management)

#### System Commands
- `/cccc:init` - Initialize CCCC system with platform choice (GitHub/GitLab)

#### PRD (Product Requirements) Commands
- `/cccc:prd:new` - Create comprehensive PRD with brainstorming and all sections
- `/cccc:prd:parse` - Convert PRD to technical implementation epic with architecture decisions

#### Epic Commands
- `/cccc:epic:analyze` - Analyze epic to decompose tasks into parallel GitHub/GitLab issues with dependency graph
- `/cccc:epic:decompose` - Break epic into concrete, actionable tasks with numbered files (001.md, 002.md, etc.)
- `/cccc:epic:next-issue` - Determine which issues can be worked on next based on dependencies and current status
- `/cccc:epic:sync` - Sync epic and issues from YAML analysis to configured platform with cross-references
- `/cccc:epic:update-status` - Update issue statuses by querying current states from GitLab/GitHub

#### Issue Commands
- `/cccc:issue:mr` - Create merge request (GitLab) or pull request (GitHub) for specific issue with proper rebasing
- `/cccc:issue:update` - Update local issue files with latest content from GitLab/GitHub (supports --all flag)

#### MR (Merge Request) Commands
- `/cccc:mr:fix` - Analyze stored MR feedback and implement requested fixes using an agent
- `/cccc:mr:start` - Start implementation work on existing merge request by launching completion agent
- `/cccc:mr:update` - Update local sync-state with latest MR comments and feedback from platform
- `/cccc:mr:cleanup` - Clean up local and remote branches after MR merge with safety verification

### Context Commands (Project Context Management)
- `/context:create` - Create initial project context documentation with 9 comprehensive context files
- `/context:prime` - Load essential context for new agent session by reading project documentation
- `/context:update` - Update project context documentation to reflect current state
- `/context:validate` - Validate integrity and freshness of project context documentation
- `/context:close` - End development session cleanly by updating context, committing, and rebasing

### Utils Commands (Development Utilities)
- `/utils:push` - Commit and push all changes with smart commit grouping and descriptive messages
- `/utils:rebase-all` - Rebase all epic branches on main and issue branches on epics (supports --dry-run)

## Development Guidelines

### Code Standards
- No partial implementation or simplification comments
- Comprehensive testing for every function
- No code duplication - reuse existing functions
- Validation-first approach with error recovery
- Sub-agent delegation for complex tasks

### File Naming Conventions
- Commands: kebab-case (`context-create.md`)
- Documentation: UPPERCASE (`CLAUDE.md`) or kebab-case
- Issues: Format `{task}.{sub}.md` (e.g., `001.1.md`)

### Git Integration
- Branch hierarchy maintenance across worktrees
- Force-with-lease safety for protected operations
- Automated cross-referencing between issues and MRs
- Dependency-aware merge ordering

## Platform Integration

### GitLab Features
- Issue creation and synchronization
- Merge request automation
- Project milestone management
- API-driven workflow automation

### GitHub Features
- Issue and PR management
- Project board integration
- Review workflow automation
- Cross-platform compatibility

## Status

**Current Phase**: Production Ready - Phase 1 Complete

✅ **Completed Features**:
- Context lifecycle management
- PRD creation and parsing
- Complete epic analysis with parallel execution
- GitLab/GitHub issue synchronization
- MR feedback workflow automation
- Issue 001.1 (Basic Implementation Infrastructure)

🚧 **In Development**:
- MCP Thread Continuity integration
- Advanced GitLab API features
- Performance optimizations

## Contributing

This project follows strict engineering standards:

1. Read existing codebase patterns before implementing
2. Use validation-first approach for all operations
3. Implement comprehensive error handling
4. Follow existing naming conventions
5. Test all functionality thoroughly
6. Document workflow patterns

## License

MIT License - See LICENSE file for details

## Support

For issues and feature requests, please use the GitLab issue tracker at:
https://gitlab.com/penguindepot/cccc/-/issues