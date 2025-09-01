---
allowed-tools: Bash, Read, Write, LS
---

# cccc:epic:update-status

Update issue statuses in sync-state.yaml by querying current states from GitLab/GitHub.

## Usage
```
/cccc:epic:update-status <epic_name>
```

## Rules Required

These rules must be loaded and followed:
- `.claude/rules/datetime.md` - For getting real current date/time
- `.claude/rules/github-operations.md` - For GitHub CLI operations
- `.claude/rules/gitlab-operations.md` - For GitLab CLI operations

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

### 2. Epic and Sync State Validation
```bash
# Verify epic exists
test -f .cccc/epics/$ARGUMENTS/epic.md || {
  echo "❌ Epic not found: $ARGUMENTS"
  echo "Run: /cccc:prd:parse $ARGUMENTS"
  exit 1
}

# Check epic has been synced
test -f .cccc/epics/$ARGUMENTS/sync-state.yaml || {
  echo "❌ Epic not synced to platform yet."
  echo "Run: /cccc:epic:sync $ARGUMENTS"
  exit 1
}

echo "✅ Epic and sync state validated"
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

### Execute Status Update
```bash
# Call the dedicated update-status script with all the complex logic
.claude/scripts/cccc/epic-update-status.sh "$ARGUMENTS"
```

## Error Handling

If the status update fails:
- Check error messages for specific guidance
- Ensure all preflight requirements are met
- Verify platform CLI authentication and permissions
- Check network connectivity to GitLab/GitHub
- Ensure issue numbers in sync-state.yaml are correct

## Important Notes

1. **Real-Time Sync**: Queries GitLab/GitHub API for current issue states
2. **Status Tracking**: Updates sync-state.yaml with current statuses
3. **Completion Timestamps**: Records when issues were closed
4. **Platform Agnostic**: Works with both GitLab and GitHub
5. **Rate Limiting**: Handles API rate limits gracefully
6. **Cached Results**: Stores results to minimize repeated API calls

## Status Fields Updated

The command updates these fields in sync-state.yaml:

```yaml
issue_mappings:
  001.1:
    number: 35
    url: https://gitlab.com/.../issues/35
    title: "Create validation script framework"
    status: "opened"           # NEW: Current issue state
    completed_at: null         # NEW: Completion timestamp (if closed)

last_status_update: 2025-08-28T04:45:29Z  # NEW: When status was last checked
```

## Example Output

```
🔄 Updating issue statuses from gitlab...
  ✅ #35: opened
  ✅ #36: opened  
  ✅ #37: closed (completed: 2025-08-28T10:30:15Z)
  ✅ #38: opened
  ✅ #39: closed (completed: 2025-08-28T11:45:22Z)
  ⚠️ #40: API error, using cached status: opened
  
📊 Status Summary:
  - Total Issues: 12
  - Completed: 2 (17%)
  - In Progress: 10 (83%)
  - Last Updated: 2025-08-28T12:15:30Z

✅ Issue statuses updated successfully
```