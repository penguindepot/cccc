#!/bin/bash
# epic-archive.sh - Archive a completed epic by closing all issues and moving documents

set -e  # Exit on any error

EPIC_NAME="$1"
FORCE_OR_DRY_RUN="$2"
ADDITIONAL_FLAG="$3"

# Parse flags
DRY_RUN_MODE=false
FORCE_MODE=false

if [ "$FORCE_OR_DRY_RUN" = "--dry-run" ] || [ "$ADDITIONAL_FLAG" = "--dry-run" ]; then
    DRY_RUN_MODE=true
fi

if [ "$FORCE_OR_DRY_RUN" = "--force" ] || [ "$ADDITIONAL_FLAG" = "--force" ]; then
    FORCE_MODE=true
fi

if [ -z "$EPIC_NAME" ]; then
    echo "❌ Usage: $0 <epic_name> [--force] [--dry-run]"
    exit 1
fi

# Get current datetime and platform info
current_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)
git_remote=$(yq '.git_remote // "origin"' .cccc/cccc-config.yml)
sync_state_file=".cccc/epics/$EPIC_NAME/sync-state.yaml"
analysis_file=".cccc/epics/$EPIC_NAME/analysis.yaml"

# Validate epic exists before starting
if [ ! -f "$sync_state_file" ]; then
    echo "❌ Epic not found: $EPIC_NAME"
    echo "Sync state file missing: $sync_state_file"
    echo "Available epics:"
    ls -1 .cccc/epics/ 2>/dev/null | head -10 || echo "  (no epics found)"
    exit 1
fi

if [ ! -f "$analysis_file" ]; then
    echo "❌ Epic analysis not found: $EPIC_NAME"
    echo "Analysis file missing: $analysis_file"
    echo "Run: /cccc:epic:analyze $EPIC_NAME"
    exit 1
fi

echo "🗄️ ${DRY_RUN_MODE:+DRY-RUN: }Starting epic archive for $EPIC_NAME..."

# Platform API functions for closing issues
close_issue_gitlab() {
    local issue_number="$1"
    local comment="$2"
    
    if [ "$DRY_RUN_MODE" = true ]; then
        echo "    [DRY-RUN] Would close GitLab issue #$issue_number"
        return 0
    fi
    
    # Add closing comment first
    if [ -n "$comment" ]; then
        glab api "projects/:id/issues/$issue_number/notes" -X POST --field "body=$comment" >/dev/null 2>&1
    fi
    
    # Close the issue
    local result=$(glab api "projects/:id/issues/$issue_number" -X PUT --field "state_event=close" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

close_issue_github() {
    local issue_number="$1"
    local comment="$2"
    
    if [ "$DRY_RUN_MODE" = true ]; then
        echo "    [DRY-RUN] Would close GitHub issue #$issue_number"
        return 0
    fi
    
    # Add closing comment first
    if [ -n "$comment" ]; then
        gh api "repos/:owner/:repo/issues/$issue_number/comments" -X POST --field "body=$comment" >/dev/null 2>&1
    fi
    
    # Close the issue
    local result=$(gh api "repos/:owner/:repo/issues/$issue_number" -X PATCH --field "state=closed" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

get_issue_status_gitlab() {
    local issue_number="$1"
    local result=$(glab api "projects/:id/issues/$issue_number" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result" | jq -r '.state'
        return 0
    else
        echo "api_error"
        return 1
    fi
}

get_issue_status_github() {
    local issue_number="$1"
    local result=$(gh api "repos/:owner/:repo/issues/$issue_number" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result" | jq -r '.state'
        return 0
    else
        echo "api_error"
        return 1
    fi
}

# Analyze current epic status
echo "  📊 Analyzing epic status..."

# Get epic issue number
epic_number=$(yq ".epic_number" "$sync_state_file")
epic_url=$(yq -r ".epic_url" "$sync_state_file")

# Get all issue IDs and analyze their status
issue_ids=$(yq '.issue_mappings | keys | .[]' "$sync_state_file" | tr -d '"')
total_issues=0
closed_issues=0
open_issues=0
api_errors=0
open_issue_list=""

for issue_id in $issue_ids; do
    total_issues=$((total_issues + 1))
    issue_number=$(yq ".issue_mappings.\"$issue_id\".number" "$sync_state_file")
    issue_title=$(yq -r ".issue_mappings.\"$issue_id\".title" "$sync_state_file")
    
    # Check current status
    if [[ "$git_platform" == "gitlab" ]]; then
        current_status=$(get_issue_status_gitlab "$issue_number")
    else
        current_status=$(get_issue_status_github "$issue_number")
    fi
    
    if [ "$current_status" = "api_error" ]; then
        api_errors=$((api_errors + 1))
        echo "  ⚠️  Could not check status of issue #$issue_number"
    elif [ "$current_status" = "closed" ]; then
        closed_issues=$((closed_issues + 1))
    else
        open_issues=$((open_issues + 1))
        open_issue_list="$open_issue_list\n    - Issue #$issue_number: $issue_title"
    fi
done

echo "  ✅"
echo "  🔍 Found $total_issues issues: $closed_issues closed, $open_issues open"

if [ $api_errors -gt 0 ]; then
    echo "  ⚠️  $api_errors issues could not be checked (API errors)"
    if [ "$FORCE_MODE" != true ] && [ "$DRY_RUN_MODE" != true ]; then
        echo "❌ Cannot proceed with API errors. Use --force to continue anyway."
        exit 1
    fi
fi

# Show what would be done in dry-run mode
if [ "$DRY_RUN_MODE" = true ]; then
    echo ""
    echo "📋 Would perform these actions:"
    if [ $open_issues -gt 0 ]; then
        echo "  ❌ Close open issues:"
        echo -e "$open_issue_list"
    fi
    echo "  ❌ Close epic issue #$epic_number: Epic: $EPIC_NAME"
    
    # Check if worktree exists
    worktree_path="../epic-$EPIC_NAME"
    if [ -d "$worktree_path" ]; then
        echo "  ❌ Remove worktree: $worktree_path"
        
        # Count branches that would be deleted
        cd "$worktree_path" 2>/dev/null || true
        branch_count=$(git branch -r | grep -E "(epic/$EPIC_NAME|issue/)" | wc -l | xargs)
        cd - >/dev/null 2>&1 || true
        
        echo "  ❌ Delete $branch_count remote branches"
    else
        echo "  ⚠️  Worktree not found: $worktree_path"
    fi
    
    # Count files that would be moved
    epic_files=$(find ".cccc/epics/$EPIC_NAME" -type f | wc -l | xargs)
    prd_file_count=0
    if [ -f ".cccc/prds/$EPIC_NAME.md" ]; then
        prd_file_count=1
    fi
    
    echo "  ❌ Move .cccc/epics/$EPIC_NAME → .cccc_frozen/epics/$EPIC_NAME"
    if [ $prd_file_count -gt 0 ]; then
        echo "  ❌ Move .cccc/prds/$EPIC_NAME.md → .cccc_frozen/prds/$EPIC_NAME.md"
    fi
    echo "  ❌ Create archive metadata file"
    
    echo ""
    echo "📊 Summary:"
    echo "  - Epic: $EPIC_NAME ($total_issues issues)"
    echo "  - Open issues to close: $open_issues"
    echo "  - Files to archive: $((epic_files + prd_file_count))"
    echo "  - Branches to delete: ~$((total_issues + 1))"
    
    exit 0
fi

# Confirmation prompt (unless force mode)
if [ "$FORCE_MODE" != true ]; then
    echo ""
    echo "⚠️ This will permanently:"
    if [ $open_issues -gt 0 ]; then
        echo "  - Close $open_issues open issues on the platform"
        echo -e "$open_issue_list"
    fi
    echo "  - Close epic issue #$epic_number on the platform"
    echo "  - Delete the ../epic-$EPIC_NAME worktree"
    echo "  - Delete ~$((total_issues + 1)) remote branches"
    echo "  - Move all files to .cccc_frozen"
    echo ""
    
    read -p "❓ Continue with archive? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "❌ Archive cancelled by user"
        echo "💡 Use --force to skip confirmation or --dry-run to preview"
        exit 1
    fi
fi

# Start the actual archive process
archive_metadata=""
closed_issue_count=0
branches_deleted=()

# Close open issues
if [ $open_issues -gt 0 ]; then
    echo "  📝 Closing remaining open issues..."
    
    for issue_id in $issue_ids; do
        issue_number=$(yq ".issue_mappings.\"$issue_id\".number" "$sync_state_file")
        issue_title=$(yq -r ".issue_mappings.\"$issue_id\".title" "$sync_state_file")
        
        # Check if issue is open
        if [[ "$git_platform" == "gitlab" ]]; then
            current_status=$(get_issue_status_gitlab "$issue_number")
        else
            current_status=$(get_issue_status_github "$issue_number")
        fi
        
        if [ "$current_status" != "closed" ] && [ "$current_status" != "api_error" ]; then
            echo "    - Closing issue #$issue_number: $issue_title..."
            
            close_comment="🗄️ Archived as part of epic completion on $current_datetime"
            
            if [[ "$git_platform" == "gitlab" ]]; then
                close_success=$(close_issue_gitlab "$issue_number" "$close_comment" && echo "true" || echo "false")
            else
                close_success=$(close_issue_github "$issue_number" "$close_comment" && echo "true" || echo "false")
            fi
            
            if [ "$close_success" = "true" ]; then
                echo "    ✅"
                closed_issue_count=$((closed_issue_count + 1))
                
                # Update sync state with closure
                yq eval ".issue_mappings.\"$issue_id\".status = \"closed\"" -i "$sync_state_file"
                yq eval ".issue_mappings.\"$issue_id\".closed_at = \"$current_datetime\"" -i "$sync_state_file"
                yq eval ".issue_mappings.\"$issue_id\".closure_reason = \"archived\"" -i "$sync_state_file"
            else
                echo "    ❌ Failed to close issue #$issue_number"
                if [ "$FORCE_MODE" != true ]; then
                    echo "❌ Issue closing failed. Use --force to continue anyway."
                    exit 1
                fi
            fi
        fi
    done
fi

# Close the epic issue
echo "  📝 Closing epic issue #$epic_number..."
close_comment="🗄️ Epic archived on $current_datetime

📊 **Archive Summary:**
- Total Issues: $total_issues
- Completed Issues: $closed_issues
- Auto-closed Issues: $closed_issue_count
- Archive Location: \`.cccc_frozen/epics/$EPIC_NAME\`

All work has been completed and the epic is now archived."

if [[ "$git_platform" == "gitlab" ]]; then
    epic_close_success=$(close_issue_gitlab "$epic_number" "$close_comment" && echo "true" || echo "false")
else
    epic_close_success=$(close_issue_github "$epic_number" "$close_comment" && echo "true" || echo "false")
fi

if [ "$epic_close_success" = "true" ]; then
    echo "  ✅"
else
    echo "  ❌ Failed to close epic issue"
    if [ "$FORCE_MODE" != true ]; then
        echo "❌ Epic closing failed. Use --force to continue anyway."
        exit 1
    fi
fi

# Remove worktree and branches
worktree_path="../epic-$EPIC_NAME"
if [ -d "$worktree_path" ] && git worktree list | grep -q "$worktree_path"; then
    echo "  🌿 Removing worktree $worktree_path..."
    
    # Navigate to worktree to collect branch information
    cd "$worktree_path"
    
    # Collect all branches for deletion
    epic_branch="epic/$EPIC_NAME"
    remote_branches=$(git branch -r | grep -E "(${epic_branch}|issue/)" | sed 's|.*origin/||' | tr '\n' ' ')
    
    # Switch to main before deleting branches
    git checkout main >/dev/null 2>&1 || true
    git fetch "$git_remote" >/dev/null 2>&1 || true
    
    cd - >/dev/null
    
    # Remove the worktree
    git worktree remove "$worktree_path" --force >/dev/null 2>&1
    echo "  ✅"
    
    # Delete remote branches
    echo "  🌐 Deleting remote branches..."
    for branch in $remote_branches; do
        if [ -n "$branch" ]; then
            if git push "$git_remote" --delete "$branch" >/dev/null 2>&1; then
                branches_deleted+=("$branch")
                echo "    - Deleted $branch ✅"
            else
                echo "    - Failed to delete $branch ⚠️"
            fi
        fi
    done
else
    echo "  ⚠️ Worktree not found or already removed"
fi

# Create archive directories
echo "  📁 Creating archive directories..."
mkdir -p .cccc_frozen/epics
mkdir -p .cccc_frozen/prds
echo "  ✅"

# Move epic files to archive
echo "  🗄️ Moving epic files to .cccc_frozen/epics/$EPIC_NAME..."
if [ -d ".cccc/epics/$EPIC_NAME" ]; then
    mv ".cccc/epics/$EPIC_NAME" ".cccc_frozen/epics/$EPIC_NAME"
    echo "  ✅"
else
    echo "  ⚠️ Epic directory not found"
fi

# Move PRD file to archive
echo "  📄 Moving PRD file to .cccc_frozen/prds/$EPIC_NAME.md..."
if [ -f ".cccc/prds/$EPIC_NAME.md" ]; then
    mv ".cccc/prds/$EPIC_NAME.md" ".cccc_frozen/prds/$EPIC_NAME.md"
    echo "  ✅"
else
    echo "  ⚠️ PRD file not found"
fi

# Create archive metadata
echo "  📊 Creating archive metadata..."
cat > ".cccc_frozen/epics/$EPIC_NAME/archive-metadata.yaml" << EOF
# Archive metadata for epic $EPIC_NAME
archived_at: $current_datetime
archived_by: cccc:epic:archive
epic_number: $epic_number
epic_url: $epic_url
total_issues: $total_issues
completed_issues: $closed_issues
auto_closed_issues: $closed_issue_count
worktree_removed: true
branches_deleted:
EOF

# Add deleted branches to metadata
for branch in "${branches_deleted[@]}"; do
    echo "  - $branch" >> ".cccc_frozen/epics/$EPIC_NAME/archive-metadata.yaml"
done

cat >> ".cccc_frozen/epics/$EPIC_NAME/archive-metadata.yaml" << EOF
final_status: archived
git_platform: $git_platform
EOF

echo "  ✅"

echo ""
echo "ARCHIVE_COMPLETED=true"
echo "ARCHIVE_SUMMARY:"
echo "📋 Archive Summary:"
echo "  - Epic: $EPIC_NAME (issue #$epic_number)"
echo "  - Issues: $total_issues total ($closed_issues were already closed, $closed_issue_count auto-closed)"
echo "  - PRD: Moved to .cccc_frozen/prds/$EPIC_NAME.md"
echo "  - Epic Data: Moved to .cccc_frozen/epics/$EPIC_NAME/"
echo "  - Worktree: $worktree_path (removed)"
echo "  - Branches: ${#branches_deleted[@]} branches deleted"
echo "  - Status: Archived at $current_datetime"