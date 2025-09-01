---
created: 2025-08-27T15:01:27Z
last_updated: 2025-09-01T14:25:22Z
version: 3.0
author: Claude Code CC System
---

# System Patterns

## Architectural Patterns

### Branch-Based Development Pattern (New Architecture)
**Major System Evolution**: Transitioned from complex worktree-based to streamlined branch-based development:
- **Direct Branch Operations**: Issues implement directly on branches without worktree complexity
- **Simplified Workflow**: issue:start command replaces mr:start for immediate branch-based development
- **Reduced Overhead**: Eliminated worktree orchestration while maintaining all core functionality
- **Enhanced Maintainability**: Simpler codebase with branch-operations.md replacing worktree-operations.md
- **Benefits**: Faster development cycle, reduced system complexity, easier maintenance

### Command-Based Architecture
The system implements a command pattern where each operation is:
- Self-contained with validation and execution logic
- Defined in markdown with structured frontmatter
- Tool-permission aware for security
- Composable with other commands

### Script Separation Pattern (New)
Complex commands now follow a separation pattern:
- **Command Files**: Handle validation, prerequisites, and user interface
- **Script Files**: Contain complex logic and heavy computation (.claude/scripts/cccc/)
- **Benefits**: Cleaner command structure, better maintainability, reusable logic
- **Example**: epic-sync.sh handles all sync logic while sync.md handles validation

### Validation-First Pattern
Every command follows strict validation:
1. **Preflight Checks**: Validate prerequisites before execution
2. **Input Validation**: Ensure parameters meet requirements
3. **State Validation**: Verify system state is appropriate
4. **Output Validation**: Confirm successful completion

### Hybrid Storage Architecture (New)
Major architectural shift from pure markdown to hybrid approach:
- **Human-Facing**: Markdown for epics, PRDs, and documentation
- **Machine-Readable**: YAML for metadata, relationships, and state
- **Content Separation**: Issue bodies in clean markdown files, metadata in YAML
- **Benefits**: 30-40% token reduction, eliminates parsing issues, maintains human readability

### Frontmatter Metadata Pattern
All context and PRD files include:
```yaml
---
created: ISO 8601 timestamp
last_updated: ISO 8601 timestamp
version: Semantic version
author: System identifier
---
```

## Design Decisions

### YAML-Driven Issue Management (New Architecture)
- **Structure**: analysis.yaml contains all issue metadata and relationships
- **Content Files**: Clean markdown files for issue bodies (issues/001.1.md)
- **State Tracking**: sync-state.yaml for complete sync metadata
- **Benefits**: Direct data access, no parsing timeouts, stable filenames
- **Pre-calculated Dependencies**: All cross-references computed before issue creation

### Markdown as Configuration
- **Rationale**: Human-readable, version-controllable, IDE-friendly
- **Benefits**: No compilation, easy editing, built-in documentation
- **Trade-offs**: Limited type safety, requires parsing (now minimized with YAML hybrid)

### File-Based State Management
- **Approach**: Separate files for different context aspects
- **Benefits**: Granular updates, parallel processing, clear separation
- **Structure**: 9 specialized context files for comprehensive coverage

### Sequential Issue Creation Pattern (New)
- **Predictable Numbering**: Issues get numbers epic+1, epic+2, etc.
- **Pre-formatted Cross-References**: All dependencies resolved before creation
- **Stable Content**: Issue body files never rename or move
- **Complete State**: All mappings preserved in sync-state.yaml
- **Benefits**: Eliminates post-creation updates, reliable cross-references, atomic operations

### Dependency-Aware Workflow Management (New)
- **Real-Time Status**: Query GitLab/GitHub APIs for current issue states
- **Dependency Resolution**: Analyze analysis.yaml to determine blocked vs ready issues
- **Conflict Detection**: Warn about issues that shouldn't be worked on in parallel
- **Phase Prioritization**: Sort recommendations by phase and estimated effort
- **Progress Tracking**: Track completion timestamps and celebrate milestones
- **Benefits**: Always know which issues are actionable, prevent workflow conflicts

### API Integration Pattern
- **Multi-Platform**: Support both GitLab (glab) and GitHub (gh) CLI tools
- **Error Handling**: Graceful fallbacks when APIs are unavailable or rate-limited
- **Caching Strategy**: Store results in sync-state.yaml to minimize repeated calls
- **Backup Management**: Automatic backup with cleanup to prevent file corruption
- **Status Synchronization**: Keep local state in sync with remote platform state
- **Benefits**: Reliable real-time data with fault tolerance

### Bidirectional Sync Pattern
- **Comment Processing**: Parse structured commands (/update) and feedback from platform
- **Content Synchronization**: Replace local files with latest platform content
- **Collaborative Updates**: Post processing summaries back as platform comments
- **Author Attribution**: Track comment authors and timestamps for feedback history
- **Local-First Workflow**: Maintain local development focus with platform collaboration
- **Audit Trail**: Preserve complete history on platform while keeping local files current
- **Benefits**: Seamless collaboration without losing local development efficiency

### Complete Development Workflow Pattern (Updated for Branch-Based)
- **Branch-Based Implementation**: Direct issue implementation on branches without worktree complexity
- **Implementation Launch**: cccc:issue:start creates branch and launches specialized development agents
- **State Tracking**: Record work initiation timestamp and implementation progress
- **Agent Integration**: Use specialized sub-agents for focused development work
- **Workflow Sequencing**: Simplified sequence - epic:sync → issue:start → development → mr workflow
- **Benefits**: Streamlined development process with reduced complexity and faster iteration

### Git-Aware Operations
- **Integration**: Commands check git status for context freshness
- **Validation**: Detect uncommitted changes and branch switches
- **History**: Leverage git log for progress tracking

## Data Flow Patterns

### Context Lifecycle Flow
```
Create → Prime → Work → Update → Validate → Close → Prime (new session)
```
**Enhanced with Cleanup**: Added context:close command for clean session termination with state summary and preparation for next session.

### PRD Processing Flow
```
Discovery → Documentation → Parsing → Epic Generation → Task Decomposition → Issue Analysis → Implementation
```

### Epic Analysis Flow
```
Read Epic → Analyze All Tasks → Decompose Issues → Dependency Analysis → Phase Planning → Individual Files → Summary
```

### Epic Sync Flow
```
Validate Prerequisites → Create Epic → Map Issues → Sync Individual Issues → Update Cross-References → Create State → Setup Worktree
```
**Critical Fix Applied**: Eliminated comment lines in temp mapping files to prevent parsing errors during sync operations.

### Intelligent Issue Management Flow (New)
```
Update Status → Analyze Dependencies → Check Conflicts → Calculate Ready Issues → Prioritize by Phase → Show Recommendations
```
**Key Features**: Dependency-aware prioritization, conflict detection, real-time API integration, and progress tracking.

### Issue Status Update Flow
```
Query API → Compare States → Update sync-state.yaml → Track Completions → Generate Progress → Cleanup Backups
```
**API Integration**: Supports both GitLab and GitHub with graceful error handling and backup management.

### Implementation Launch Flow (Updated for Branch-Based)
```
Validate Issue → Check Dependencies → Create Branch → Setup Environment → Launch Agent → Update Work State → Provide Guidance
```
**Key Features**: Complete prerequisite validation, dependency satisfaction checking, direct branch creation, simplified environment setup, agent-based implementation support.

### MR Review Feedback Flow (Completed)
```
MR Update: Fetch MR Comments → Parse /fix Commands → Categorize Feedback → Store in sync-state → Report Summary
MR Fix: Check Feedback → Prepare Fix Prompt → Launch Agent → Apply Fixes → Push Changes → Post Confirmation → Update State
```
**Production Ready**: Complete implementation with structured /fix command parsing, graceful exit when no fixes needed, automated agent-based implementation, single confirmation comment posting, and comprehensive audit trail preservation in sync-state.

### Bidirectional Issue Sync Flow (New)
```
Fetch Issue + Comments → Process Structured Updates → Update Local File → Generate Summary → Post Comment → Update Sync State
```
**Key Features**: Structured comment parsing (/update commands), feedback attribution, collaborative refinement, platform audit trails.

### Merge Request Workflow Pattern (Updated for Branch-Based)
```
Validate Issue → Create/Switch Branch → Rebase on Main → Implement Changes → Push Branch → Create MR/PR → Update State
```
**Key Features**: Simplified branch-based workflow, direct main branch integration, force-with-lease safety, MR tracking in sync-state.yaml, platform integration.

### Branch Hierarchy Maintenance Pattern (Enhanced)
```
Discover Worktrees → Fetch Updates → Pull Epic Remote State → Phase 1: Rebase Epics on Main → Safety Check → Push Epics → Phase 2: Rebase Issues on Epics → Push Issues → Report Status
```
**Key Features**: **Pull-before-rebase safety** (NEW), commit loss prevention with safety checks, automated branch maintenance, conflict detection and reporting, selective targeting, dry-run capability, comprehensive statistics.

### Implementation Launch Pattern (Updated for Branch-Based)
```
Validate Issue → Check Dependencies → Create Branch → Setup Environment → Launch Agent → Track Work Start → Provide Implementation Guidance
```
**Key Features**: Issue prerequisite validation, dependency satisfaction checking, direct branch creation, simplified environment setup, agent-based development, work tracking.

### Command Execution Flow
```
User Input → Preflight → Validation → Execution → Verification → Summary
```

## Error Handling Patterns

### Graceful Degradation
- Continue with partial context if some files missing
- Warn but proceed for non-critical failures
- Fail fast only for critical errors

### Error Recovery Strategy
1. Identify error type and severity
2. Attempt automatic recovery if possible
3. Provide specific remediation steps
4. Never leave corrupted state

### User Feedback Pattern
- Clear error messages with actionable solutions
- Progress indicators for long operations
- Comprehensive summaries after completion
- Warnings for potential issues

## Consistency Patterns

### Naming Conventions
- **Commands**: Verb-noun format (e.g., `create`, `update`, `validate`)
- **Files**: Descriptive kebab-case
- **Variables**: Contextual placeholders (e.g., `$ARGUMENTS`)

### Timestamp Standardization
- Always use ISO 8601 format
- UTC timezone for consistency
- Real system time via `date -u +"%Y-%m-%dT%H:%M:%SZ"`

### Status Reporting
- Emoji indicators for status (✅ ❌ ⚠️ 🟢 🟡 🟠 🔴)
- Structured summaries with statistics
- Hierarchical information presentation

## Integration Patterns

### Sub-Agent Delegation
- File-analyzer for large file processing
- Code-analyzer for code investigation
- Test-runner for test execution
- Keeps main conversation context clean

### Cross-Reference Management
- Files can reference other context files
- Validation ensures references remain valid
- Enables modular documentation

### Permission Boundaries
- Each command declares required tools
- Restricted tool access for security
- Explicit permission model in frontmatter

### Multi-Platform Support
- Platform detection via configuration and remotes
- Abstracted CLI operations (gh/glab) with consistent interfaces
- Shared rule patterns for common operations
- Error handling specific to each platform's limitations

## Scalability Patterns

### Modular Command Structure
- Commands organized by namespace
- Independent execution paths
- Shared rules for common functionality

### Incremental Updates
- Only update changed sections
- Preserve timestamps for unchanged content
- Surgical modifications over regeneration

### Parallel Processing
- Multiple file operations in parallel
- Batch validation for efficiency
- Progress tracking for long operations