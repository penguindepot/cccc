#!/bin/bash

echo "🚀 Starting work on issue $2"
echo ""

EPIC_NAME="$1"
ISSUE_ID="$2"

if [ -z "$EPIC_NAME" ] || [ -z "$ISSUE_ID" ]; then
  echo "❌ Usage: $0 <epic_name> <issue_id>"
  exit 1
fi

# Get current datetime for updates
current_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get platform and remote configuration
git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)
git_remote=$(yq '.git_remote // "origin"' .cccc/cccc-config.yml)

echo "🔧 Platform: $git_platform"
echo "🔧 Remote: $git_remote"
echo ""

# Get issue details from analysis and sync-state
echo "📋 Reading issue details..."
issue_title=$(yq ".issues.\"$ISSUE_ID\".title" .cccc/epics/$EPIC_NAME/analysis.yaml | tr -d '"')
issue_estimate=$(yq ".issues.\"$ISSUE_ID\".estimate_minutes" .cccc/epics/$EPIC_NAME/analysis.yaml)
issue_phase=$(yq ".issues.\"$ISSUE_ID\".phase" .cccc/epics/$EPIC_NAME/analysis.yaml)
issue_body_file=$(yq ".issues.\"$ISSUE_ID\".body_file" .cccc/epics/$EPIC_NAME/analysis.yaml | tr -d '"')

# Get platform issue number and MR details
issue_number=$(yq ".issue_mappings.\"$ISSUE_ID\".number" .cccc/epics/$EPIC_NAME/sync-state.yaml)
issue_url=$(yq ".issue_mappings.\"$ISSUE_ID\".url" .cccc/epics/$EPIC_NAME/sync-state.yaml | tr -d '"')
mr_url=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_url // \"\"" .cccc/epics/$EPIC_NAME/sync-state.yaml 2>/dev/null | tr -d '"')
mr_number=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_number" .cccc/epics/$EPIC_NAME/sync-state.yaml)

echo "Epic: $EPIC_NAME"
echo "Issue: #$issue_number - $issue_title"
echo ""

# Verify MR exists
if [ -z "$mr_url" ] || [ "$mr_url" = "null" ] || [ "$mr_url" = "" ]; then
  echo "❌ No merge request found for issue $ISSUE_ID"
  echo "Create MR first: /cccc:issue:mr $EPIC_NAME $ISSUE_ID"
  exit 1
fi

echo "✅ Pre-checks:"
echo "  - MR exists: $mr_url (#$mr_number)"

# Check dependencies are satisfied
echo "  - Checking dependencies..."
depends_on=$(yq ".issues.\"$ISSUE_ID\".depends_on" .cccc/epics/$EPIC_NAME/analysis.yaml)

if [ "$depends_on" != "null" ] && [ "$depends_on" != "[]" ]; then
  dependencies_satisfied=true
  dependency_list=$(yq ".issues.\"$ISSUE_ID\".depends_on[]" .cccc/epics/$EPIC_NAME/analysis.yaml | tr -d '"')
  
  for dep in $dependency_list; do
    dep_status=$(yq ".issue_mappings.\"$dep\".status" .cccc/epics/$EPIC_NAME/sync-state.yaml | tr -d '"')
    dep_title=$(yq ".issues.\"$dep\".title" .cccc/epics/$EPIC_NAME/analysis.yaml | tr -d '"')
    
    if [ "$dep_status" != "closed" ]; then
      echo "  ❌ Dependency not completed: $dep ($dep_title) - status: $dep_status"
      dependencies_satisfied=false
    else
      echo "  ✅ Dependency satisfied: $dep ($dep_title)"
    fi
  done
  
  if [ "$dependencies_satisfied" != "true" ]; then
    echo ""
    echo "❌ Cannot start work - dependencies not satisfied"
    echo "Complete dependency issues first or check their status"
    exit 1
  fi
else
  echo "  ✅ No dependencies required"
fi

# Check for epic worktree
worktree_path="../epic-$EPIC_NAME"
if ! git worktree list | grep -q "$worktree_path"; then
  echo "❌ Epic worktree not found: $worktree_path"
  echo "Worktree should have been created by /cccc:epic:sync"
  exit 1
fi
echo "  - Worktree exists: $worktree_path"

# Navigate to epic worktree
cd "$worktree_path" || {
  echo "❌ Failed to navigate to worktree: $worktree_path"
  exit 1
}

echo ""
echo "🔄 Updating branch..."

# Check if issue branch exists
issue_branch="issue/$ISSUE_ID"
if ! git branch | grep -q "$issue_branch"; then
  echo "❌ Issue branch not found: $issue_branch"
  echo "MR exists but branch is missing. Run: /cccc:issue:mr $EPIC_NAME $ISSUE_ID"
  exit 1
fi
echo "  ✅ Branch exists: $issue_branch"

# Fetch latest and checkout issue branch
echo "📥 Fetching latest from $git_remote..."
git fetch "$git_remote" >/dev/null 2>&1 || {
  echo "❌ Failed to fetch from remote"
  exit 1
}

echo "🔄 Checking out $issue_branch..."
git checkout "$issue_branch" >/dev/null 2>&1 || {
  echo "❌ Failed to checkout $issue_branch"
  exit 1
}

# Rebase issue branch on epic branch
epic_branch="epic/$EPIC_NAME"
echo "🔄 Rebasing $issue_branch on $epic_branch..."
if ! git rebase "$epic_branch" >/dev/null 2>&1; then
  echo "❌ Failed to rebase $issue_branch on $epic_branch"
  echo "Resolve conflicts manually and try again"
  exit 1
fi
echo "✅ Branch updated and ready"

# Return to main repo directory for agent launch
cd - >/dev/null

echo ""
echo "📝 Launching implementation agent..."

# Update sync-state with work started
echo "📊 Updating sync-state..."
sync_state_file=".cccc/epics/$EPIC_NAME/sync-state.yaml"

# Create backup
cp "$sync_state_file" "${sync_state_file}.bak"

# Update the issue mapping with work started
yq eval ".issue_mappings.\"$ISSUE_ID\".work_started = \"$current_datetime\"" -i "$sync_state_file"
yq eval ".issue_mappings.\"$ISSUE_ID\".work_status = \"in_progress\"" -i "$sync_state_file"
yq eval ".issue_mappings.\"$ISSUE_ID\".agent_launched = \"$current_datetime\"" -i "$sync_state_file"

# Cleanup backup if successful
if [ $? -eq 0 ]; then
  rm -f "${sync_state_file}.bak"
  echo "✅ Updated sync-state with work started"
else
  # Restore backup on failure
  mv "${sync_state_file}.bak" "$sync_state_file"
  echo "⚠️  Failed to update sync-state, restored backup"
fi

# Launch agent with Task tool
echo ""
echo "Agent ID: agent-$ISSUE_ID"
echo "Task: $issue_title"
echo "Estimated: ${issue_estimate} minutes"
echo "Phase: $issue_phase"
echo ""

# Prepare agent prompt
issue_file_path=".cccc/epics/$EPIC_NAME/$issue_body_file"

agent_prompt="You are implementing Issue #$issue_number: $issue_title

## Context
- Epic: $EPIC_NAME
- Issue ID: $ISSUE_ID
- Platform Issue: #$issue_number
- Worktree: $worktree_path
- Branch: $issue_branch
- Estimated time: ${issue_estimate} minutes

## Your Task
1. Navigate to the epic worktree: cd $worktree_path
2. Ensure you're on the correct branch: git checkout $issue_branch
3. Read the full issue requirements from: $issue_file_path
4. Implement the solution according to the acceptance criteria
5. Make focused, logical commits with format: \"Issue #$issue_number: {specific change}\"
6. Follow all coding standards and patterns from CLAUDE.md
7. Test your implementation thoroughly

## Important Guidelines
- Work ONLY in the epic worktree: $worktree_path
- Stay on the issue branch: $issue_branch
- Make atomic, well-described commits
- Follow the acceptance criteria exactly
- Use existing code patterns and conventions
- Ask clarifying questions if requirements are unclear

## When Complete
- Ensure all acceptance criteria are met
- All tests pass (if applicable)
- Code follows project conventions
- Ready for code review in the MR

The MR already exists at: $mr_url
Your commits will automatically appear in the MR for review.

Begin implementation now."

echo "🤖 Starting implementation..."

# Save agent prompt to temp file for command to read
agent_prompt_file="/tmp/mr-start-agent-prompt-$ISSUE_ID.txt"
issue_file_temp="/tmp/mr-start-issue-file-$ISSUE_ID.txt"

if ! echo "$agent_prompt" > "$agent_prompt_file"; then
  echo "❌ Failed to create agent prompt file"
  exit 1
fi

if ! echo "$issue_file_path" > "$issue_file_temp"; then
  echo "❌ Failed to create issue file reference"
  rm -f "$agent_prompt_file"
  exit 1
fi

# Verify issue file exists and is readable
if [ ! -f "$issue_file_path" ]; then
  echo "❌ Issue file not found: $issue_file_path"
  rm -f "$agent_prompt_file" "$issue_file_temp"
  exit 1
fi

# Output information for the command to use (structured format)
echo "AGENT_PROMPT_FILE=$agent_prompt_file"
echo "ISSUE_FILE_PATH=$issue_file_path"
echo "WORKTREE_PATH=$worktree_path"
echo "ISSUE_BRANCH=$issue_branch"
echo "MR_URL=$mr_url"
echo "ISSUE_URL=$issue_url"
echo "AGENT_LAUNCHED=$current_datetime"
echo "EPIC_NAME=$EPIC_NAME"
echo "ISSUE_ID=$ISSUE_ID"

exit 0