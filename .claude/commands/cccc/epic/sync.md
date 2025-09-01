---
allowed-tools: Bash, Read, Write, LS
---

# cccc:epic:sync

Sync epic and individual issues from YAML analysis to configured git platform (GitHub/GitLab) with pre-calculated cross-references.

## Usage
```
/cccc:epic:sync <epic_name>
```

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

### 2. Epic and Analysis Validation
```bash
# Verify epic exists
test -f .cccc/epics/$ARGUMENTS/epic.md || {
  echo "❌ Epic not found. Run: /cccc:prd:parse $ARGUMENTS"
  exit 1
}

# Check for analysis.yaml from analyze command
test -f .cccc/epics/$ARGUMENTS/analysis.yaml || {
  echo "❌ No analysis found. Run: /cccc:epic:analyze $ARGUMENTS"
  exit 1
}

# Validate analysis has issues
issue_count=$(yq '.stats.total_issues' .cccc/epics/$ARGUMENTS/analysis.yaml)
[ "$issue_count" -eq 0 ] 2>/dev/null && {
  echo "❌ No issues found in analysis"
  exit 1
}

echo "✅ Epic and analysis validated ($issue_count issues)"
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

### Execute Epic Sync Script
```bash
# Call the dedicated sync script with all the complex logic
.claude/scripts/cccc/epic-sync.sh "$ARGUMENTS"
```

## Error Handling

If the sync script fails:
- Check error messages for specific guidance
- Ensure all preflight requirements are met
- Verify epic analysis is complete and valid
- Check platform CLI authentication and permissions

## Important Notes

1. **yq Requirement**: This command requires `yq` for reliable YAML parsing
2. **Script-Based**: Complex sync logic is in `.claude/scripts/cccc/epic-sync.sh`
3. **Platform Agnostic**: Works with both GitLab and GitHub
4. **Cross-References**: All issue dependencies are pre-calculated and included
5. **Atomic Operations**: Either full success or clean failure state
6. **Development Ready**: Creates worktree for epic development