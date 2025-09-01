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

# Get platform issue number
issue_number=$(yq ".issue_mappings.\"$ISSUE_ID\".number" .cccc/epics/$EPIC_NAME/sync-state.yaml)
issue_url=$(yq ".issue_mappings.\"$ISSUE_ID\".url" .cccc/epics/$EPIC_NAME/sync-state.yaml | tr -d '"')

echo "Epic: $EPIC_NAME"
echo "Issue: #$issue_number - $issue_title"
echo ""

echo "✅ Pre-checks:"

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

# Check if epic branch exists
epic_branch="epic/$EPIC_NAME"
if ! git branch -a | grep -q "$epic_branch"; then
  echo "❌ Epic branch not found: $epic_branch"
  echo "Epic branch should have been created by /cccc:epic:sync"
  exit 1
fi
echo "  - Epic branch exists: $epic_branch"

echo ""
echo "🔄 Creating issue branch..."

# Create issue branch from epic branch
issue_branch="issue/$ISSUE_ID"

# Check if issue branch already exists
if git branch | grep -q "$issue_branch"; then
  echo "  ⚠️  Branch already exists: $issue_branch"
  echo "  🔄 Switching to existing branch..."
  git checkout "$issue_branch" >/dev/null 2>&1 || {
    echo "❌ Failed to checkout existing branch: $issue_branch"
    exit 1
  }
else
  # Fetch latest updates first
  echo "📥 Fetching latest from $git_remote..."
  git fetch "$git_remote" >/dev/null 2>&1 || {
    echo "❌ Failed to fetch from remote"
    exit 1
  }
  
  # Ensure we're on the epic branch to create issue branch from it
  echo "🔄 Checking out epic branch: $epic_branch..."
  git checkout "$epic_branch" >/dev/null 2>&1 || {
    echo "❌ Failed to checkout epic branch: $epic_branch"
    exit 1
  }
  
  # Pull latest epic branch changes
  echo "📥 Pulling latest epic changes..."
  git pull "$git_remote" "$epic_branch" >/dev/null 2>&1 || {
    echo "❌ Failed to pull latest epic changes"
    exit 1
  }
  
  # Create and checkout issue branch
  echo "🌟 Creating branch: $issue_branch..."
  git checkout -b "$issue_branch" >/dev/null 2>&1 || {
    echo "❌ Failed to create issue branch: $issue_branch"
    exit 1
  }
  
  echo "  ✅ Created branch: $issue_branch"
  echo "  ✅ Branch based on: $epic_branch"
fi

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
- Branch: $issue_branch
- Estimated time: ${issue_estimate} minutes

## Your Task
1. Ensure you're on the correct branch: git checkout $issue_branch
2. Read the full issue requirements from: $issue_file_path
3. Implement the solution according to the acceptance criteria
4. Make focused, logical commits with format: \"Issue #$issue_number: {specific change}\"
5. Follow all coding standards and patterns from CLAUDE.md
6. Test your implementation thoroughly

## Important Guidelines
- Work in the main repository (no worktrees)
- Stay on the issue branch: $issue_branch
- Make atomic, well-described commits
- Follow the acceptance criteria exactly
- Use existing code patterns and conventions
- Ask clarifying questions if requirements are unclear

## CRITICAL: Respect Issue Scope
**You MUST stay within the boundaries of this specific issue:**
- ONLY implement what is explicitly required in the acceptance criteria
- DO NOT add extra features or \"nice-to-have\" improvements
- DO NOT refactor code that isn't directly related to this issue
- DO NOT fix other bugs or issues you might discover
- If you notice other problems, mention them in comments but DO NOT fix them
- Focus on delivering EXACTLY what issue #$issue_number requires

Remember: Each issue has a specific scope for a reason. Other issues may depend on the current state of the code. Unauthorized changes can break other work in progress.

## When Complete
- Ensure all acceptance criteria are met
- All tests pass (if applicable)
- Code follows project conventions
- Ready for MR creation with /cccc:issue:mr $EPIC_NAME $ISSUE_ID

Begin implementation now."

echo "🤖 Starting implementation..."

# Save agent prompt to temp file for command to read
agent_prompt_file="/tmp/issue-start-agent-prompt-$ISSUE_ID.txt"
issue_file_temp="/tmp/issue-start-issue-file-$ISSUE_ID.txt"

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
echo "ISSUE_BRANCH=$issue_branch"
echo "ISSUE_URL=$issue_url"
echo "AGENT_LAUNCHED=$current_datetime"
echo "EPIC_NAME=$EPIC_NAME"
echo "ISSUE_ID=$ISSUE_ID"

exit 0