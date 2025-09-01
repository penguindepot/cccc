---
allowed-tools: Bash, Read, Write, LS, Task
---

# cccc:mr:start

Start implementation work on an existing merge request by launching an agent to complete the issue requirements.

## Usage
```
/cccc:mr:start <epic_name> <issue_id>
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

### Execute MR Start Implementation
```bash
# Call the dedicated mr-start script with all the complex logic
SCRIPT_OUTPUT=$(.claude/scripts/cccc/mr-start.sh "$EPIC_NAME" "$ISSUE_ID")

if [ $? -ne 0 ]; then
  echo "$SCRIPT_OUTPUT"
  exit 1
fi

# Extract agent information from script output
AGENT_PROMPT_FILE=$(echo "$SCRIPT_OUTPUT" | grep "AGENT_PROMPT_FILE=" | cut -d'=' -f2)
ISSUE_FILE_PATH=$(echo "$SCRIPT_OUTPUT" | grep "ISSUE_FILE_PATH=" | cut -d'=' -f2)
WORKTREE_PATH=$(echo "$SCRIPT_OUTPUT" | grep "WORKTREE_PATH=" | cut -d'=' -f2)
ISSUE_BRANCH=$(echo "$SCRIPT_OUTPUT" | grep "ISSUE_BRANCH=" | cut -d'=' -f2)
MR_URL=$(echo "$SCRIPT_OUTPUT" | grep "MR_URL=" | cut -d'=' -f2)
ISSUE_URL=$(echo "$SCRIPT_OUTPUT" | grep "ISSUE_URL=" | cut -d'=' -f2)
AGENT_LAUNCHED=$(echo "$SCRIPT_OUTPUT" | grep "AGENT_LAUNCHED=" | cut -d'=' -f2)
EPIC_NAME_VAR=$(echo "$SCRIPT_OUTPUT" | grep "EPIC_NAME=" | cut -d'=' -f2)
ISSUE_ID_VAR=$(echo "$SCRIPT_OUTPUT" | grep "ISSUE_ID=" | cut -d'=' -f2)

# Validate critical variables were extracted
if [ -z "$AGENT_PROMPT_FILE" ] || [ -z "$WORKTREE_PATH" ] || [ -z "$ISSUE_BRANCH" ]; then
  echo "❌ Failed to extract agent information from script output"
  echo "Script output was:"
  echo "$SCRIPT_OUTPUT"
  exit 1
fi

# Read the agent prompt and issue content
if [ -f "$AGENT_PROMPT_FILE" ]; then
  AGENT_PROMPT=$(cat "$AGENT_PROMPT_FILE")
  ISSUE_CONTENT=$(cat "$ISSUE_FILE_PATH")
  
  echo "🚀 Launching implementation agent..."
  echo "📋 Agent ID: agent-$ISSUE_ID"
  echo "📁 Working in: $WORKTREE_PATH"
  echo "🌿 Branch: $ISSUE_BRANCH"
  echo ""
  
  # Launch Task agent with implementation prompt
  Task general-purpose "Implement $EPIC_NAME issue $ISSUE_ID" "$AGENT_PROMPT

Issue Requirements:
$ISSUE_CONTENT

**CRITICAL**: Work ONLY in the epic worktree: $WORKTREE_PATH
Navigate there first: cd $WORKTREE_PATH
Ensure you're on branch: git checkout $ISSUE_BRANCH
Make commits and push them to complete the implementation."

  # After agent completes, push changes to remote
  echo ""
  echo "📤 Pushing implementation changes to remote..."
  
  # Get git remote from config
  git_remote=$(yq '.git_remote // "origin"' .cccc/cccc-config.yml)
  
  # Push the implementation
  cd "$WORKTREE_PATH" || {
    echo "❌ Failed to navigate to worktree for push"
    exit 1
  }
  
  # Check if there are new commits to push
  if git diff --quiet "$git_remote/$ISSUE_BRANCH" "$ISSUE_BRANCH" 2>/dev/null; then
    echo "📝 No new commits to push (branch up to date)"
  else
    if git push --force-with-lease "$git_remote" "$ISSUE_BRANCH" 2>/dev/null; then
      echo "✅ Successfully pushed $ISSUE_BRANCH to $git_remote"
    else
      echo "⚠️  Push failed - check for conflicts or network issues"
      echo "Manual push: cd $WORKTREE_PATH && git push --force-with-lease $git_remote $ISSUE_BRANCH"
      cd - >/dev/null
      exit 1
    fi
  fi
  
  cd - >/dev/null
  
  # Update sync-state with completion status
  echo "📊 Updating sync-state with completion..."
  current_completion_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  sync_state_file=".cccc/epics/$EPIC_NAME_VAR/sync-state.yaml"
  
  if [ -f "$sync_state_file" ]; then
    cp "$sync_state_file" "${sync_state_file}.bak"
    yq eval ".issue_mappings.\"$ISSUE_ID_VAR\".work_completed = \"$current_completion_time\"" -i "$sync_state_file"
    yq eval ".issue_mappings.\"$ISSUE_ID_VAR\".work_status = \"completed\"" -i "$sync_state_file"
    
    if [ $? -eq 0 ]; then
      rm -f "${sync_state_file}.bak"
      echo "✅ Updated sync-state with completion status"
    else
      mv "${sync_state_file}.bak" "$sync_state_file"
      echo "⚠️  Failed to update sync-state, restored backup"
    fi
  fi
  
  # Clean up temp files
  rm -f "$AGENT_PROMPT_FILE" "/tmp/mr-start-issue-file-$ISSUE_ID.txt"
  
  echo ""
  echo "🎉 Implementation Complete!"
  echo "🔗 Track progress:"
  echo "  - MR: $MR_URL"
  echo "  - Issue: $ISSUE_URL"
  echo "  - Branch: $ISSUE_BRANCH"
  echo "  - Status: agent_completed ($AGENT_LAUNCHED)"
  echo ""
  echo "💡 Next Steps:"
  echo "  - Review the MR for implemented changes"
  echo "  - Test the implementation if needed"
  echo "  - Merge when satisfied with the work"
  
else
  echo "❌ Failed to prepare agent prompt"
  exit 1
fi
```

## Error Handling

If the MR start fails:
- Check error messages for specific guidance
- Ensure MR was created first with `/cccc:issue:mr`
- Verify worktree exists and is accessible
- Check branch exists and can be checked out
- Ensure dependencies are satisfied before starting work

## Important Notes

1. **MR Must Exist**: This command requires an MR created by `/cccc:issue:mr`
2. **Real Agent Execution**: Actually launches a Task agent for implementation (no simulation)
3. **Dependency Checking**: Validates all dependencies are completed before starting
4. **Branch Management**: Uses existing issue branch, rebases and updates automatically
5. **Automatic Push**: Pushes implementation changes to remote after agent completes
6. **Progress Tracking**: Updates sync-state.yaml with work status and agent launch time

## Expected Output

```
🚀 Starting work on issue 001.1
Epic: test-prd
Issue: #35 - Create validation script framework

✅ Pre-checks:
  - MR exists: https://gitlab.com/.../merge_requests/2 (#2)
  - Dependencies satisfied: No dependencies required
  - Worktree exists: ../epic-test-prd

🔄 Updating branch...
  ✅ Branch exists: issue/001.1
  ✅ Rebased on epic/test-prd

🚀 Launching implementation agent...
📋 Agent ID: agent-001.1
📁 Working in: ../epic-test-prd
🌿 Branch: issue/001.1

[Agent implements the solution...]

📤 Pushing implementation changes to remote...
✅ Successfully pushed issue/001.1 to origin

🎉 Implementation Complete!
🔗 Track progress:
  - MR: https://gitlab.com/.../merge_requests/2
  - Issue: https://gitlab.com/.../issues/35
  - Branch: issue/001.1
  - Status: agent_completed (2025-08-28T07:04:02Z)

💡 Next Steps:
  - Review the MR for implemented changes
  - Test the implementation if needed
  - Merge when satisfied with the work
```