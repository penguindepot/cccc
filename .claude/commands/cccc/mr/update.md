---
allowed-tools: Bash, Read, Write, LS
---

# cccc:mr:update

Update local sync-state with latest merge request comments and feedback from GitLab/GitHub.

## Usage
```
/cccc:mr:update <epic_name> <issue_id>
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

# Check if issue file exists
test -f .cccc/epics/$EPIC_NAME/issues/$ISSUE_ID.md || {
  echo "❌ Issue file not found: .cccc/epics/$EPIC_NAME/issues/$ISSUE_ID.md"
  exit 1
}

echo "✅ Epic and issue validated"
```

### 3. MR Existence Check
```bash
# Check if MR exists for this issue
mr_url=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_url" .cccc/epics/$EPIC_NAME/sync-state.yaml 2>/dev/null | tr -d '"')
mr_number=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_number" .cccc/epics/$EPIC_NAME/sync-state.yaml 2>/dev/null)

if [ -z "$mr_url" ] || [ "$mr_url" = "null" ]; then
  echo "❌ No merge request found for issue $ISSUE_ID"
  echo "Create MR first: /cccc:issue:mr $EPIC_NAME $ISSUE_ID"
  exit 1
fi

echo "✅ MR exists: $mr_url (#$mr_number)"
```

### 4. Platform CLI Validation
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

### Execute MR Update
```bash
# Call the dedicated mr-update script with all the complex logic
.claude/scripts/cccc/mr-update.sh "$EPIC_NAME" "$ISSUE_ID"
```

## Error Handling

If the MR update fails:
- Check error messages for specific guidance
- Ensure all preflight requirements are met
- Verify platform CLI authentication and permissions
- Check network connectivity to GitLab/GitHub
- Ensure MR numbers in sync-state.yaml are correct
- Verify JSON/YAML parsing tools are working

## Important Notes

1. **MR Comment Sync**: Fetches all discussions/comments from MR and parses for actionable feedback
2. **Structured Commands**: Looks for `/fix` commands in comments (similar to `/update` for issues)
3. **Feedback Categorization**: Separates structured fixes from general feedback
4. **Local Storage**: Updates sync-state.yaml with categorized feedback for mr:fix command
5. **No Platform Changes**: This command only fetches and stores, doesn't post anything back

## What Gets Updated

### Local Files Updated:
- `.cccc/epics/<epic>/sync-state.yaml` - MR feedback data added under issue_mappings.<issue_id>.mr_feedback

### Feedback Structure Added:
```yaml
mr_feedback:
  last_fetched: "2025-08-28T10:00:00Z"
  comments:
    - author: "reviewer1"
      date: "2025-08-28T09:30:00Z" 
      body: "Please add error handling for empty files"
      type: "feedback"
    - author: "reviewer2"
      date: "2025-08-28T09:45:00Z"
      body: "/fix validation: Check for null values"
      type: "structured"
  has_actionable: true
  fix_required: true
  actionable_count: 1
  feedback_count: 1
```

## Expected Comment Processing

The system looks for structured fix commands like:
```
/fix validation: Add null checks
/fix error-handling: Improve error messages
/fix performance: Optimize loop in calculateTotal
```

And categorizes unstructured feedback:
```
"The validation logic should also check for empty files"
"Consider adding better error messages"
"This could be optimized for better performance"
```

## Example Output

```
🔄 Fetching MR feedback for issue 001.1...
  📥 Found MR: https://gitlab.com/.../merge_requests/2 (#2)
  💬 Fetched 5 discussions with 8 total comments
  🔍 Processed comments for actionable feedback
  ✅ Found 2 structured fix commands
  📝 Found 3 general feedback comments
  
📊 MR Feedback Summary:
  - MR: #2 - Create validation script framework
  - Total Comments: 8
  - Structured Fixes: 2 (/fix commands)
  - General Feedback: 3 items
  - Actionable Items: Yes (2 fixes required)
  - Last Fetched: 2025-08-28T10:15:30Z

💡 Next Steps:
  - Run: /cccc:mr:fix test-prd 001.1 (to implement fixes)
  - Or review feedback manually in sync-state.yaml

🔗 View MR: https://gitlab.com/jeunesse.paulien/cccc/-/merge_requests/2
```