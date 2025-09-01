---
allowed-tools: Bash, Read, Write, LS
---

# Epic Analyze

Analyze an entire epic to decompose all tasks into parallel GitHub issues with implementation sketches.

## Usage
```
/cccc:epic:analyze <epic_name>
```

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

1. **Validate epic exists:**
   - Check if `.cccc/epics/$ARGUMENTS/` directory exists
   - If not found, tell user: "❌ Epic not found: $ARGUMENTS. Available epics:" and list directories in .cccc/epics/
   - Stop execution if epic doesn't exist

2. **Scan for task files:**
   - Count numbered task files (001.md, 002.md, etc.) in `.cccc/epics/$ARGUMENTS/`
   - If no task files found, tell user: "❌ No tasks found in epic: $ARGUMENTS. Run: /cccc:epic:decompose $ARGUMENTS first"
   - Report: "📋 Found {count} tasks to analyze: {list task numbers}"

3. **Check for existing analysis:**
   - Check if `.cccc/epics/$ARGUMENTS/$ARGUMENTS-epic-analysis.md` already exists
   - If it exists, ask user: "⚠️ Epic analysis already exists. Overwrite? (yes/no)"
   - Only proceed with explicit 'yes' confirmation
   - If user says no, suggest: "View existing analysis with: Read .cccc/epics/$ARGUMENTS/$ARGUMENTS-epic-analysis.md"

4. **Validate task file integrity:**
   - For each task file, verify it has valid frontmatter with: name, status, created
   - Report any files with malformed frontmatter: "⚠️ Task {number} has invalid frontmatter"
   - Continue with valid tasks, note issues in final analysis

## Instructions

You are analyzing the entire epic: **$ARGUMENTS** to create an optimized parallel execution plan.

### 1. Read Epic Context

Load the epic overview:
- Read `.cccc/epics/$ARGUMENTS/epic.md` to understand the overall goals
- Extract key information: name, status, overview, technical approach
- Note the total estimated effort and current progress

### 2. Analyze All Tasks

For each task file (001.md, 002.md, etc.):

**Parse Task Details:**
- Extract task name, description, acceptance criteria
- Identify technical details and file patterns mentioned
- Note dependencies (depends_on field) and conflicts (conflicts_with field)
- Parse effort estimates (size and hours)

**Identify Work Categories:**
- **Script Layer**: .claude/scripts/cccc/ files - validation, utilities, common functions
- **Command Layer**: .claude/commands/cccc/ files - command modifications and new commands  
- **Template Layer**: Templates, PRD structures, documentation templates
- **Integration Layer**: Error handling, cleanup mechanisms, shared libraries
- **Test Layer**: Validation tests, integration tests, test runners
- **Documentation Layer**: User guides, troubleshooting, command documentation

**File Impact Analysis:**
- List all files each task will create or modify
- Identify shared files that multiple tasks will touch
- Assess conflict risk (High/Medium/Low) based on file overlap

### 3. Decompose Tasks into Issues

For each task, create 2-3 focused issues following these constraints:

**Issue Sizing Rules:**
- Maximum 3 files modified per issue
- Maximum 500 LOC per issue
- Each issue should be completable in 15-45 minutes
- Issues should have clear, testable acceptance criteria

**Issue Structure:**
```
Issue #X.Y: {Clear action-oriented title}
- Files: {list of 1-3 specific files}
- LOC: ~{estimated lines}
- Dependencies: {list issue numbers}
- Implementation: {2-3 line summary with key code elements}
```

**Naming Convention:**
- Use format: Issue #{task}.{sub}: {Title}
- Example: Issue #001.1: Create validation script framework
- Example: Issue #002.2: Update PRD creation command

### 4. Create Dependency Graph

Build comprehensive dependency relationships:

**Cross-Task Dependencies:**
- Issue from Task 003 depends on Issue from Task 002 (parser needs template)
- Issue from Task 004 depends on Issues from Task 001 and 003 (error handling needs validation)
- Issue from Task 005 depends on completion of Tasks 002 and 004 (docs need final implementation)
- Issue from Task 006 depends on all other tasks (integration tests need everything)

**File-Level Conflicts:**
- Identify issues that modify the same files
- Mark these as "sequential required" or "coordination needed"
- Suggest resolution strategies (separate commits, communication protocols)

**Critical Path Analysis:**
- Identify the longest dependency chain
- Calculate minimum wall time with infinite parallelization
- Find bottlenecks that limit parallel execution

### 5. Generate Parallel Execution Phases

Group issues into execution phases:

**Phase Criteria:**
- Issues in same phase have no dependencies on each other
- All dependencies of phase N must be completed in phases 1 through N-1
- Optimize for maximum parallelization while respecting dependencies

**Phase Structure:**
```
Phase 1 (Start Immediately):
  - Issue #001.1: Create validation framework (30 min)
  - Issue #002.1: Standardize PRD template (20 min)
  Parallel time: 30 minutes

Phase 2 (After Phase 1):
  - Issue #001.2: Add frontmatter validation (25 min)
  - Issue #002.2: Update PRD command (15 min)
  - Issue #003.1: Create YAML parser (35 min)
  Parallel time: 35 minutes

[Continue for all phases...]
```

### 6. Calculate Time Savings

**Sequential Execution:**
- Sum all individual issue times
- Total: {sum of all issue hours}

**Parallel Execution:**
- Sum the longest phase times
- Total: {sum of phase durations}

**Efficiency Gain:**
- Parallelization factor: {sequential_time / parallel_time}x
- Time saved: {sequential_time - parallel_time} hours ({percentage}% reduction)

### 7. Create YAML-Based Analysis Structure

Get current datetime: `date -u +"%Y-%m-%dT%H:%M:%SZ"`

Create analysis.yaml with all metadata and issues directory with body files:

**Directory Setup:**
```bash
mkdir -p ".cccc/epics/$ARGUMENTS/issues"
```

**Create analysis.yaml file:**
```yaml
# .cccc/epics/$ARGUMENTS/analysis.yaml
epic: $ARGUMENTS
analyzed: {current_datetime}
stats:
  total_issues: {count}
  phases: {phase_count}
  sequential_hours: {sequential_total}
  parallel_hours: {parallel_total}
  speedup: {parallelization_factor}
  ready_to_start: {phase1_issue_count}

# Phase execution order
phases:
  1: [001.1, 002.1]
  2: [003.1, 001.2, 002.2]
  3: [003.2, 001.3, 004.1]
  # ... continue for all phases

# All issue metadata
issues:
  001.1:
    title: "{Clear action-oriented title}"
    task: 1
    phase: 1
    estimate_minutes: {time}
    depends_on: []
    conflicts_with: []
    files_modified: {count}
    max_loc: {lines}
    body_file: issues/001.1.md
  001.2:
    title: "{title}"
    task: 1
    phase: 2
    estimate_minutes: {time}
    depends_on: [002.1]
    conflicts_with: []
    files_modified: {count}
    max_loc: {lines}
    body_file: issues/001.2.md
  # ... continue for all issues
```

**Issue Body File Format (no frontmatter):**
Each issue gets a clean markdown file in issues/ directory:
```markdown
# Issue #{task}.{sub}: {title}

## Overview
{1-2 sentence description of what this issue accomplishes}

## Files to Modify
1. `{file_path1}` ({new|modify})
2. `{file_path2}` ({new|modify})
3. `{file_path3}` ({new|modify})

## Implementation Sketch
{Detailed code examples and implementation approach}

## Acceptance Criteria
- [ ] {Specific testable criterion 1}
- [ ] {Specific testable criterion 2}
- [ ] {Specific testable criterion 3}

## Dependencies
{List what must be completed before this issue can start}
- Issue #{dep1}: {reason}
- Issue #{dep2}: {reason}

## Definition of Done
- [ ] Code implemented according to implementation sketch
- [ ] All acceptance criteria met
- [ ] Code follows CCCC patterns and standards
- [ ] Changes tested and validated
- [ ] Ready for dependent issues to begin
```

**Summary File Generation (from YAML):**
Generate human-readable summary from analysis.yaml data:

```bash
# Generate summary.md from analysis.yaml using the YAML data
# This summary is for human reading and can be regenerated anytime
```

The summary.md will be generated from the YAML using this template structure:

```markdown
# Epic Analysis Summary: $ARGUMENTS

## Quick Stats  
- **Total Issues**: {stats.total_issues} issues decomposed from {task_count} tasks
- **Parallel Execution**: {stats.parallel_hours}h (vs {stats.sequential_hours}h sequential)  
- **Time Savings**: {stats.speedup}x speedup, {percentage}% reduction
- **Ready to Start**: {stats.ready_to_start} issues can begin immediately

## Issue Status Overview
- 🟢 Ready (Phase 1): {phase1_count} issues
- 🟡 Blocked (Phases 2+): {blocked_count} issues  
- 🔴 High Conflict Risk: {high_risk_count} issues

## Execution Phases

### Phase 1 (Start Immediately - No Dependencies)
{For each issue in phases.1:}
- `{issue_id}.md` - {issues[issue_id].title} ({issues[issue_id].estimate_minutes} min)

**Phase Duration**: {max_phase1_time} minutes

### Phase 2 (After Phase 1)
{For each issue in phases.2:}  
- `{issue_id}.md` - {issues[issue_id].title} ({issues[issue_id].estimate_minutes} min) - depends on {issues[issue_id].depends_on}

**Phase Duration**: {max_phase2_time} minutes

{Continue for all phases}

## Next Actions
- [ ] Run /cccc:epic:sync {epic_name} to create issues on GitLab/GitHub
- [ ] Assign Phase 1 issues to available developers
- [ ] Begin implementation immediately
```

### 8. Validation and Quality Checks

Before finalizing the analysis:
- Ensure all task work is covered by issues
- Verify dependency logic is sound (no circular dependencies)
- Confirm LOC estimates are reasonable
- Check that file patterns don't unnecessarily overlap
- Validate that parallelization strategy is practical

### 9. Output Summary

After creating analysis.yaml, issue body files, and summary.md, provide this summary:

```
✅ Epic Analysis Complete: $ARGUMENTS

📊 Analysis Results:
  • Tasks Analyzed: {task_count}
  • Issues Generated: {total_issues}
  • Sequential Time: {seq_hours} hours
  • Parallel Time: {par_hours} hours
  • Speedup Factor: {factor}x

📁 Created Analysis Structure:
  .cccc/epics/$ARGUMENTS/analysis.yaml        # All metadata and relationships
  .cccc/epics/$ARGUMENTS/issues/summary.md    # Human-readable summary
  .cccc/epics/$ARGUMENTS/issues/001.1.md     # Issue body content
  .cccc/epics/$ARGUMENTS/issues/001.2.md     # Issue body content
  {List all issue body files created}

🚀 Execution Strategy:
  Phase 1: {phase1_count} issues ready to start immediately
  Phase 2: {phase2_count} issues after Phase 1
  {Continue for key phases}

⚠️ Risk Assessment:
  🔴 High Risk: {high_risk_count} file conflicts requiring sequential execution
  🟡 Medium Risk: {med_risk_count} related file modifications
  🟢 Low Risk: {low_risk_count} independent issues

💡 Next Steps:
  1. Run: /cccc:epic:sync $ARGUMENTS
  2. This will create GitLab/GitHub issues with proper cross-references
  3. Issues will be numbered sequentially and ready for development
```

## Error Recovery

If any step fails:
- If task files are malformed, continue with valid tasks and note issues
- If analysis file creation fails, ensure directory exists and has write permissions
- Never leave the epic analysis in an incomplete state
- Provide clear guidance on how to fix issues and retry

## Implementation Notes

The analysis should be practical and actionable:
- Focus on realistic parallel execution, not theoretical maximum
- Account for coordination overhead in time estimates  
- Prefer clear separation over maximum parallelization
- Consider developer expertise when suggesting parallel work
- Provide concrete implementation guidance, not abstract analysis