#!/bin/bash

echo "🔗 Creating MR for Issue $2..."
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

# Check if issue branch exists
issue_branch="issue/$ISSUE_ID"
if ! git branch | grep -q "$issue_branch"; then
  echo "❌ Issue branch not found: $issue_branch"
  echo "Run: /cccc:issue:start $EPIC_NAME $ISSUE_ID"
  exit 1
fi
echo "✅ Issue branch found: $issue_branch"

# Get issue details from analysis
issue_title=$(yq ".issues.\"$ISSUE_ID\".title" .cccc/epics/$EPIC_NAME/analysis.yaml | tr -d '"')
issue_body_file=$(yq ".issues.\"$ISSUE_ID\".body_file" .cccc/epics/$EPIC_NAME/analysis.yaml | tr -d '"')
issue_estimate=$(yq ".issues.\"$ISSUE_ID\".estimate_minutes" .cccc/epics/$EPIC_NAME/analysis.yaml)

echo "📝 Issue: $issue_title"
echo "📄 Body file: $issue_body_file"
echo ""

# Get issue number from sync-state
issue_number=$(yq ".issue_mappings.\"$ISSUE_ID\".number" .cccc/epics/$EPIC_NAME/sync-state.yaml)
if [ -z "$issue_number" ] || [ "$issue_number" = "null" ]; then
  echo "❌ Issue not found in sync-state.yaml"
  echo "Ensure the issue was properly synced."
  exit 1
fi

echo "🏷️  Platform issue number: #$issue_number"
echo ""

# Work in main repository (no worktree navigation needed)

echo "🔄 Updating and rebasing branches..."

# Fetch latest from remote
echo "📥 Fetching latest from $git_remote..."
git fetch "$git_remote" || {
  echo "❌ Failed to fetch from remote"
  exit 1
}

# Rebase epic branch on main
epic_branch="epic/$EPIC_NAME"
echo "🔄 Rebasing epic branch ($epic_branch) on $git_remote/main..."
git checkout "$epic_branch" >/dev/null 2>&1 || {
  echo "❌ Failed to checkout $epic_branch"
  exit 1
}

if ! git rebase "$git_remote/main"; then
  echo "❌ Failed to rebase $epic_branch on main"
  echo "Resolve conflicts manually and try again"
  exit 1
fi
echo "✅ Epic branch rebased successfully"

# Push the rebased epic branch to keep remote synchronized
echo "📤 Pushing rebased epic branch to remote..."
if git push "$git_remote" "$epic_branch"; then
  echo "✅ Epic branch pushed to $git_remote"
else
  echo "⚠️ Failed to push epic branch, continuing with MR creation..."
fi

# Checkout existing issue branch (should already exist from /cccc:issue:start)
echo "🌿 Checking out issue branch: $issue_branch"
git checkout "$issue_branch" >/dev/null 2>&1 || {
  echo "❌ Failed to checkout issue branch: $issue_branch"
  echo "Ensure issue branch was created with /cccc:issue:start $EPIC_NAME $ISSUE_ID"
  exit 1
}

# Rebase issue branch on epic branch
echo "🔄 Rebasing issue branch on epic..."
if ! git rebase "$epic_branch"; then
  echo "❌ Failed to rebase $issue_branch on $epic_branch"
  echo "Resolve conflicts manually and try again"
  exit 1
fi
echo "✅ Issue branch rebased successfully"

# Push issue branch to remote
echo "📤 Pushing issue branch to remote..."
if git push -u "$git_remote" "$issue_branch" 2>&1; then
  echo "✅ Issue branch pushed to $git_remote"
else
  echo "⚠️ Branch may already exist on remote, continuing..."
fi
echo ""

# Get issue content for MR description
echo "📖 Reading issue content..."
issue_file_path=".cccc/epics/$EPIC_NAME/$issue_body_file"
if [ -f "$issue_file_path" ]; then
  # Get first few lines for description
  issue_description=$(head -10 "$issue_file_path" | sed '/^$/d' | head -5)
else
  issue_description="Implementation of issue $ISSUE_ID"
fi

# Create MR/PR based on platform
echo "🚀 Creating $git_platform MR/PR..."

if [ "$git_platform" = "gitlab" ]; then
  # Create GitLab MR
  echo "Creating GitLab merge request..."
  
  mr_output=$(glab mr create \
    --source-branch "$issue_branch" \
    --target-branch "$epic_branch" \
    --title "Issue #$issue_number: $issue_title" \
    --description "Resolves #$issue_number

## Description
$issue_description

## Changes
- Implementation of issue #$issue_number ($ISSUE_ID)
- Epic: $EPIC_NAME
- Branch: $issue_branch
- Estimated: ${issue_estimate}min

Created via /cccc:issue:mr command on $current_datetime" \
    --label "issue" \
    --assignee "@me" 2>&1)
  
  if [ $? -eq 0 ]; then
    # Extract MR URL from output
    mr_url=$(echo "$mr_output" | grep -o 'https://gitlab.com/[^[:space:]]*' | head -1)
    mr_number=$(echo "$mr_url" | grep -oE '[0-9]+$' | tail -1)
    
    if [ -z "$mr_url" ]; then
      # Try alternative extraction
      mr_url=$(echo "$mr_output" | grep -o 'https://[^[:space:]]*merge_requests/[0-9]*' | head -1)
      mr_number=$(echo "$mr_url" | grep -oE '[0-9]+$')
    fi
    
    platform_type="GitLab MR"
  else
    echo "❌ Failed to create GitLab MR:"
    echo "$mr_output"
    exit 1
  fi
  
else
  # Create GitHub PR
  echo "Creating GitHub pull request..."
  
  pr_output=$(gh pr create \
    --base "$epic_branch" \
    --head "$issue_branch" \
    --title "Issue #$issue_number: $issue_title" \
    --body "Resolves #$issue_number

## Description
$issue_description

## Changes
- Implementation of issue #$issue_number ($ISSUE_ID)  
- Epic: $EPIC_NAME
- Branch: $issue_branch
- Estimated: ${issue_estimate}min

Created via /cccc:issue:mr command on $current_datetime" \
    --label "issue" \
    --assignee "@me" 2>&1)
  
  if [ $? -eq 0 ]; then
    # Extract PR URL from output
    mr_url=$(echo "$pr_output" | grep -o 'https://github.com/[^[:space:]]*' | head -1)
    mr_number=$(echo "$mr_url" | grep -oE '[0-9]+$' | tail -1)
    
    platform_type="GitHub PR"
  else
    echo "❌ Failed to create GitHub PR:"
    echo "$pr_output"
    exit 1
  fi
fi

if [ -z "$mr_url" ] || [ -z "$mr_number" ]; then
  echo "❌ Could not extract MR/PR URL or number from output"
  echo "Output was: $mr_output$pr_output"
  exit 1
fi

echo "✅ $platform_type created successfully!"
echo "   URL: $mr_url"  
echo "   Number: #$mr_number"
echo ""

# Update sync-state.yaml (already in main repo)

echo "📁 Updating sync-state.yaml..."
sync_state_file=".cccc/epics/$EPIC_NAME/sync-state.yaml"

# Create backup
cp "$sync_state_file" "${sync_state_file}.bak"

# Add MR information to the specific issue mapping
if [ "$git_platform" = "gitlab" ]; then
  mr_field="mr_url"
  mr_number_field="mr_number"
else  
  mr_field="pr_url"
  mr_number_field="pr_number"
fi

# Update the issue mapping with MR information
yq eval ".issue_mappings.\"$ISSUE_ID\".${mr_field} = \"$mr_url\"" -i "$sync_state_file"
yq eval ".issue_mappings.\"$ISSUE_ID\".${mr_number_field} = $mr_number" -i "$sync_state_file"
yq eval ".issue_mappings.\"$ISSUE_ID\".mr_created = \"$current_datetime\"" -i "$sync_state_file"

# Cleanup backup if successful
if [ $? -eq 0 ]; then
  rm -f "${sync_state_file}.bak"
  echo "✅ Updated sync-state.yaml with MR information"
else
  # Restore backup on failure
  mv "${sync_state_file}.bak" "$sync_state_file"
  echo "⚠️  Failed to update sync-state.yaml, restored backup"
fi
echo ""

# Final summary
echo "🎉 $platform_type Created Successfully!"
echo "=================================="
echo ""
echo "🔗 $platform_type: $mr_url"
echo "   • Number: #$mr_number"
echo "   • Title: Issue #$issue_number: $issue_title"
echo "   • Source: $issue_branch"
echo "   • Target: $epic_branch"
echo ""
echo "📁 Updated: $sync_state_file"
echo ""
echo "🔗 Next Steps:"
echo "   • Review and provide feedback on the MR/PR"
echo "   • Use /cccc:issue:update $EPIC_NAME $ISSUE_ID to sync comments (if needed)"
echo "   • Merge when ready"

exit 0