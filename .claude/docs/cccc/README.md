# CCCC Documentation

Claude Code Command Center (CCCC) is a complete command and context management system for AI-assisted development.

## Package Overview

CCCC provides a comprehensive workflow from Product Requirements Document (PRD) to implementation, with persistent context management and dual platform integration for GitLab and GitHub.

### Key Features

- **Persistent Context Management**: Never lose project context between AI sessions
- **Complete Workflow Automation**: PRD → Epic → Issue → Implementation → Review
- **Dual Platform Integration**: GitLab and GitHub support with bidirectional sync
- **Intelligent Issue Management**: Dependency-aware prioritization and automation
- **MR Feedback Workflows**: Automated fix implementation from review feedback
- **Performance Optimized**: 7-phase parallel execution (1.65x speedup)

### Installation Variants

- **minimal**: Essential context management only (10 commands)
- **standard**: Full workflows including PRD and Epic management (25 commands)
- **full**: Complete system with MR workflows and GitLab/GitHub integration (40+ commands)

### Command Categories

1. **Context Management** (`/context:*`)
2. **PRD Workflow** (`/cccc:prd:*`)
3. **Epic Management** (`/cccc:epic:*`)
4. **Issue Management** (`/cccc:issue:*`)
5. **Merge Request Lifecycle** (`/cccc:mr:*`)
6. **Utilities** (`/cccc:utils:*`)

### System Requirements

- Git >= 2.0.0 (required)
- Optional: yq, jq, gh, glab for enhanced functionality

For detailed command documentation, see the individual command files in `.claude/commands/cccc/`.