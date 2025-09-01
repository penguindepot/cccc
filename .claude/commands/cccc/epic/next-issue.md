---
allowed-tools: Bash, Read, Write, LS
---

# cccc:epic:next-issue

Determine which issues can be worked on next based on their dependencies and current status in GitLab/GitHub.

## Usage
```
/cccc:epic:next-issue <epic_name>
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

# Check analysis exists
test -f .cccc/epics/$ARGUMENTS/analysis.yaml || {
  echo "❌ No analysis found for epic."
  echo "Run: /cccc:epic:analyze $ARGUMENTS"
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

### Execute Next Issue Analysis
```bash
# Call the dedicated next-issue script with all the complex logic
.claude/scripts/cccc/epic-next-issue.sh "$ARGUMENTS"
```

## Error Handling

If the analysis fails:
- Check error messages for specific guidance
- Ensure all preflight requirements are met
- Verify epic has been synced and analyzed
- Check platform CLI authentication and permissions
- Consider running `/cccc:epic:update-status $ARGUMENTS` to refresh issue states

## Important Notes

1. **Real-Time Status**: Queries GitLab/GitHub for current issue states
2. **Dependency Analysis**: Considers all dependencies and conflicts from analysis.yaml
3. **Phase Awareness**: Prioritizes issues based on phase ordering
4. **Conflict Detection**: Warns about issues that shouldn't be worked on in parallel
5. **Progress Tracking**: Shows overall epic completion progress
6. **Smart Recommendations**: Sorts and prioritizes actionable issues

## Example Output

```
🎯 Next Issues for Epic: test-prd

✅ Ready to Start (no blockers):
  #35 - Create validation script framework (Phase 1, ~25min)
  #37 - Standardize PRD template structure (Phase 1, ~30min)
  
⏸️ Blocked (waiting on dependencies):
  #36 - Create workflow test runner
    └─ Waiting on: #35 (opened)
  #38 - Improve new command validation logic  
    └─ Waiting on: #37 (opened)
    
⚠️ Conflicts to Consider:
  #38 conflicts with #41, #43 (avoid parallel work)
  
📊 Progress: 0/12 issues completed (0%)
🔗 Epic: https://gitlab.com/jeunesse.paulien/cccc/-/issues/34
```