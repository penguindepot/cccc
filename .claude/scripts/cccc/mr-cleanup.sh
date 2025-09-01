#!/bin/bash
# mr-cleanup.sh - Clean up local and remote branches after MR merge

set -e  # Exit on any error

EPIC_NAME="$1"
ISSUE_ID="$2"
FORCE_FLAG="$3"

if [ -z "$EPIC_NAME" ] || [ -z "$ISSUE_ID" ]; then
    echo "❌ Usage: $0 <epic_name> <issue_id> [--force]"
    exit 1
fi

echo "🧹 Starting MR cleanup for issue $ISSUE_ID..."

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

# Check if MR exists
if [ "$mr_number" = "null" ] || [ -z "$mr_number" ] || [ "$mr_url" = "null" ]; then
    echo "❌ No merge request found for issue $ISSUE_ID"
    echo "Nothing to clean up - no MR was created for this issue"
    
    # Only clean up local branch if it exists
    issue_branch="issue/$ISSUE_ID"
    worktree_path="../epic-$EPIC_NAME"
    
    if [ -d "$worktree_path" ]; then
        cd "$worktree_path" 2>/dev/null || true
        if git branch | grep -q "$issue_branch" 2>/dev/null; then
            echo ""
            echo "💡 Found local issue branch without MR. Clean up manually:"
            echo "   cd $worktree_path"
            echo "   git checkout main"
            echo "   git branch -D $issue_branch"
        fi
        cd - >/dev/null 2>&1 || true
    fi
    
    exit 1
fi

# Check for epic worktree
worktree_path="../epic-$EPIC_NAME"
if ! git worktree list | grep -q "$worktree_path"; then
    echo "❌ Epic worktree not found: $worktree_path"
    echo "Nothing to clean up - worktree doesn't exist"
    exit 1
fi

# Navigate to epic worktree
cd "$worktree_path" || {
    echo "❌ Failed to navigate to worktree: $worktree_path"
    exit 1
}

# Check if issue branch exists locally
issue_branch="issue/$ISSUE_ID"
if ! git branch | grep -q "$issue_branch"; then
    echo "⚠️  Issue branch not found locally: $issue_branch"
    echo "Branch may have already been cleaned up"
    
    # Still try to clean up remote and update sync state
    echo "  🌐 Checking for remote branch to clean up..."
    
    # Check if remote branch exists
    if git ls-remote --heads "$git_remote" "$issue_branch" | grep -q "$issue_branch"; then
        echo "  🗑️  Deleting remote branch $issue_branch..."
        if git push "$git_remote" --delete "$issue_branch" >/dev/null 2>&1; then
            echo "  ✅ Remote branch deleted"
        else
            echo "  ⚠️  Failed to delete remote branch (may not have permission)"
        fi
    else
        echo "  ✅ Remote branch doesn't exist"
    fi
    
    # Update sync state
    echo "  📊 Updating sync-state with cleanup status..."
    if [ -f "../$sync_state_file" ]; then
        cd - >/dev/null
        cp "$sync_state_file" "${sync_state_file}.bak"
        yq eval ".issue_mappings.\"$ISSUE_ID\".cleanup_completed_at = \"$current_datetime\"" -i "$sync_state_file"
        yq eval ".issue_mappings.\"$ISSUE_ID\".cleanup_status = \"partial_remote_only\"" -i "$sync_state_file"
        rm -f "${sync_state_file}.bak"
        echo "  ✅ Updated sync-state"
    fi
    
    echo ""
    echo "CLEANUP_COMPLETED=true"
    echo "CLEANUP_SUMMARY:"
    echo "📋 Cleanup Summary:"
    echo "  - Issue: $ISSUE_ID - $issue_title"
    echo "  - MR: #$mr_number"
    echo "  - Local Branch: $issue_branch (was already missing)"
    echo "  - Remote Branch: cleaned up if it existed"
    echo "  - Status: Partial cleanup completed at $current_datetime"
    exit 0
fi

# Verify MR is merged (unless force flag is used)
if [ "$FORCE_FLAG" != "--force" ]; then
    echo "  🔍 Verifying MR #$mr_number is merged..."
    
    # Check MR status via platform CLI
    mr_merged=false
    
    if [[ "$git_platform" == "gitlab" ]]; then
        # Get GitLab MR state - try glab mr view first, then API if needed
        mr_state=$(glab mr view "$mr_number" --output json 2>/dev/null | yq -p json '.state' 2>/dev/null || echo "unknown")
        if [ "$mr_state" = "unknown" ]; then
            # Fallback to direct API call with error handling
            project_path=$(yq -r '.project_path' .cccc/cccc-config.yml)
            if [ "$project_path" != "null" ] && [ -n "$project_path" ]; then
                mr_state=$(glab api "projects/$project_path/merge_requests/$mr_number" --jq '.state' 2>/dev/null || echo "unknown")
            fi
        fi
        
        if [ "$mr_state" = "merged" ]; then
            mr_merged=true
            merged_at=$(glab mr view "$mr_number" --output json 2>/dev/null | yq -p json '.merged_at' 2>/dev/null || echo "unknown")
            if [ "$merged_at" = "unknown" ] && [ "$project_path" != "null" ]; then
                merged_at=$(glab api "projects/$project_path/merge_requests/$mr_number" --jq '.merged_at' 2>/dev/null || echo "unknown")
            fi
        fi
    else
        # Get GitHub PR state
        pr_state=$(gh api "repos/:owner/:repo/pulls/$mr_number" --jq '.state' 2>/dev/null || echo "unknown")
        pr_merged=$(gh api "repos/:owner/:repo/pulls/$mr_number" --jq '.merged' 2>/dev/null || echo "false")
        if [ "$pr_state" = "closed" ] && [ "$pr_merged" = "true" ]; then
            mr_merged=true
            merged_at=$(gh api "repos/:owner/:repo/pulls/$mr_number" --jq '.merged_at' 2>/dev/null || echo "unknown")
        fi
    fi
    
    if [ "$mr_merged" = "false" ]; then
        echo "  ❌"
        echo ""
        if [ "$mr_state" = "unknown" ]; then
            echo "❌ Unable to verify MR status"
            echo "  - MR: #$mr_number"
            echo "  - URL: $mr_url"
            echo "  - This could mean:"
            echo "    • GitLab CLI authentication issues"
            echo "    • MR was deleted or doesn't exist"
            echo "    • Network connectivity problems"
            echo "  - Use --force to cleanup anyway (if you're certain MR is merged)"
        else
            echo "❌ MR is not merged yet"
            echo "  - Status: $mr_state"
            echo "  - MR: $mr_url"
            echo "  - Use --force to cleanup anyway (not recommended)"
        fi
        echo ""
        echo "💡 Wait for MR to be merged, then run cleanup again."
        exit 1
    fi
    
    echo "  ✅"
else
    echo "  ⚠️  Force mode enabled - skipping merge verification"
    merged_at="unknown (forced cleanup)"
fi

# Fetch latest from remote
echo "  📥 Fetching latest changes..."
git fetch "$git_remote" >/dev/null 2>&1 || {
    echo "  ⚠️  Failed to fetch from remote (continuing anyway)"
}

# Switch away from issue branch if we're on it
current_branch=$(git branch --show-current)
if [ "$current_branch" = "$issue_branch" ]; then
    echo "  🌿 Switching away from issue branch..."
    
    # Try to switch to epic branch first, then main
    epic_branch="epic/$EPIC_NAME"
    if git branch | grep -q "$epic_branch"; then
        git checkout "$epic_branch" >/dev/null 2>&1 || {
            git checkout main >/dev/null 2>&1 || {
                echo "  ❌ Failed to switch away from issue branch"
                exit 1
            }
        }
    else
        git checkout main >/dev/null 2>&1 || {
            echo "  ❌ Failed to switch to main branch"
            exit 1
        }
    fi
    echo "  ✅"
else
    echo "  ✅ Already on different branch ($current_branch)"
fi

# Check for unpushed commits
echo "  🔍 Checking for unpushed commits..."
if git log "$git_remote/$issue_branch..$issue_branch" --oneline 2>/dev/null | grep -q .; then
    if [ "$FORCE_FLAG" != "--force" ]; then
        echo "  ❌"
        echo ""
        echo "⚠️  Issue branch has unpushed commits!"
        echo "  - Branch: $issue_branch"
        echo "  - Unpushed commits exist"
        echo "  - Use --force to delete anyway (will lose commits)"
        echo ""
        echo "💡 Push commits first or use --force if you're certain."
        exit 1
    else
        echo "  ⚠️  Force mode: ignoring unpushed commits"
    fi
else
    echo "  ✅ No unpushed commits"
fi

# Delete local issue branch
echo "  🗑️  Deleting local branch $issue_branch..."
if git branch -D "$issue_branch" >/dev/null 2>&1; then
    echo "  ✅"
else
    echo "  ❌ Failed to delete local branch"
    exit 1
fi

# Delete remote branch if it exists
echo "  🌐 Deleting remote branch $issue_branch..."
if git ls-remote --heads "$git_remote" "$issue_branch" | grep -q "$issue_branch"; then
    if git push "$git_remote" --delete "$issue_branch" >/dev/null 2>&1; then
        echo "  ✅"
    else
        echo "  ⚠️  Failed to delete remote branch (may not have permission)"
    fi
else
    echo "  ✅ Remote branch doesn't exist"
fi

# Return to original directory
cd - >/dev/null

# Update sync-state with cleanup completion
echo "  📊 Updating sync-state with cleanup status..."
if [ -f "$sync_state_file" ]; then
    cp "$sync_state_file" "${sync_state_file}.bak"
    yq eval ".issue_mappings.\"$ISSUE_ID\".cleanup_completed_at = \"$current_datetime\"" -i "$sync_state_file"
    yq eval ".issue_mappings.\"$ISSUE_ID\".cleanup_status = \"completed\"" -i "$sync_state_file"
    yq eval ".issue_mappings.\"$ISSUE_ID\".mr_merged_at = \"$merged_at\"" -i "$sync_state_file"
    
    if [ $? -eq 0 ]; then
        rm -f "${sync_state_file}.bak"
        echo "  ✅"
    else
        mv "${sync_state_file}.bak" "$sync_state_file"
        echo "  ⚠️  Failed to update sync-state, restored backup"
    fi
else
    echo "  ⚠️  Sync-state file not found, skipping update"
fi

echo ""
echo "CLEANUP_COMPLETED=true"
echo "CLEANUP_SUMMARY:"
echo "📋 Cleanup Summary:"
echo "  - Issue: $ISSUE_ID - $issue_title"

if [ "$FORCE_FLAG" = "--force" ]; then
    echo "  - MR: #$mr_number (status unknown - forced cleanup)"
else
    echo "  - MR: #$mr_number (merged at $merged_at)"
fi

echo "  - Local Branch: $issue_branch (deleted)"
echo "  - Remote Branch: $git_remote/$issue_branch (deleted)"
echo "  - Worktree: $worktree_path (preserved)"

if [ "$FORCE_FLAG" = "--force" ]; then
    echo "  - Status: Force cleanup completed at $current_datetime"
else
    echo "  - Status: Cleanup completed at $current_datetime"
fi