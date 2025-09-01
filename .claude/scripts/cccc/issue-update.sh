#!/bin/bash
# issue-update.sh - Update local issue files from GitLab/GitHub API with comment processing

set -e  # Exit on any error

# Require dependencies
for cmd in yq jq; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "❌ $cmd is required for YAML/JSON parsing. Install with:"
        echo "   macOS: brew install $cmd"
        exit 1
    }
done

# GitLab API functions
get_issue_data_gitlab() {
    local issue_number="$1"
    local result=$(glab api "projects/:id/issues/$issue_number" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

get_issue_comments_gitlab() {
    local issue_number="$1"
    local result=$(glab api "projects/:id/issues/$issue_number/notes" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

post_comment_gitlab() {
    local issue_number="$1"
    local comment_body="$2"
    glab api "projects/:id/issues/$issue_number/notes" \
        --method POST \
        --field "body=$comment_body" >/dev/null 2>&1
}

# GitHub API functions
get_issue_data_github() {
    local issue_number="$1"
    local result=$(gh api "repos/:owner/:repo/issues/$issue_number" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

get_issue_comments_github() {
    local issue_number="$1"
    local result=$(gh api "repos/:owner/:repo/issues/$issue_number/comments" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

post_comment_github() {
    local issue_number="$1"
    local comment_body="$2"
    gh api "repos/:owner/:repo/issues/$issue_number/comments" \
        --method POST \
        --field "body=$comment_body" >/dev/null 2>&1
}

# Comment processing functions
process_structured_updates() {
    local comments_json="$1"
    local temp_updates="/tmp/structured_updates.yaml"
    
    # Initialize updates file
    echo "acceptance_updates: []" > "$temp_updates"
    echo "status_updates: []" >> "$temp_updates"
    echo "estimate_updates: []" >> "$temp_updates"
    echo "other_updates: []" >> "$temp_updates"
    echo "feedback_comments: []" >> "$temp_updates"
    
    local structured_count=0
    local feedback_count=0
    
    # Process each comment
    local comment_count=$(echo "$comments_json" | jq '. | length')
    
    for ((i = 0; i < comment_count; i++)); do
        local comment_body=$(echo "$comments_json" | jq -r ".[$i].body // .[$i].note")
        local comment_author=$(echo "$comments_json" | jq -r ".[$i].author.username // .[$i].user.login")
        local comment_date=$(echo "$comments_json" | jq -r ".[$i].created_at")
        
        # Skip system comments and empty comments
        [[ -z "$comment_body" || "$comment_body" == "null" ]] && continue
        
        # Check for structured updates
        if echo "$comment_body" | grep -q "^/update"; then
            structured_count=$((structured_count + 1))
            
            # Parse different update types
            while IFS= read -r line; do
                if [[ "$line" =~ ^/update[[:space:]]+acceptance:[[:space:]]*(.*) ]]; then
                    local acceptance_item="${BASH_REMATCH[1]}"
                    yq -i ".acceptance_updates += [\"$acceptance_item\"]" "$temp_updates"
                elif [[ "$line" =~ ^/update[[:space:]]+status:[[:space:]]*(.*) ]]; then
                    local status_update="${BASH_REMATCH[1]}"
                    yq -i ".status_updates += [\"$status_update\"]" "$temp_updates"
                elif [[ "$line" =~ ^/update[[:space:]]+estimate:[[:space:]]*(.*) ]]; then
                    local estimate_update="${BASH_REMATCH[1]}"
                    yq -i ".estimate_updates += [\"$estimate_update\"]" "$temp_updates"
                elif [[ "$line" =~ ^/update[[:space:]]+(.*):[[:space:]]*(.*) ]]; then
                    local update_key="${BASH_REMATCH[1]}"
                    local update_value="${BASH_REMATCH[2]}"
                    yq -i ".other_updates += [{\"key\": \"$update_key\", \"value\": \"$update_value\"}]" "$temp_updates"
                fi
            done <<< "$comment_body"
        else
            # Non-structured feedback
            feedback_count=$((feedback_count + 1))
            local feedback_entry="{\"author\": \"$comment_author\", \"date\": \"$comment_date\", \"body\": $(echo "$comment_body" | jq -R .)}"
            yq -i ".feedback_comments += [$feedback_entry]" "$temp_updates"
        fi
    done
    
    echo "$temp_updates:$structured_count:$feedback_count"
}

# Apply updates to issue markdown
apply_updates_to_issue() {
    local issue_file="$1"
    local updates_file="$2"
    local issue_title="$3"
    local issue_description="$4"
    
    # Create new issue content with latest data from platform
    cat > "$issue_file" << EOF
# Issue: $issue_title

## Overview
$issue_description

## Comments Processing Summary
$(date -u +"%Y-%m-%dT%H:%M:%SZ"): Updated from platform

### Structured Updates Applied:
EOF
    
    # Add acceptance updates if any
    local acceptance_updates=$(yq '.acceptance_updates | length' "$updates_file")
    if [[ $acceptance_updates -gt 0 ]]; then
        echo "" >> "$issue_file"
        echo "**Acceptance Criteria Updates:**" >> "$issue_file"
        yq -r '.acceptance_updates[]' "$updates_file" | while read -r update; do
            echo "- $update" >> "$issue_file"
        done
    fi
    
    # Add status updates if any
    local status_updates=$(yq '.status_updates | length' "$updates_file")
    if [[ $status_updates -gt 0 ]]; then
        echo "" >> "$issue_file"
        echo "**Status Updates:**" >> "$issue_file"
        yq -r '.status_updates[]' "$updates_file" | while read -r update; do
            echo "- Status: $update" >> "$issue_file"
        done
    fi
    
    # Add estimate updates if any
    local estimate_updates=$(yq '.estimate_updates | length' "$updates_file")
    if [[ $estimate_updates -gt 0 ]]; then
        echo "" >> "$issue_file"
        echo "**Estimate Updates:**" >> "$issue_file"
        yq -r '.estimate_updates[]' "$updates_file" | while read -r update; do
            echo "- Estimate: $update" >> "$issue_file"
        done
    fi
    
    # Add other updates if any
    local other_updates=$(yq '.other_updates | length' "$updates_file")
    if [[ $other_updates -gt 0 ]]; then
        echo "" >> "$issue_file"
        echo "**Other Updates:**" >> "$issue_file"
        yq -r '.other_updates[] | "- " + .key + ": " + .value' "$updates_file" >> "$issue_file"
    fi
    
    # Add feedback summary if any
    local feedback_count=$(yq '.feedback_comments | length' "$updates_file")
    if [[ $feedback_count -gt 0 ]]; then
        echo "" >> "$issue_file"
        echo "## Feedback Comments"
        echo "" >> "$issue_file"
        yq -r '.feedback_comments[] | "**" + .author + "** (" + .date + "):\n" + .body + "\n"' "$updates_file" >> "$issue_file"
    fi
    
    echo "" >> "$issue_file"
    echo "---" >> "$issue_file"
    echo "*Last updated from platform: $(date -u +"%Y-%m-%dT%H:%M:%SZ")*" >> "$issue_file"
}

# Generate update summary for posting back to platform
generate_update_summary() {
    local updates_file="$1"
    local structured_count="$2"
    local feedback_count="$3"
    local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat << EOF
## 🤖 CCCC Issue Update Summary

**Updated:** $current_date

**Changes Processed:**
- Structured updates: $structured_count
- Feedback comments: $feedback_count

**Local File Status:** ✅ Updated

This issue's local file has been synchronized with the latest platform content and comments.

---
*Generated by CCCC Issue Update System*
EOF
}

# Update single issue
update_single_issue() {
    local epic_name="$1"
    local issue_id="$2"
    local git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)
    local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Get issue number from sync state
    local issue_number=$(yq ".issue_mappings.\"$issue_id\".number" ".cccc/epics/$epic_name/sync-state.yaml")
    if [[ "$issue_number" == "null" || -z "$issue_number" ]]; then
        echo "❌ Issue number not found for $issue_id"
        return 1
    fi
    
    local issue_url=$(yq -r ".issue_mappings.\"$issue_id\".url" ".cccc/epics/$epic_name/sync-state.yaml")
    
    echo "🔄 Updating issue $issue_id from $git_platform..."
    
    # Fetch issue data
    local issue_data
    local comments_data
    
    if [[ "$git_platform" == "gitlab" ]]; then
        issue_data=$(get_issue_data_gitlab "$issue_number")
        comments_data=$(get_issue_comments_gitlab "$issue_number")
    else
        issue_data=$(get_issue_data_github "$issue_number")
        comments_data=$(get_issue_comments_github "$issue_number")
    fi
    
    if [[ $? -ne 0 ]]; then
        echo "  ❌ Failed to fetch issue data for #$issue_number"
        return 1
    fi
    
    # Extract issue details
    local issue_title=$(echo "$issue_data" | jq -r '.title')
    local issue_description=$(echo "$issue_data" | jq -r '.description // .body')
    local comment_count=$(echo "$comments_data" | jq '. | length')
    
    # Extract issue status
    local issue_status
    if [[ "$git_platform" == "gitlab" ]]; then
        issue_status=$(echo "$issue_data" | jq -r '.state')
        # GitLab uses "closed" or "opened"
    else
        issue_status=$(echo "$issue_data" | jq -r '.state')
        # GitHub uses "open" or "closed" - normalize to GitLab format
        if [[ "$issue_status" == "open" ]]; then
            issue_status="opened"
        fi
    fi
    
    echo "  📥 Fetched issue body and $comment_count comments"
    
    # Process comments for structured updates
    local process_result=$(process_structured_updates "$comments_data")
    local updates_file=$(echo "$process_result" | cut -d: -f1)
    local structured_count=$(echo "$process_result" | cut -d: -f2)
    local feedback_count=$(echo "$process_result" | cut -d: -f3)
    
    echo "  🔍 Processed $structured_count structured updates from comments"
    
    # Apply updates to local issue file
    local issue_file=".cccc/epics/$epic_name/issues/$issue_id.md"
    apply_updates_to_issue "$issue_file" "$updates_file" "$issue_title" "$issue_description"
    
    echo "  📝 Replaced local issue file with latest content"
    
    # Generate and post update summary if there were any updates
    if [[ $((structured_count + feedback_count)) -gt 0 ]]; then
        local update_summary=$(generate_update_summary "$updates_file" "$structured_count" "$feedback_count")
        
        if [[ "$git_platform" == "gitlab" ]]; then
            post_comment_gitlab "$issue_number" "$update_summary"
        else
            post_comment_github "$issue_number" "$update_summary"
        fi
        
        if [[ $? -eq 0 ]]; then
            echo "  💬 Posted update summary as new comment"
        else
            echo "  ⚠️ Failed to post update summary comment"
        fi
    fi
    
    # Update sync state
    local previous_status=$(yq ".issue_mappings.\"$issue_id\".status" ".cccc/epics/$epic_name/sync-state.yaml" 2>/dev/null | tr -d '"')
    yq -i ".issue_mappings.\"$issue_id\".last_updated = \"$current_date\"" ".cccc/epics/$epic_name/sync-state.yaml"
    yq -i ".issue_mappings.\"$issue_id\".status = \"$issue_status\"" ".cccc/epics/$epic_name/sync-state.yaml"
    
    # Add closed timestamp if status changed to closed
    if [[ "$issue_status" == "closed" && "$previous_status" != "closed" ]]; then
        local closed_at
        if [[ "$git_platform" == "gitlab" ]]; then
            closed_at=$(echo "$issue_data" | jq -r '.closed_at // empty')
        else
            closed_at=$(echo "$issue_data" | jq -r '.closed_at // empty')
        fi
        if [[ -n "$closed_at" && "$closed_at" != "null" ]]; then
            yq -i ".issue_mappings.\"$issue_id\".completed_at = \"$closed_at\"" ".cccc/epics/$epic_name/sync-state.yaml"
        fi
    fi
    
    # Cleanup temp files
    rm -f "$updates_file"
    
    # Show summary
    echo ""
    echo "📊 Update Summary:"
    echo "  - Issue: #$issue_number - $issue_title ($issue_status)"
    echo "  - Comments Processed: $comment_count ($structured_count structured, $feedback_count feedback)"
    echo "  - Local File Updated: ✅"
    echo "  - Platform Comment Posted: $([ $((structured_count + feedback_count)) -gt 0 ] && echo "✅" || echo "⏭️ (no updates to post)")"
    echo "  - Status: $([ "$previous_status" != "$issue_status" ] && echo "$previous_status → $issue_status" || echo "$issue_status")"
    echo "  - Last Sync: $current_date"
    echo ""
    echo "🔗 View Updated Issue: $issue_url"
    
    return 0
}

# Update all issues in epic
update_all_issues() {
    local epic_name="$1"
    local sync_state_file=".cccc/epics/$epic_name/sync-state.yaml"
    
    echo "🔄 Updating all issues in epic: $epic_name"
    echo ""
    
    # Get all issue IDs from sync state
    local issue_ids=$(yq '.issue_mappings | keys | .[]' "$sync_state_file" | tr -d '"')
    local total_issues=0
    local successful_updates=0
    local failed_updates=0
    
    for issue_id in $issue_ids; do
        total_issues=$((total_issues + 1))
        echo "[$total_issues] Processing issue: $issue_id"
        
        if update_single_issue "$epic_name" "$issue_id"; then
            successful_updates=$((successful_updates + 1))
        else
            failed_updates=$((failed_updates + 1))
        fi
        
        echo ""
    done
    
    # Final summary
    echo "🎯 Bulk Update Complete"
    echo ""
    echo "📊 Final Summary:"
    echo "  - Total Issues: $total_issues"
    echo "  - Successful Updates: $successful_updates"
    echo "  - Failed Updates: $failed_updates"
    echo "  - Success Rate: $((successful_updates * 100 / total_issues))%"
    
    return $failed_updates
}

# Main function
main() {
    local epic_name="$1"
    local issue_id_or_flag="$2"
    
    if [[ -z "$epic_name" ]]; then
        echo "Usage: $0 <epic_name> <issue_id|--all>"
        exit 1
    fi
    
    # Validate epic exists
    if [[ ! -f ".cccc/epics/$epic_name/sync-state.yaml" ]]; then
        echo "❌ Sync state not found for epic: $epic_name"
        echo "Run: /cccc:epic:sync $epic_name"
        exit 1
    fi
    
    # Determine operation mode
    if [[ "$issue_id_or_flag" == "--all" ]]; then
        update_all_issues "$epic_name"
    elif [[ -n "$issue_id_or_flag" ]]; then
        update_single_issue "$epic_name" "$issue_id_or_flag"
    else
        echo "Usage: $0 <epic_name> <issue_id|--all>"
        exit 1
    fi
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi