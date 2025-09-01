---
allowed-tools: Bash, Read, LS
---

# Validate Context

This command validates the integrity and freshness of project context documentation in `.cccc/context/`, ensuring all context files are valid, current, and complete.

## Required Rules

**IMPORTANT:** Before executing this command, read and follow:
- `.claude/rules/datetime.md` - For getting real current date/time

## Preflight Checklist

Before proceeding, complete these validation steps.
Do not bother the user with preflight checks progress ("I'm not going to ..."). Just do them and move on.

### 1. Context Directory Check
- Run: `ls -la .cccc/context/ 2>/dev/null`
- If directory doesn't exist:
  - Tell user: "❌ No context directory found. Please run /context:create first."
  - Exit gracefully
- If directory is empty:
  - Tell user: "❌ Context directory is empty. Please run /context:create to establish context."
  - Exit gracefully

### 2. Get Current DateTime
- Run: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
- Store for staleness calculations

## Instructions

### 1. File Existence Validation

Check for all expected context files:

**Required Files:**
- `progress.md` - Current project status
- `project-structure.md` - Directory organization  
- `tech-context.md` - Technical stack
- `system-patterns.md` - Architecture patterns
- `product-context.md` - Requirements and users
- `project-brief.md` - Core purpose
- `project-overview.md` - Feature summary
- `project-vision.md` - Long-term direction
- `project-style-guide.md` - Coding conventions

**Validation Steps:**
- Run: `ls -1 .cccc/context/*.md 2>/dev/null | wc -l` to count files
- For each expected file: `test -f ".cccc/context/{filename}" && echo "✅ {filename}" || echo "❌ {filename} MISSING"`
- Report missing files and their impact

### 2. File Integrity Validation

For each existing file, validate:

**Basic Integrity:**
- File is readable: `test -r ".cccc/context/{file}" && echo "readable" || echo "UNREADABLE"`
- File has content: `test -s ".cccc/context/{file}" && echo "has content" || echo "EMPTY"`
- File size reasonable: `stat -f%z ".cccc/context/{file}" 2>/dev/null` (warn if >50KB, error if >100KB)

**Frontmatter Validation:**
- Check starts with `---`: `head -1 ".cccc/context/{file}" | grep -q '^---$'`
- Check has closing `---`: `sed -n '2,10p' ".cccc/context/{file}" | grep -q '^---$'`
- Extract and validate fields:
  ```bash
  # Extract frontmatter
  sed -n '/^---$/,/^---$/p' ".cccc/context/{file}" | sed '1d;$d'
  ```
- Required fields: `created`, `last_updated`, `version`, `author`
- Date format validation: ISO 8601 format `YYYY-MM-DDTHH:MM:SSZ`

**Content Validation:**
- Minimum content length: File should have >10 lines after frontmatter
- Markdown structure: Check for at least one `#` header
- No placeholder text: Grep for `[TODO]`, `[PLACEHOLDER]`, `{content...}`

### 3. Staleness Analysis

Calculate how old each file is:

**Age Calculation:**
- Get file modification time: `stat -f%m ".cccc/context/{file}" 2>/dev/null`
- Compare with current time to get age in days
- Use `last_updated` from frontmatter if available and more recent

**Staleness Thresholds:**
- **🟢 Fresh:** ≤3 days old
- **🟡 Getting Stale:** 4-7 days old  
- **🟠 Stale:** 8-14 days old
- **🔴 Very Stale:** >14 days old

**Context-Specific Staleness:**
- `progress.md`: Should be ≤2 days (most critical)
- `tech-context.md`: Should be ≤7 days
- `project-structure.md`: Should be ≤7 days  
- `project-vision.md`: Can be ≤30 days (changes rarely)

### 4. Cross-Reference Validation

Check for broken references between files:

**Reference Patterns:**
- Look for: `See {filename}`, `Defined in {filename}`, `tech-context.md`, etc.
- Run: `grep -n "\.md" .cccc/context/*.md 2>/dev/null`
- Verify referenced files exist
- Check section references are valid

**Consistency Checks:**
- Project name consistent across files
- Technology stack matches between `tech-context.md` and `project-structure.md`
- No conflicting information between files

### 5. Git Integration Analysis

Check context alignment with git state:

**Recent Activity Check:**
- Run: `git log --since="7 days ago" --oneline | wc -l` to count recent commits
- If >5 recent commits but context >3 days old: Flag as potentially stale
- Run: `git status --short | wc -l` to count uncommitted changes
- If uncommitted changes exist but `progress.md` >1 day old: Flag for update

**Branch Alignment:**
- Run: `git branch --show-current` to get current branch
- Check if `progress.md` mentions correct branch
- Detect if on different branch than documented

### 6. Validation Report Generation

Provide comprehensive validation report:

```
🔍 Context Validation Report
Generated: {current_timestamp}

📁 File Status:
  ✅ Complete: {complete_count}/9 required files present
  ❌ Missing: {missing_files}
  ⚠️  Issues: {files_with_issues}

🏥 Health Check:
  ✅ Readable: {readable_count}/{total_count}
  ✅ Valid Frontmatter: {valid_frontmatter_count}/{total_count}
  ✅ Sufficient Content: {content_valid_count}/{total_count}

⏰ Freshness Analysis:
  🟢 Fresh (≤3 days): {fresh_count}
  🟡 Getting Stale (4-7 days): {getting_stale_count}
  🟠 Stale (8-14 days): {stale_count}
  🔴 Very Stale (>14 days): {very_stale_count}

🔗 Cross-Reference Check:
  ✅ Valid References: {valid_refs}
  ❌ Broken References: {broken_refs}

🔄 Git Alignment:
  - Recent Commits: {recent_commit_count} (last 7 days)
  - Uncommitted Changes: {uncommitted_count}
  - Current Branch: {current_branch}
  - Context-Git Sync: {sync_status}

📋 Detailed Issues:
{detailed_issue_list}

💡 Recommendations:
{specific_recommendations}

🎯 Overall Status: {PASS|WARNINGS|FAIL}
```

### 7. Specific Validation Rules

**Critical Errors (FAIL status):**
- Any required file completely missing
- Any file unreadable or empty
- Corrupted frontmatter in critical files (progress.md, tech-context.md)
- Very stale progress.md (>7 days)

**Warnings (WARNINGS status):**
- Non-critical files missing
- Stale files (>7 days)
- Broken cross-references
- Large files (>50KB)
- Git-context misalignment

**Pass Criteria:**
- All required files present and readable
- Valid frontmatter in all files
- progress.md ≤3 days old
- No critical errors

### 8. Actionable Recommendations

Based on validation results, provide specific actions:

**For Missing Files:**
- "Run /context:create to rebuild missing context"
- "Critical file {file} missing - run /context:update to regenerate"

**For Stale Context:**
- "Context is {days} days old - run /context:update to refresh"
- "progress.md is stale - update with recent work completed"

**For Integrity Issues:**
- "File {file} has corrupted frontmatter - manual fix required"
- "File {file} is unusually large ({size}KB) - consider splitting"

**For Git Misalignment:**
- "Recent commits but stale context - run /context:update"
- "Branch changed since last context update - verify accuracy"

## Error Handling

**Permission Issues:**
- "❌ Cannot read context files - check permissions"
- List specific files with permission problems

**Corrupted Files:**
- "⚠️ File {file} appears corrupted - validation skipped"
- Suggest regeneration or manual repair

**System Issues:**
- "❌ Cannot access git information - git status unknown"
- Continue validation without git integration

## Performance Optimization

For large context directories:
- Process files in parallel when possible
- Show progress: "Validating context files... {current}/{total}"
- Skip validation of very large files with warning
- Cache repeated calculations (file stats, git info)

## Important Notes

- **Always use real datetime** from system clock for staleness calculations
- **Fail fast on critical errors** but continue for warnings
- **Provide actionable recommendations** - don't just report problems
- **Consider git state** - context should align with development activity
- **Validate cross-references** - broken links reduce context effectiveness
- **Check both content and metadata** - both must be valid for useful context

$ARGUMENTS