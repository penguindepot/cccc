---
allowed-tools: Bash, Read, Write, LS
---

# cccc:epic:archive

Archive a completed epic by closing all remaining open issues, removing branches, and preserving all documentation in the .cccc_frozen directory.

## Usage
```
/cccc:epic:archive <epic_name> [--force] [--dry-run]
```

## Parameters
- `<epic_name>`: Name of the epic to archive
- `--force`: Optional flag to skip confirmation prompts (dangerous)
- `--dry-run`: Optional flag to preview what would be archived without making changes

## Rules Required

These rules must be loaded and followed:
- `.claude/rules/datetime.md` - For getting real current date/time
- `.claude/rules/github-operations.md` - For GitHub CLI operations
- `.claude/rules/gitlab-operations.md` - For GitLab CLI operations
- `.claude/rules/cccc/branch-operations.md` - For branch management and cleanup

## Preflight Checklist

### 1. System Requirements Check
```bash
# Check CCCC system initialization
test -f .cccc/cccc-config.yml || {
  echo "❌ CCCC system not initialized. Run: /cccc:init"
  exit 1
}

# Check yq is available for YAML parsing
command -v yq >/dev/null 2>&1 || {
  echo "❌ yq is required for YAML parsing. Install with:"
  echo "   macOS: brew install yq"
  echo "   Linux: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq"
  exit 1
}

echo "✅ System requirements validated"
```

### 2. Epic Validation
```bash
EPIC_NAME="$1"
FORCE_FLAG="$2"
DRY_RUN_FLAG="$3"

# Handle flags in any order
if [ "$FORCE_FLAG" = "--dry-run" ] || [ "$DRY_RUN_FLAG" = "--dry-run" ]; then
    DRY_RUN_MODE=true
fi

if [ "$FORCE_FLAG" = "--force" ] || [ "$DRY_RUN_FLAG" = "--force" ]; then
    FORCE_MODE=true
fi

# Verify epic name provided
if [ -z "$EPIC_NAME" ]; then
  echo "❌ Epic name required"
  echo "Usage: /cccc:epic:archive <epic_name> [--force] [--dry-run]"
  exit 1
fi

# Verify epic exists
test -f .cccc/epics/$EPIC_NAME/epic.md || {
  echo "❌ Epic not found: $EPIC_NAME"
  echo "Available epics:"
  ls -1 .cccc/epics/ 2>/dev/null | head -10 || echo "  (no epics found)"
  exit 1
}

# Check epic has been synced
test -f .cccc/epics/$EPIC_NAME/sync-state.yaml || {
  echo "❌ Epic not synced to platform yet."
  echo "Run: /cccc:epic:sync $EPIC_NAME"
  exit 1
}

# Check analysis exists
test -f .cccc/epics/$EPIC_NAME/analysis.yaml || {
  echo "❌ No analysis found for epic."
  echo "Run: /cccc:epic:analyze $EPIC_NAME"
  exit 1
}

echo "✅ Epic validation passed"
```

### 3. Platform Validation
```bash
# Get platform from config
git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)

# Validate appropriate CLI is available
if [ "$git_platform" = "gitlab" ]; then
  command -v glab >/dev/null 2>&1 || {
    echo "❌ GitLab CLI not found. Install: brew install glab"
    exit 1
  }
else
  command -v gh >/dev/null 2>&1 || {
    echo "❌ GitHub CLI not found. Install: brew install gh"
    exit 1
  }
fi

echo "✅ Platform CLI validated ($git_platform)"
```

## Instructions

### Execute Epic Archive
```bash
# Call the dedicated epic-archive script
if [ "$DRY_RUN_MODE" = true ]; then
    SCRIPT_OUTPUT=$(.claude/scripts/cccc/epic-archive.sh "$EPIC_NAME" "--dry-run" "$FORCE_MODE")
else
    SCRIPT_OUTPUT=$(.claude/scripts/cccc/epic-archive.sh "$EPIC_NAME" "$FORCE_FLAG" "$DRY_RUN_FLAG")
fi

if [ $? -ne 0 ]; then
  echo "$SCRIPT_OUTPUT"
  exit 1
fi

# Extract archive summary from script output
ARCHIVE_SUMMARY=$(echo "$SCRIPT_OUTPUT" | grep -A 30 "ARCHIVE_SUMMARY:")

echo "$SCRIPT_OUTPUT"

if [ "$DRY_RUN_MODE" = true ]; then
  echo ""
  echo "💡 Dry-run completed. Use /cccc:epic:archive $EPIC_NAME to execute."
elif echo "$SCRIPT_OUTPUT" | grep -q "ARCHIVE_COMPLETED=true"; then
  echo ""
  echo "🎉 Epic Archive Completed Successfully!"
  echo ""
  echo "$ARCHIVE_SUMMARY"
  echo ""
  echo "💡 Epic $EPIC_NAME has been archived to .cccc_frozen/"
  echo "   All issues and the epic have been closed on the platform."
else
  echo ""
  echo "❌ Archive failed or was cancelled"
  echo "Check the output above for details"
  exit 1
fi
```

## Error Handling

If the epic archive fails:
- Check that you have permissions to close issues on the platform
- Verify the epic and all issues exist on the platform
- Ensure platform CLI is properly authenticated
- Check that the epic branch exists and can be deleted
- Verify you have write permissions to create .cccc_frozen directory
- Use `--dry-run` to preview changes before executing
- Use `--force` flag only if you're certain it's safe

## Important Notes

1. **Destructive Operation**: Archives move files and close platform issues
2. **Platform Integration**: Closes all open issues and the epic on GitLab/GitHub
3. **Branch Cleanup**: Removes all epic and issue branches
4. **Documentation Preserved**: All files moved to .cccc_frozen for safekeeping
5. **Audit Trail**: Archive metadata tracks what was closed and when
6. **Dry-run Safe**: Use --dry-run to preview without making changes
7. **Force Override**: --force skips confirmation prompts (use carefully)

## Expected Output (Success)

```
🗄️ Starting epic archive for test-prd...
  📊 Analyzing epic status... ✅
  🔍 Found 12 issues: 10 closed, 2 open
  📝 Closing remaining open issues...
    - Closing issue #36: Create unit test framework... ✅
    - Closing issue #38: Add integration tests... ✅
  📝 Closing epic issue #34... ✅
  🌿 Removing branches... ✅
  🌐 Deleting remote branches...
    - Deleting epic/test-prd... ✅
    - Deleting issue branches... ✅
  📁 Creating archive directories... ✅
  🗄️ Moving epic files to .cccc_frozen/epics/test-prd... ✅
  📄 Moving PRD file to .cccc_frozen/prds/test-prd.md... ✅
  📊 Creating archive metadata... ✅

🎉 Epic Archive Completed Successfully!

📋 Archive Summary:
  - Epic: test-prd (issue #34)
  - Issues: 12 total (10 were already closed, 2 auto-closed)
  - PRD: Moved to .cccc_frozen/prds/test-prd.md
  - Epic Data: Moved to .cccc_frozen/epics/test-prd/
  - Branches: 13 branches deleted (1 epic + 12 issues)
  - Status: Archived at 2025-08-29T12:00:00Z

💡 Epic test-prd has been archived to .cccc_frozen/
   All issues and the epic have been closed on the platform.
```

## Expected Output (Dry-run)

```
🗄️ DRY-RUN: Epic archive preview for test-prd...
  📊 Analyzing epic status... ✅
  🔍 Found 12 issues: 10 closed, 2 open

📋 Would perform these actions:
  ❌ Close open issues:
    - Issue #36: Create unit test framework
    - Issue #38: Add integration tests
  ❌ Close epic issue #34: Epic: test-prd
  ❌ Delete 13 remote branches
  ❌ Move .cccc/epics/test-prd → .cccc_frozen/epics/test-prd
  ❌ Move .cccc/prds/test-prd.md → .cccc_frozen/prds/test-prd.md
  ❌ Create archive metadata file

📊 Summary:
  - Epic: test-prd (12 issues)
  - Open issues to close: 2
  - Files to archive: 15
  - Branches to delete: 13

💡 Dry-run completed. Use /cccc:epic:archive test-prd to execute.
```

## Expected Output (User Cancellation)

```
🗄️ Starting epic archive for test-prd...
  📊 Analyzing epic status... ✅
  🔍 Found 12 issues: 10 closed, 2 open

⚠️ This will permanently:
  - Close 2 open issues on the platform
  - Close epic issue #34 on the platform
  - Delete 13 remote branches
  - Move all files to .cccc_frozen

❓ Continue with archive? (y/N): n

❌ Archive cancelled by user
💡 Use --force to skip confirmation or --dry-run to preview
```