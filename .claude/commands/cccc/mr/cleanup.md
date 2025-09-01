---
allowed-tools: Bash, Read, Write, LS
---

# cccc:mr:cleanup

Clean up local and remote branches after a merge request has been successfully merged. Safely removes issue branches, updates sync state, and cleans up temporary files.

## Usage
```
/cccc:mr:cleanup <epic_name> <issue_id> [--force]
```

## Parameters
- `<epic_name>`: Name of the epic containing the issue
- `<issue_id>`: Issue ID (e.g., "001.1")
- `--force`: Optional flag to force cleanup even if MR not verified as merged (dangerous)

## Rules Required

These rules must be loaded and followed:
- `.claude/rules/datetime.md` - For getting real current date/time
- `.claude/rules/github-operations.md` - For GitHub CLI operations
- `.claude/rules/gitlab-operations.md` - For GitLab CLI operations
- `.claude/rules/worktree-operations.md` - For Git worktree management

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

### 2. Epic and Issue Validation
```bash
EPIC_NAME="$1"
ISSUE_ID="$2"
FORCE_FLAG="$3"

# Verify epic exists
test -f .cccc/epics/$EPIC_NAME/epic.md || {
  echo "❌ Epic not found: $EPIC_NAME"
  echo "Run: /cccc:prd:parse $EPIC_NAME"
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

# Validate specific issue exists in analysis
yq ".issues.\"$ISSUE_ID\"" .cccc/epics/$EPIC_NAME/analysis.yaml >/dev/null 2>&1 || {
  echo "❌ Issue not found in analysis: $ISSUE_ID"
  echo "Available issues:"
  yq '.issues | keys | .[]' .cccc/epics/$EPIC_NAME/analysis.yaml | tr -d '"'
  exit 1
}

echo "✅ Epic and issue validated"
```

### 3. MR and Platform Validation
```bash
# Check if MR exists for this issue
mr_url=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_url" .cccc/epics/$EPIC_NAME/sync-state.yaml 2>/dev/null)
mr_number=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_number" .cccc/epics/$EPIC_NAME/sync-state.yaml 2>/dev/null)

if [ -z "$mr_url" ] || [ "$mr_url" = "null" ]; then
  echo "❌ No merge request found for issue $ISSUE_ID"
  echo "Nothing to clean up - no MR was created for this issue"
  exit 1
fi

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

echo "✅ MR and platform validated ($git_platform)"
```

## Instructions

### Execute MR Cleanup
```bash
# Call the dedicated mr-cleanup script
SCRIPT_OUTPUT=$(.claude/scripts/cccc/mr-cleanup.sh "$EPIC_NAME" "$ISSUE_ID" "$FORCE_FLAG")

if [ $? -ne 0 ]; then
  echo "$SCRIPT_OUTPUT"
  exit 1
fi

# Extract cleanup summary from script output
CLEANUP_SUMMARY=$(echo "$SCRIPT_OUTPUT" | grep -A 20 "CLEANUP_SUMMARY:")

echo "$SCRIPT_OUTPUT"

if echo "$SCRIPT_OUTPUT" | grep -q "CLEANUP_COMPLETED=true"; then
  echo ""
  echo "🎉 MR Cleanup Completed Successfully!"
  echo ""
  echo "$CLEANUP_SUMMARY"
  echo ""
  echo "💡 Branch and remote cleanup finished."
  echo "   Epic worktree is still available for other issues."
else
  echo ""
  echo "❌ Cleanup failed or was skipped"
  echo "Check the output above for details"
  exit 1
fi
```

## Error Handling

If the MR cleanup fails:
- Check that the MR is actually merged on the platform
- Verify you have permissions to delete remote branches
- Ensure the worktree exists and is accessible
- Check that the issue branch exists locally
- Verify platform CLI authentication and permissions
- Use `--force` flag only if you're certain it's safe

## Important Notes

1. **Safety First**: By default, verifies MR is merged before any deletion
2. **Worktree Preserved**: Epic worktree remains intact for other issues
3. **Sync State Updated**: Marks issue as cleaned up with timestamp
4. **Remote Cleanup**: Attempts to delete remote branch if it exists
5. **Force Override**: `--force` flag bypasses merge verification (use carefully)
6. **Rollback Safe**: Does not delete anything that can't be recreated

## Expected Output (Success)

```
🧹 Starting MR cleanup for issue 001.1...
  🔍 Verifying MR #2 is merged... ✅
  🌿 Switching away from issue branch... ✅
  🗑️  Deleting local branch issue/001.1... ✅
  🌐 Deleting remote branch issue/001.1... ✅
  📊 Updating sync-state with cleanup status... ✅

🎉 MR Cleanup Completed Successfully!

📋 Cleanup Summary:
  - Issue: 001.1 - Create validation script framework
  - MR: #2 (merged on 2024-08-28T10:30:00Z)
  - Local Branch: issue/001.1 (deleted)
  - Remote Branch: origin/issue/001.1 (deleted)
  - Worktree: ../epic-test-prd (preserved)
  - Status: Cleanup completed at 2024-08-28T10:35:00Z

💡 Branch and remote cleanup finished.
   Epic worktree is still available for other issues.
```

## Expected Output (Not Merged)

```
🧹 Starting MR cleanup for issue 001.1...
  🔍 Verifying MR #2 is merged... ❌

❌ MR is not merged yet
  - Status: open
  - MR: https://gitlab.com/.../merge_requests/2
  - Use --force to cleanup anyway (not recommended)

💡 Wait for MR to be merged, then run cleanup again.
```

## Expected Output (Force Mode)

```
🧹 Starting MR cleanup for issue 001.1...
  ⚠️  Force mode enabled - skipping merge verification
  🌿 Switching away from issue branch... ✅
  🗑️  Deleting local branch issue/001.1... ✅
  🌐 Deleting remote branch issue/001.1... ✅
  📊 Updating sync-state with cleanup status... ✅

⚠️  Force Cleanup Completed!
   Note: MR merge status was not verified

📋 Cleanup Summary:
  - Issue: 001.1 - Create validation script framework
  - MR: #2 (status unknown - forced cleanup)
  - Local Branch: issue/001.1 (deleted)
  - Remote Branch: origin/issue/001.1 (deleted)
  - Worktree: ../epic-test-prd (preserved)
  - Status: Force cleanup completed at 2024-08-28T10:35:00Z
```