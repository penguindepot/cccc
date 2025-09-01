---
created: 2025-08-27T15:01:27Z
last_updated: 2025-09-01T16:35:00Z
version: 1.6
author: Claude Code CC System
---

# Technical Context

## Technology Stack

### Core Technologies
- **Version Control**: Git with GitLab/GitHub remote repository support
- **Package System**: PRISM package manager for distribution and installation
- **Multi-Platform Support**: GitHub and GitLab integration with platform detection
- **Primary Language**: Markdown-based configuration and documentation
- **Data Format**: YAML for metadata and relationships (30-40% token efficiency over JSON)
- **Command Framework**: Claude Code command system using markdown definitions
- **Shell Scripting**: Bash for automation and system interactions
- **Hybrid Storage**: YAML for machine data + Markdown for human content
- **Distribution**: PRISM package with variants (minimal, standard, full)

### Development Environment
- **Platform**: macOS (Darwin 24.5.0)
- **IDE Integration**: Claude Code with IDE file monitoring
- **Git Remote**: GitLab (gitlab.com:penguindepot/cccc.git)

### Claude Code Integration
- **Command System**: Custom commands via .claude/commands/ directory
- **Rules Engine**: Behavioral rules in .claude/rules/
- **Sub-Agents**: Specialized agents for file analysis, code analysis, and test running
- **Memory System**: CLAUDE.md for persistent project guidelines

## Dependencies

### System Requirements
- Git for version control (>=2.0.0)
- Bash shell for command execution
- File system with write permissions
- Claude Code CLI tool (>=1.0.0)
- PRISM package manager for installation

### Platform CLI Tools
- **GitHub CLI** (`gh`): For GitHub issue and repository operations (auto-installed)
- **GitLab CLI** (`glab`): For GitLab issue and repository operations (auto-installed)
- **yq**: YAML processing for analysis.yaml parsing (auto-installed via PRISM hooks)
- **jq**: JSON processing for CLI output parsing (auto-installed via PRISM hooks)

### Command Dependencies
- **DateTime Rule**: Standardized timestamp generation using system clock
- **Directory Structure**: Requires .cccc/ and .claude/ directories
- **Frontmatter Parser**: YAML-compatible frontmatter in markdown files

## Development Tools

### Command Line Tools
- `date` - For ISO 8601 timestamp generation
- `git` - Version control operations
- `gh` - GitHub CLI for issue operations
- `glab` - GitLab CLI for issue operations
- `yq` - YAML parsing for analysis.yaml (NEW: replaces error-prone grep patterns)
- `jq` - JSON parsing for CLI output
- `ls`, `test`, `stat` - File system operations
- `sed`, `grep` - Text processing and validation
- `mkdir` - Directory creation

### Configuration Files
- **CLAUDE.md**: AI behavior configuration
- **prism-package.yaml**: PRISM package definition with variants and hooks
- **.cccc/cccc-config.yml**: CCCC system configuration (created by PRISM)
- **AGENTS.md**: Sub-agent definitions
- **COMMANDS.md**: Command registry
- **.claude/rules/**: Shared rule definitions
- **.gitignore**: CCCC-specific ignore patterns (auto-updated)

## Architecture Patterns

### Command Pattern (Phase 1.5 Optimization)
Commands are being optimized for performance:
1. Frontmatter with tool permissions
2. **Extracted Preflight Validation**: Standalone bash scripts for system validation (30-40% context reduction)
3. **Minimal Context Loading**: Progressive context based on operation complexity
4. Core instruction execution with agent isolation
5. Error handling and recovery
6. Post-execution summary with performance metrics

### Context Management Pattern (Optimized)
Enhanced context management for performance:
1. Structured markdown files with frontmatter and YAML metadata
2. **Smart Context Loading**: None/Minimal/Light/Full context levels based on operation
3. **Context Caching**: Multi-level caching with intelligent invalidation
4. **Progressive Loading**: Start minimal, upgrade as needed
5. Systematic validation and updates with performance tracking
6. Git-aware staleness detection
7. Cross-reference integrity with consistency validation

### PRD Workflow Pattern
Product development lifecycle:
1. PRD creation with structured sections
2. Parsing into actionable epics
3. Implementation tracking
4. Context preservation

## Security Considerations
- Local file system storage only
- No external API dependencies
- Git-based version control for audit trail
- Permission checks before file operations

## Performance Characteristics & Optimization
- Lightweight markdown-based storage with YAML metadata optimization
- Fast file system operations with smart caching strategies  
- **Phase 1.5 Optimization**: 60-80% context reduction potential through preflight extraction
- **Bash Separation**: Pure bash operations isolated from Claude processing for 50% speed improvement
- **Agent Isolation**: Minimal context passing to sub-agents to reduce redundant processing
- Scalable command structure with progressive context loading
- **Performance Monitoring**: Context usage analytics and efficiency reporting

## Integration Capabilities
- Git hooks potential for automation
- MCP server compatibility for enhanced persistence
- Claude Desktop thread continuity support
- Extensible command framework for new features
- **PRISM Package System**: Distributable package with lifecycle management
- **Installation Variants**: Flexible deployment options (minimal/standard/full)
- **Dependency Management**: Automated installation of required tools
- **Performance Analytics**: Context usage tracking and efficiency reporting
- **Agent Communication**: Minimal context passing between parent and child agents
- **Platform Integration**: Dual GitHub/GitLab support with optimized API usage