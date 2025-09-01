#!/bin/bash
# mr-fix.sh - Analyze MR feedback and prepare fix implementation

set -e  # Exit on any error

EPIC_NAME="$1"
ISSUE_ID="$2"

if [ -z "$EPIC_NAME" ] || [ -z "$ISSUE_ID" ]; then
    echo "❌ Usage: $0 <epic_name> <issue_id>"
    exit 1
fi

echo "🔍 Analyzing MR feedback for issue $ISSUE_ID..."

# Get current datetime for updates
current_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get platform and sync state info
git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)
git_remote=$(yq '.git_remote // "origin"' .cccc/cccc-config.yml)
sync_state_file=".cccc/epics/$EPIC_NAME/sync-state.yaml"

# Get MR and issue details from sync-state
mr_number=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_number" "$sync_state_file")
mr_url=$(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_url" "$sync_state_file")
issue_title=$(yq -r ".issue_mappings.\"$ISSUE_ID\".title" "$sync_state_file")
issue_number=$(yq ".issue_mappings.\"$ISSUE_ID\".number" "$sync_state_file")

# Check if MR feedback exists
mr_feedback_exists=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_feedback" "$sync_state_file" 2>/dev/null)

if [ -z "$mr_feedback_exists" ] || [ "$mr_feedback_exists" = "null" ]; then
    echo "❌ No MR feedback found"
    echo "Run: /cccc:mr:update $EPIC_NAME $ISSUE_ID"
    exit 1
fi

# Get feedback details
actionable_count=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_feedback.actionable_count" "$sync_state_file")
feedback_count=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_feedback.feedback_count" "$sync_state_file")
fix_required=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_feedback.fix_required" "$sync_state_file")
last_fetched=$(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.last_fetched" "$sync_state_file")

# Count structured and AI-detected fixes separately  
structured_fixes=$(yq '.issue_mappings."'$ISSUE_ID'".mr_feedback.comments[] | select(.type == "structured")' "$sync_state_file" 2>/dev/null | wc -l | tr -d ' ')
ai_detected_fixes=$(yq '.issue_mappings."'$ISSUE_ID'".mr_feedback.comments[] | select(.type == "ai_detected_action")' "$sync_state_file" 2>/dev/null | wc -l | tr -d ' ')
total_actionable=$((structured_fixes + ai_detected_fixes))

echo "  📥 Found MR feedback with $total_actionable actionable fixes"
echo "    - Structured (/fix): $structured_fixes"
echo "    - AI-detected: $ai_detected_fixes"
echo "  💬 $feedback_count general feedback comments $([ "$feedback_count" -gt 0 ] && echo "(informational only)" || echo "")"

# Check if fixes are required
if [ "$fix_required" != "true" ] || [ "$total_actionable" -eq 0 ]; then
    echo ""
    echo "FIX_REQUIRED=false"
    echo "MR_FEEDBACK_SUMMARY:"
    echo "📊 MR Feedback Summary:"
    echo "  - MR: #$mr_number - $issue_title"
    echo "  - Structured Fixes: $structured_fixes (/fix commands)"
    echo "  - AI-Detected Actions: $ai_detected_fixes items"
    echo "  - General Feedback: $feedback_count items"
    echo "  - Status: No action needed"
    echo "  - Last Fetched: $last_fetched"
    exit 0
fi

echo "  🎯 Preparing fix implementation..."

# Check for epic worktree
worktree_path="../epic-$EPIC_NAME"
if ! git worktree list | grep -q "$worktree_path"; then
    echo "❌ Epic worktree not found: $worktree_path"
    echo "Worktree should have been created by /cccc:epic:sync"
    exit 1
fi

# Navigate to epic worktree to check branch
cd "$worktree_path" || {
    echo "❌ Failed to navigate to worktree: $worktree_path"
    exit 1
}

# Check if issue branch exists
issue_branch="issue/$ISSUE_ID"
if ! git branch | grep -q "$issue_branch"; then
    echo "❌ Issue branch not found: $issue_branch"
    echo "MR exists but branch is missing. Run: /cccc:issue:mr $EPIC_NAME $ISSUE_ID"
    exit 1
fi

# Fetch latest and checkout issue branch
git fetch "$git_remote" >/dev/null 2>&1 || {
    echo "❌ Failed to fetch from remote"
    exit 1
}

git checkout "$issue_branch" >/dev/null 2>&1 || {
    echo "❌ Failed to checkout $issue_branch"
    exit 1
}

# Rebase issue branch on epic branch (ensure we're up to date)
epic_branch="epic/$EPIC_NAME"
if ! git rebase "$epic_branch" >/dev/null 2>&1; then
    echo "❌ Failed to rebase $issue_branch on $epic_branch"
    echo "Resolve conflicts manually and try again"
    exit 1
fi

# Return to main repo directory
cd - >/dev/null

# Prepare fix prompt
issue_file_path=".cccc/epics/$EPIC_NAME/issues/$ISSUE_ID.md"

# Extract structured fix commands
fix_prompt_file="/tmp/mr-fix-prompt-$ISSUE_ID.txt"

# Build the fix prompt
cat > "$fix_prompt_file" << EOF
You are implementing fixes for MR #$mr_number: $issue_title based on reviewer feedback.

## Context
- Epic: $EPIC_NAME
- Issue ID: $ISSUE_ID
- Platform Issue: #$issue_number
- MR: #$mr_number ($mr_url)
- Worktree: $worktree_path
- Branch: $issue_branch

## Reviewer Feedback to Address

The following fixes have been requested by reviewers:

EOF

# Process AI-detected actionable comments directly
if yq -e ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"ai_detected_action\")" "$sync_state_file" >/dev/null 2>&1; then
    {
        echo "### AI-Detected Fix Required"
        echo "**Reviewer:** $(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"ai_detected_action\") | .author" "$sync_state_file") ($(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"ai_detected_action\") | .date" "$sync_state_file"))"
        echo "**Action Needed:** $(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"ai_detected_action\") | .fix_description" "$sync_state_file")"
        file_path=$(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"ai_detected_action\") | .file_path" "$sync_state_file")
        line_number=$(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"ai_detected_action\") | .line_number" "$sync_state_file")
        if [[ -n "$file_path" && "$file_path" != "null" && "$file_path" != "" ]]; then
            location_line="**Location:** $file_path"
            if [[ -n "$line_number" && "$line_number" != "null" && "$line_number" != "" ]]; then
                location_line="$location_line:$line_number"
            fi
            echo "$location_line"
        fi
        echo ""
    } >> "$fix_prompt_file"
fi

# Process structured fix commands
if yq -e ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"structured\")" "$sync_state_file" >/dev/null 2>&1; then
    {
        echo "### Structured Fix"
        echo "**Reviewer:** $(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"structured\") | .author" "$sync_state_file") ($(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"structured\") | .date" "$sync_state_file"))"
        echo "**Request:** $(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"structured\") | .fix_description" "$sync_state_file")"
        echo "**Original Comment:** $(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"structured\") | .body" "$sync_state_file")"
        file_path=$(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"structured\") | .file_path" "$sync_state_file")
        line_number=$(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_feedback.comments[] | select(.type == \"structured\") | .line_number" "$sync_state_file")
        if [[ -n "$file_path" && "$file_path" != "null" && "$file_path" != "" ]]; then
            location_line="**Location:** $file_path"
            if [[ -n "$line_number" && "$line_number" != "null" && "$line_number" != "" ]]; then
                location_line="$location_line:$line_number"
            fi
            echo "$location_line"
        fi
        echo ""
    } >> "$fix_prompt_file"
fi

# Add general feedback context if any
feedback_items=$(yq '.issue_mappings."'$ISSUE_ID'".mr_feedback.comments[] | select(.type == "feedback")' "$sync_state_file" 2>/dev/null | wc -l | tr -d ' ')

if [ "$feedback_items" -gt 0 ]; then
    echo "" >> "$fix_prompt_file"
    echo "## Additional Context (General Feedback)" >> "$fix_prompt_file"
    echo "Consider this feedback while making fixes:" >> "$fix_prompt_file"
    echo "" >> "$fix_prompt_file"
    
    yq -r '.issue_mappings."'$ISSUE_ID'".mr_feedback.comments[] | select(.type == "feedback") | "- **" + .author + "**: " + .body' "$sync_state_file" >> "$fix_prompt_file"
fi

cat >> "$fix_prompt_file" << EOF

## Your Task

1. Ensure you're on the correct branch: git checkout $issue_branch
2. Address each structured fix request above
3. Make focused commits with format: "Fix #$mr_number: {specific fix description}"
4. Follow all coding standards from CLAUDE.md
5. Test your fixes if applicable

## Important Guidelines

- Work in the main repository (no worktrees)
- Stay on the issue branch: $issue_branch
- Make atomic commits for each fix
- Address the reviewer feedback precisely
- Use existing code patterns and conventions

## CRITICAL: Respect Fix Scope

**You MUST stay within the boundaries of the requested fixes:**
- ONLY address the specific feedback items listed above
- DO NOT add extra improvements or "while I'm here" changes
- DO NOT refactor code that isn't directly related to the fixes
- DO NOT fix other issues you might discover
- Each commit should address ONE specific feedback item
- If a fix requires touching unrelated code, make minimal changes only

**Fix Discipline**: Reviewers asked for specific changes. Deliver exactly those changes and nothing more. Scope creep in fixes can introduce new bugs or break other work.

## Original Issue Requirements

For reference, the original issue requirements are in: $issue_file_path

## When Complete

- Ensure all requested fixes are implemented
- Code follows project conventions
- Ready for re-review in the MR
- Each fix should be in a separate, well-described commit

The fixes will automatically be pushed to the MR for re-review.

Begin implementing the requested fixes now.
EOF

# Output information for the command to use (structured format like mr-start.sh)
echo ""
echo "FIX_REQUIRED=true"
echo "FIX_PROMPT_FILE=$fix_prompt_file"
echo "WORKTREE_PATH=$worktree_path"
echo "ISSUE_BRANCH=$issue_branch"
echo "FIX_COUNT=$total_actionable"
echo "MR_URL=$mr_url"
echo "MR_NUMBER=$mr_number"
echo "ISSUE_TITLE=$issue_title"
echo "EPIC_NAME=$EPIC_NAME"
echo "ISSUE_ID=$ISSUE_ID"

exit 0