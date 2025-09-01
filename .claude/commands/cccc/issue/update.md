---
allowed-tools: Bash, Read, Write, LS
---

# cccc:issue:update

Update local issue files with latest content and comments from GitLab/GitHub, and optionally post updates back to the platform.

## Usage
```
/cccc:issue:update <epic_name> <issue_id>
/cccc:issue:update <epic_name> --all
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

# Check jq is available for JSON parsing
command -v jq >/dev/null 2>&1 || {
  echo "❌ jq is required for JSON parsing. Install with:"
  echo "   macOS: brew install jq"
  echo "   Linux: apt-get install jq"
  exit 1
}

echo "✅ System requirements validated"
```

### 2. Epic and Sync State Validation
```bash
# Parse arguments
if [[ "$2" == "--all" ]]; then
  EPIC_NAME="$1"
  UPDATE_ALL=true
  ISSUE_ID=""
else
  EPIC_NAME="$1"
  ISSUE_ID="$2"
  UPDATE_ALL=false
fi

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

# Validate specific issue if provided
if [[ "$UPDATE_ALL" == false ]]; then
  # Check if issue exists in analysis
  yq ".issues.\"$ISSUE_ID\"" .cccc/epics/$EPIC_NAME/analysis.yaml >/dev/null 2>&1 || {
    echo "❌ Issue not found in analysis: $ISSUE_ID"
    echo "Available issues:"
    yq '.issues | keys | .[]' .cccc/epics/$EPIC_NAME/analysis.yaml | tr -d '"'
    exit 1
  }
  
  # Check if issue file exists
  test -f .cccc/epics/$EPIC_NAME/issues/$ISSUE_ID.md || {
    echo "❌ Issue file not found: .cccc/epics/$EPIC_NAME/issues/$ISSUE_ID.md"
    exit 1
  }
fi

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

### Execute Issue Update
```bash
# Call the dedicated issue-update script with all the complex logic
if [[ "$UPDATE_ALL" == true ]]; then
  .claude/scripts/cccc/issue-update.sh "$EPIC_NAME" --all
else
  .claude/scripts/cccc/issue-update.sh "$EPIC_NAME" "$ISSUE_ID"
fi
```

## Error Handling

If the issue update fails:
- Check error messages for specific guidance
- Ensure all preflight requirements are met
- Verify platform CLI authentication and permissions
- Check network connectivity to GitLab/GitHub
- Ensure issue numbers in sync-state.yaml are correct
- Verify JSON/YAML parsing tools are working

## Important Notes

1. **Bidirectional Sync**: Fetches content from platform and can post updates back
2. **Comment Processing**: Analyzes issue comments for actionable updates
3. **Local File Replacement**: Completely replaces local issue files (no audit trail kept locally)
4. **Platform Audit Trail**: All changes tracked in GitLab/GitHub comments
5. **AI Integration**: Can suggest improvements based on comment analysis
6. **Structured Updates**: Looks for specific comment formats like `/update status: completed`

## What Gets Updated

### Local Files Updated:
- `.cccc/epics/<epic>/issues/<issue_id>.md` - Complete issue content replacement
- `.cccc/epics/<epic>/sync-state.yaml` - Last sync timestamp and metadata

### Platform Updates (Optional):
- New comment posted with update summary
- Status updates if detected in comments
- Cross-references to related issues

## Expected Comment Processing

The system looks for structured comments like:
```
/update acceptance: ✅ Script provides validation functions
/update status: in-progress
/update estimate: 45 minutes (increased due to complexity)
```

And unstructured feedback:
```
"The validation logic should also check for empty files"
"Consider adding error codes for different failure types"
```

## Example Output

```
🔄 Updating issue 001.1 from gitlab...
  📥 Fetched issue body and 3 comments
  🔍 Processed 2 structured updates from comments
  ✏️ Updated acceptance criteria (2 items marked complete)
  📝 Replaced local issue file with latest content
  💬 Posted update summary as new comment
  
📊 Update Summary:
  - Issue: #35 - Create validation script framework
  - Comments Processed: 3 (2 structured, 1 feedback)
  - Local File Updated: ✅
  - Platform Comment Posted: ✅
  - Last Sync: 2025-08-28T12:15:30Z

🔗 View Updated Issue: https://gitlab.com/penguindepot/cccc/-/issues/35
```