---
allowed-tools: Bash, Read, Write, LS, Task
---

# cccc:mr:fix

Analyze stored MR feedback and implement requested fixes using an agent. Exits gracefully if no fixes are required.

## Usage
```
/cccc:mr:fix <epic_name> <issue_id>
```

## Rules Required

These rules must be loaded and followed:
- `.claude/rules/datetime.md` - For getting real current date/time
- `.claude/rules/github-operations.md` - For GitHub CLI operations
- `.claude/rules/gitlab-operations.md` - For GitLab CLI operations
- `.claude/rules/cccc/branch-operations.md` - For branch management

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

### 3. MR and Feedback Validation
```bash
# Check if MR exists for this issue
mr_url=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_url" .cccc/epics/$EPIC_NAME/sync-state.yaml 2>/dev/null | tr -d '"')
mr_number=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_number" .cccc/epics/$EPIC_NAME/sync-state.yaml 2>/dev/null)

if [ -z "$mr_url" ] || [ "$mr_url" = "null" ]; then
  echo "❌ No merge request found for issue $ISSUE_ID"
  echo "Create MR first: /cccc:issue:mr $EPIC_NAME $ISSUE_ID"
  exit 1
fi

# Check if MR feedback has been fetched
mr_feedback_exists=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_feedback" .cccc/epics/$EPIC_NAME/sync-state.yaml 2>/dev/null | tr -d '"')

if [ -z "$mr_feedback_exists" ] || [ "$mr_feedback_exists" = "null" ]; then
  echo "❌ No MR feedback found for issue $ISSUE_ID"
  echo "Fetch feedback first: /cccc:mr:update $EPIC_NAME $ISSUE_ID"
  exit 1
fi

echo "✅ MR and feedback validated"
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

### Execute MR Fix Analysis and Implementation
```bash
# Call the dedicated mr-fix script to analyze feedback
SCRIPT_OUTPUT=$(.claude/scripts/cccc/mr-fix.sh "$EPIC_NAME" "$ISSUE_ID")

if [ $? -ne 0 ]; then
  echo "$SCRIPT_OUTPUT"
  exit 1
fi

# Check if fixes are required
FIX_REQUIRED=$(echo "$SCRIPT_OUTPUT" | grep "FIX_REQUIRED=" | cut -d'=' -f2)

if [ "$FIX_REQUIRED" = "false" ]; then
  echo "✅ All good! No fixes required."
  echo ""
  echo "$(echo "$SCRIPT_OUTPUT" | grep -A 10 "MR_FEEDBACK_SUMMARY:")"
  exit 0
fi

# Extract fix information from script output
FIX_PROMPT_FILE=$(echo "$SCRIPT_OUTPUT" | grep "FIX_PROMPT_FILE=" | cut -d'=' -f2)
WORKTREE_PATH=$(echo "$SCRIPT_OUTPUT" | grep "WORKTREE_PATH=" | cut -d'=' -f2)
ISSUE_BRANCH=$(echo "$SCRIPT_OUTPUT" | grep "ISSUE_BRANCH=" | cut -d'=' -f2)
FIX_COUNT=$(echo "$SCRIPT_OUTPUT" | grep "FIX_COUNT=" | cut -d'=' -f2)
MR_URL=$(echo "$SCRIPT_OUTPUT" | grep "MR_URL=" | cut -d'=' -f2)
MR_NUMBER=$(echo "$SCRIPT_OUTPUT" | grep "MR_NUMBER=" | cut -d'=' -f2)
ISSUE_TITLE=$(echo "$SCRIPT_OUTPUT" | grep "ISSUE_TITLE=" | cut -d'=' -f2)
EPIC_NAME_VAR=$(echo "$SCRIPT_OUTPUT" | grep "EPIC_NAME=" | cut -d'=' -f2)
ISSUE_ID_VAR=$(echo "$SCRIPT_OUTPUT" | grep "ISSUE_ID=" | cut -d'=' -f2)

# Validate critical variables were extracted
if [ -z "$FIX_PROMPT_FILE" ] || [ -z "$ISSUE_BRANCH" ]; then
  echo "❌ Failed to extract fix information from script output"
  echo "Script output was:"
  echo "$SCRIPT_OUTPUT"
  exit 1
fi

echo "🔧 Implementing MR fixes..."
echo "📋 Fix ID: fix-$ISSUE_ID"
echo "📁 Working in main repository"
echo "🌿 Branch: $ISSUE_BRANCH"
echo "🎯 Fixes to apply: $FIX_COUNT"
echo ""

# Read the fix prompt file
if [ -f "$FIX_PROMPT_FILE" ]; then
  FIX_PROMPT=$(cat "$FIX_PROMPT_FILE")
  
  # Launch Task agent with fix implementation prompt
  Task general-purpose "Fix MR feedback for $EPIC_NAME issue $ISSUE_ID" "$FIX_PROMPT

**CRITICAL REQUIREMENTS**:
1. Work in the main repository
2. Ensure you're on branch: git checkout $ISSUE_BRANCH
3. **RESPECT FIX SCOPE**:
   - ONLY address the specific feedback items listed above
   - DO NOT add extra improvements beyond what reviewers requested
   - DO NOT refactor unrelated code even if you see issues
   - DO NOT fix problems that weren't mentioned in the review
   - Each commit should address ONE specific feedback item
4. Make focused commits with format: \"Fix #$MR_NUMBER: {specific fix}\"
5. Push changes when complete

**SCOPE DISCIPLINE**: Only implement the exact fixes requested. If reviewers didn't ask for it, don't change it. Stay laser-focused on the feedback provided."

  # After agent completes, push changes to remote
  echo ""
  echo "📤 Pushing fix changes to remote..."
  
  # Get git remote from config
  git_remote=$(yq '.git_remote // "origin"' .cccc/cccc-config.yml)
  
  # Push the fixes from current repository
  
  # Check if there are new commits to push
  if git diff --quiet "$git_remote/$ISSUE_BRANCH" "$ISSUE_BRANCH" 2>/dev/null; then
    echo "📝 No new commits to push (branch up to date)"
  else
    if git push --force-with-lease "$git_remote" "$ISSUE_BRANCH" 2>/dev/null; then
      echo "✅ Successfully pushed fixes to $git_remote"
      
      # Post confirmation comment to MR
      echo "💬 Posting fix confirmation to MR..."
      current_completion_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      
      fix_summary="## 🤖 Applied Requested Fixes

**Fixed:** $current_completion_time

Applied $FIX_COUNT review fixes based on MR feedback:

$(yq -r '.issue_mappings."'$ISSUE_ID_VAR'".mr_feedback.comments[] | select(.type == "structured") | "- " + .fix_description' .cccc/epics/$EPIC_NAME_VAR/sync-state.yaml 2>/dev/null || echo "- Implemented requested changes")

**Changes:** View the latest commits in this MR
**Status:** Ready for re-review

---
*Fixes applied automatically by CCCC MR Fix System*"

      # Post comment via platform CLI
      git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)
      
      if [[ "$git_platform" == "gitlab" ]]; then
        echo "$fix_summary" | glab api "projects/:id/merge_requests/$MR_NUMBER/notes" --method POST --field "body=@-" >/dev/null 2>&1
      else
        echo "$fix_summary" | gh api "repos/:owner/:repo/issues/$MR_NUMBER/comments" --method POST --field "body=@-" >/dev/null 2>&1
      fi
      
      if [ $? -eq 0 ]; then
        echo "✅ Posted fix confirmation comment"
      else
        echo "⚠️ Failed to post confirmation comment (fixes still applied)"
      fi
      
    else
      echo "⚠️ Push failed - check for conflicts or network issues"
      echo "Manual push: git push --force-with-lease $git_remote $ISSUE_BRANCH"
      exit 1
    fi
  fi
  
  # Update sync-state with fix completion status
  echo "📊 Updating sync-state with fix completion..."
  current_completion_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  sync_state_file=".cccc/epics/$EPIC_NAME_VAR/sync-state.yaml"
  
  if [ -f "$sync_state_file" ]; then
    cp "$sync_state_file" "${sync_state_file}.bak"
    yq eval ".issue_mappings.\"$ISSUE_ID_VAR\".mr_feedback.fixes_applied_at = \"$current_completion_time\"" -i "$sync_state_file"
    yq eval ".issue_mappings.\"$ISSUE_ID_VAR\".mr_feedback.fix_status = \"completed\"" -i "$sync_state_file"
    
    if [ $? -eq 0 ]; then
      rm -f "${sync_state_file}.bak"
      echo "✅ Updated sync-state with fix completion status"
    else
      mv "${sync_state_file}.bak" "$sync_state_file"
      echo "⚠️ Failed to update sync-state, restored backup"
    fi
  fi
  
  # Clean up temp files
  rm -f "$FIX_PROMPT_FILE"
  
  echo ""
  echo "🎉 MR Fixes Applied Successfully!"
  echo "🔗 Track progress:"
  echo "  - MR: $MR_URL"
  echo "  - Branch: $ISSUE_BRANCH"
  echo "  - Fixes Applied: $FIX_COUNT"
  echo "  - Status: Ready for re-review"
  echo ""
  echo "💡 Next Steps:"
  echo "  - Review the updated MR with applied fixes"
  echo "  - Merge when satisfied with the fixes"
  
else
  echo "❌ Failed to read fix prompt file"
  exit 1
fi
```

## Error Handling

If the MR fix fails:
- Check error messages for specific guidance
- Ensure MR feedback was fetched first with `/cccc:mr:update`
- Check branch exists and can be checked out
- Ensure you have write access to push changes
- Verify platform CLI authentication and permissions

## Important Notes

1. **Prerequisite**: Requires MR feedback fetched by `/cccc:mr:update` first
2. **Graceful Exit**: If no actionable fixes found, exits with success message (no spam)
3. **Real Agent Execution**: Launches Task agent for actual fix implementation
4. **Automatic Push**: Pushes fix changes to remote after agent completes
5. **MR Comment**: Posts single confirmation comment only when fixes are applied
6. **Progress Tracking**: Updates sync-state.yaml with fix completion status

## Expected Output (No Fixes)

```
🔍 Analyzing MR feedback for issue 001.1...
  📥 Found MR feedback with 0 actionable fixes
  💬 3 general feedback comments (informational only)

✅ All good! No fixes required.

📊 MR Feedback Summary:
  - MR: #2 - Create validation script framework
  - Structured Fixes: 0 (/fix commands)
  - General Feedback: 3 items
  - Status: No action needed
```

## Expected Output (With Fixes)

```
🔍 Analyzing MR feedback for issue 001.1...
  📥 Found MR feedback with 2 actionable fixes
  🎯 Preparing fix implementation...

🔧 Implementing MR fixes...
📋 Fix ID: fix-001.1
📁 Working in: main repository
🌿 Branch: issue/001.1
🎯 Fixes to apply: 2

🤖 Launching fix agent...
[Agent implements the fixes...]

📤 Pushing fix changes to remote...
✅ Successfully pushed fixes to origin

💬 Posting fix confirmation to MR...
✅ Posted fix confirmation comment

📊 Updating sync-state with fix completion...
✅ Updated sync-state with fix completion status

🎉 MR Fixes Applied Successfully!
🔗 Track progress:
  - MR: https://gitlab.com/.../merge_requests/2
  - Branch: issue/001.1
  - Fixes Applied: 2
  - Status: Ready for re-review

💡 Next Steps:
  - Review the updated MR with applied fixes
  - Merge when satisfied with the fixes
```