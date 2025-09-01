---
allowed-tools: Bash, Read, Write, LS
---

# cccc:issue:mr

Create a merge request (GitLab) or pull request (GitHub) for a specific issue with proper branch rebasing and platform integration.

## Usage
```
/cccc:issue:mr <epic_name> <issue_id>
```

## Rules Required

These rules must be loaded and followed:
- `.claude/rules/datetime.md` - For getting real current date/time
- `.claude/rules/github-operations.md` - For GitHub CLI operations
- `.claude/rules/gitlab-operations.md` - For GitLab CLI operations
- `.claude/rules/worktree-operations.md` - For Git worktree management and proper rebasing

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

### 3. Platform CLI Validation
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

### Execute Issue MR Creation
```bash
# Call the dedicated issue-mr script with all the complex logic
.claude/scripts/cccc/issue-mr.sh "$EPIC_NAME" "$ISSUE_ID"
```

## Error Handling

If the MR creation fails:
- Check error messages for specific guidance
- Ensure all preflight requirements are met
- Verify platform CLI authentication and permissions
- Check network connectivity to GitLab/GitHub
- Ensure epic worktree exists and is accessible
- Verify issue branches can be rebased cleanly

## Important Notes

1. **Worktree Integration**: Works with existing epic worktrees created by `/cccc:epic:sync`
2. **Proper Rebasing**: Follows worktree-operations rules - rebases epic on main, then issue on epic
3. **Platform Support**: Supports both GitLab (MR) and GitHub (PR) automatically
4. **State Tracking**: Updates sync-state.yaml with MR/PR information
5. **Branch Management**: Creates issue branches following `issue/{issue_id}` pattern

## Expected Output

```
🔗 Creating MR for Issue 001.1...
✅ Epic worktree found: ../epic-test-prd
🔄 Rebasing epic branch on main...
🌿 Creating/updating issue branch: issue/001.1
🔄 Rebasing issue branch on epic...
📤 Pushing issue branch to remote...
🚀 Creating GitLab MR...
✅ MR #47 created successfully!

🎉 GitLab MR Created Successfully!
🔗 MR: https://gitlab.com/jeunesse.paulien/cccc/-/merge_requests/47
   • Number: #47
   • Title: Issue #35: Create validation script framework
   • Source: issue/001.1
   • Target: epic/test-prd

📁 Updated: .cccc/epics/test-prd/sync-state.yaml
🔗 Next Steps:
   • Review and provide feedback on the MR
   • Merge when ready
   • Continue work in epic worktree: ../epic-test-prd
```