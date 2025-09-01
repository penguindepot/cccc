---
created: 2025-08-27T15:01:27Z
last_updated: 2025-09-01T16:35:00Z
version: 2.7
author: Claude Code CC System
---

# Project Structure

## Directory Organization

```
cccc/
├── .cccc/               # CCCC-specific data and configuration
│   ├── cccc-config.yml  # Main CCCC configuration file (created by PRISM)
│   ├── context/         # Project context documentation (9 files)
│   ├── epics/           # Generated technical epics (currently empty - test-prd archived)
│   └── prds/            # Product Requirements Documents
├── .cccc_frozen/        # Archived completed epics and PRDs
│   └── test-prd/        # ARCHIVED: Complete test-prd epic documentation
│   │       ├── 001-006.md         # Individual task files
│   │       ├── epic.md            # Epic overview and summary
│   │       ├── analysis.yaml      # NEW: All issue metadata and relationships
│   │       ├── sync-state.yaml    # NEW: Complete sync state and mappings
│   │       └── issues/            # Clean issue body files (no frontmatter)
│   │           ├── 001.1.md       # Clean markdown body only
│   │           ├── 001.2.md       # Clean markdown body only
│   │           ├── 001.3.md       # Clean markdown body only
│   │           ├── 002.1.md       # Clean markdown body only
│   │           ├── 002.2.md       # Clean markdown body only
│   │           ├── 003.1.md       # Clean markdown body only
│   │           ├── 003.2.md       # Clean markdown body only
│   │           ├── 003.3.md       # Clean markdown body only
│   │           ├── 004.1.md       # Clean markdown body only
│   │           ├── 004.2.md       # Clean markdown body only
│   │           ├── 004.3.md       # Clean markdown body only
│   │           ├── 005.1.md       # Clean markdown body only
│   │           ├── 005.2.md       # Clean markdown body only
│   │           ├── 006.1.md       # Clean markdown body only
│   │           ├── 006.2.md       # Clean markdown body only
│   │           └── summary.md     # Human-readable analysis summary
│   └── prds/            # Product Requirements Documents
├── .claude/             # Claude Code configuration
│   ├── cccc.md          # CCCC package configuration
│   ├── settings.local.json # Local Claude Code settings
│   ├── agents/          # Specialized sub-agent definitions
│   │   ├── cccc-code-analyzer.md    # Code analysis sub-agent
│   │   ├── cccc-file-analyzer.md    # File analysis sub-agent
│   │   ├── cccc-parallel-worker.md  # Parallel processing agent
│   │   └── cccc-test-runner.md      # Test execution agent
│   ├── commands/        # Custom command definitions
│   │   ├── cccc/        # CCCC-specific commands
│   │   │   ├── epic/    # Epic management commands (decompose, analyze, sync, next-issue, update-status, archive)
│   │   │   ├── issue/   # Issue management commands (update, mr, start)
│   │   │   ├── mr/      # Merge request management commands (update, fix, cleanup)
│   │   │   └── prd/     # PRD management commands
│   │   ├── context/     # Context management commands (create, prime, update, validate, close)
│   │   └── utils/       # Utility commands (push, rebase-all)
│   ├── rules/           # System rules and guidelines
│   │   ├── datetime.md           # Datetime handling standards
│   │   ├── github-operations.md # GitHub CLI patterns
│   │   ├── gitlab-operations.md # GitLab CLI patterns  
│   │   └── branch-operations.md # Branch-based development management
│   └── scripts/         # Automation scripts
│       ├── cccc/        # CCCC system scripts
│       │   ├── init.sh              # System initialization with yq installation
│       │   ├── epic-sync.sh         # Epic sync logic with proper YAML parsing
│       │   ├── epic-next-issue.sh   # Dependency-aware issue prioritization
│       │   ├── epic-update-status.sh # Real-time status tracking from GitLab/GitHub
│       │   ├── issue-update.sh      # Bidirectional issue sync with comment processing
│       │   ├── issue-mr.sh          # Merge request creation with proper rebasing workflow
│       │   ├── issue-start.sh       # Branch-based implementation launch with validation
│       │   ├── mr-update.sh         # MR comment fetching and feedback processing
│       │   ├── mr-fix.sh            # MR fix implementation and automated response posting
│       │   ├── mr-cleanup.sh        # NEW: Post-merge branch cleanup with validation and state updates
│       │   └── analyze-comment.sh   # NEW: MR comment analysis helper script
│       └── utils/        # NEW: Utility scripts
│           └── rebase-all.sh        # NEW: Branch hierarchy maintenance across all worktrees
├── .git/                # Git repository data
├── .prism/              # PRISM package manager data
├── AGENTS.md            # Agent configuration documentation
├── ARCHITECTURE.md      # System architecture and design patterns documentation
├── cccc-1.0.0.tar.gz    # PRISM package archive
├── CLAUDE.md            # Claude Code behavior guidelines
├── COMMANDS.md          # Command system documentation
├── CONTEXT-STRATEGY.md  # Context management and optimization strategies
├── PERFORMANCE.md       # Performance optimization approaches and metrics
├── prism-package.yaml   # PRISM package definition with variants and hooks
├── README.md            # Project documentation with PRISM installation instructions
└── ROADMAP.md           # Project roadmap, milestones, and future development plans
```

## File Naming Patterns
- **Commands**: Kebab-case (e.g., `prd-new.md`, `context-update.md`, `epic-analyze.md`)
- **Documentation**: PascalCase for system docs (e.g., `CLAUDE.md`, `AGENTS.md`)
- **Context Files**: Kebab-case with descriptive names (e.g., `project-structure.md`)
- **PRDs**: Kebab-case matching feature names (e.g., `test-prd.md`)
- **Issue Files**: Format `issue-{task}.{sub}.md` (e.g., `issue-001.1.md`, `issue-002.3.md`)
- **Task Files**: Three-digit numbering (e.g., `001.md`, `002.md`, `003.md`)

## Key Directories

### `.claude/commands/`
Houses all custom Claude Code commands organized by namespace:
- `cccc/prd/` - PRD lifecycle management
- `cccc/epic/` - Epic analysis, sync, and issue management
- `cccc/issue/` - Individual issue operations, MR creation, and branch-based implementation start
- `cccc/mr/` - MR lifecycle: update, fix, cleanup workflow automation
- `context/` - Context lifecycle management: create, prime, update, validate, close
- `utils/` - Cross-cutting utility operations

### `.cccc/`
Project-specific data storage:
- `context/` - Structured documentation for maintaining context between sessions  
- `prds/` - Product requirement documents with frontmatter metadata
- `epics/` - Active technical epics with implementation details

### `.cccc_frozen/`
Archive storage for completed work:
- Complete epic documentation preserved after cccc:epic:archive
- Maintains full project history and implementation details
- Includes sync-state.yaml files with platform issue mappings

### Root Level Files
- **prism-package.yaml**: PRISM package definition with three variants (minimal/standard/full) and lifecycle hooks
- **cccc-1.0.0.tar.gz**: Packaged PRISM distribution archive
- **ARCHITECTURE.md**: System architecture and design patterns documentation
- **CLAUDE.md**: Defines AI behavior, tone, and absolute rules
- **AGENTS.md**: Configurations for specialized sub-agents
- **COMMANDS.md**: Index and documentation of available commands
- **CONTEXT-STRATEGY.md**: Context management and optimization strategies
- **PERFORMANCE.md**: Performance optimization approaches and metrics
- **README.md**: Updated with PRISM installation instructions and variant descriptions
- **ROADMAP.md**: Project roadmap, milestones, and future development plans

## Module Organization
The project follows a command-based architecture where:
- Each command is self-contained with its own validation and execution logic
- Commands can reference shared rules (e.g., `datetime.md`)
- Context files maintain project state between sessions
- PRDs drive feature development through structured documentation

## Integration Points
- **PRISM Package System**: Distributable package with automated installation and dependency management
- **Git Integration**: Full git repository with GitLab/GitHub remote support
- **Claude Code**: Native integration through .claude directory
- **Command System**: Extensible command framework via markdown definitions
- **Context System**: Persistent state management across sessions
- **Dependency Management**: Automated installation of yq, jq, gh, glab tools via PRISM hooks