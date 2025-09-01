#!/bin/bash
# epic-update-status.sh - Update issue statuses from GitLab/GitHub API

set -e  # Exit on any error

# Require yq for YAML parsing
command -v yq >/dev/null 2>&1 || {
    echo "❌ yq is required for YAML parsing. Install with:"
    echo "   macOS: brew install yq"
    echo "   Linux: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq"
    exit 1
}

# Platform API functions
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

get_issue_closed_date_gitlab() {
    local issue_number="$1"
    local result=$(glab api "projects/:id/issues/$issue_number" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result" | jq -r '.closed_at // empty'
        return 0
    else
        return 1
    fi
}

get_issue_closed_date_github() {
    local issue_number="$1"
    local result=$(gh api "repos/:owner/:repo/issues/$issue_number" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result" | jq -r '.closed_at // empty'
        return 0
    else
        return 1
    fi
}

# Main status update function
update_epic_status() {
    local epic_name="$1"
    local sync_state_file=".cccc/epics/$epic_name/sync-state.yaml"
    local git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)
    local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "🔄 Updating issue statuses from $git_platform..."
    
    # Create backup of sync state
    local backup_file="${sync_state_file}.backup.$(date +%s)"
    cp "$sync_state_file" "$backup_file"
    
    # Create temporary file for updates
    local temp_file="/tmp/sync-state-updated.yaml"
    cp "$sync_state_file" "$temp_file"
    
    # Counters for summary
    local total_issues=0
    local completed_issues=0
    local api_errors=0
    local status_changes=0
    
    # Get all issue IDs from sync state
    local issue_ids=$(yq '.issue_mappings | keys | .[]' "$sync_state_file" | tr -d '"')
    
    for issue_id in $issue_ids; do
        total_issues=$((total_issues + 1))
        
        local issue_number=$(yq ".issue_mappings.\"$issue_id\".number" "$sync_state_file")
        local previous_status=$(yq ".issue_mappings.\"$issue_id\".status" "$sync_state_file" 2>/dev/null | tr -d '"')
        local current_status
        local closed_date=""
        
        # Get current status from API
        if [[ "$git_platform" == "gitlab" ]]; then
            current_status=$(get_issue_status_gitlab "$issue_number")
            if [[ "$current_status" == "closed" ]]; then
                closed_date=$(get_issue_closed_date_gitlab "$issue_number")
            fi
        else
            current_status=$(get_issue_status_github "$issue_number")
            if [[ "$current_status" == "closed" ]]; then
                closed_date=$(get_issue_closed_date_github "$issue_number")
            fi
        fi
        
        # Handle API errors
        if [[ "$current_status" == "api_error" ]]; then
            api_errors=$((api_errors + 1))
            if [[ "$previous_status" == "null" || -z "$previous_status" ]]; then
                current_status="opened"  # Default fallback
                echo "  ⚠️ #$issue_number: API error, defaulting to opened"
            else
                current_status="$previous_status"
                echo "  ⚠️ #$issue_number: API error, using cached status: $current_status"
            fi
        else
            # Check if status changed
            if [[ "$previous_status" != "$current_status" ]]; then
                status_changes=$((status_changes + 1))
            fi
            echo "  ✅ #$issue_number: $current_status"
        fi
        
        # Update status in temp file
        yq -i ".issue_mappings.\"$issue_id\".status = \"$current_status\"" "$temp_file"
        
        # Handle completion timestamp
        if [[ "$current_status" == "closed" ]]; then
            completed_issues=$((completed_issues + 1))
            
            # Check if we already have a completion timestamp
            local existing_completed=$(yq ".issue_mappings.\"$issue_id\".completed_at" "$sync_state_file" 2>/dev/null | tr -d '"')
            
            if [[ "$existing_completed" == "null" || -z "$existing_completed" ]]; then
                # Use API closed date or current timestamp
                local completion_date="${closed_date:-$current_date}"
                yq -i ".issue_mappings.\"$issue_id\".completed_at = \"$completion_date\"" "$temp_file"
                echo "    └─ Marked completed: $completion_date"
            fi
        else
            # If issue was reopened, clear completion timestamp
            local existing_completed=$(yq ".issue_mappings.\"$issue_id\".completed_at" "$sync_state_file" 2>/dev/null | tr -d '"')
            if [[ "$existing_completed" != "null" && -n "$existing_completed" ]]; then
                yq -i ".issue_mappings.\"$issue_id\".completed_at = null" "$temp_file"
                echo "    └─ Cleared completion timestamp (issue reopened)"
            fi
        fi
    done
    
    # Add last status update timestamp
    yq -i ".last_status_update = \"$current_date\"" "$temp_file"
    
    # Replace original file
    mv "$temp_file" "$sync_state_file"
    
    # Calculate progress
    local progress_percent=0
    if [[ $total_issues -gt 0 ]]; then
        progress_percent=$((completed_issues * 100 / total_issues))
    fi
    
    # Show summary
    echo
    echo "📊 Status Summary:"
    echo "  - Total Issues: $total_issues"
    echo "  - Completed: $completed_issues (${progress_percent}%)"
    echo "  - In Progress: $((total_issues - completed_issues)) ($((100 - progress_percent))%)"
    echo "  - Status Changes: $status_changes"
    if [[ $api_errors -gt 0 ]]; then
        echo "  - API Errors: $api_errors (using cached values)"
    fi
    echo "  - Last Updated: $current_date"
    
    # Success message
    if [[ $api_errors -eq 0 ]]; then
        echo
        echo "✅ Issue statuses updated successfully"
    else
        echo
        echo "⚠️ Issue statuses updated with some API errors"
        echo "   Backup saved to: $backup_file"
    fi
    
    # Show epic progress if substantial completion
    if [[ $completed_issues -gt 0 ]]; then
        echo
        echo "🎉 Progress Update:"
        echo "  Epic has $completed_issues completed issues"
        if [[ $progress_percent -ge 25 ]]; then
            echo "  🚀 Epic is ${progress_percent}% complete!"
        fi
        if [[ $progress_percent -ge 50 ]]; then
            echo "  🔥 Past halfway mark! Keep going!"
        fi
        if [[ $progress_percent -ge 90 ]]; then
            echo "  🏁 Almost done! Final sprint!"
        fi
    fi
    
    # Cleanup old backups (keep only last 5)
    local backup_dir=$(dirname "$sync_state_file")
    local backup_count=$(find "$backup_dir" -name "sync-state.yaml.backup.*" -type f | wc -l)
    if [[ $backup_count -gt 5 ]]; then
        find "$backup_dir" -name "sync-state.yaml.backup.*" -type f | sort | head -n $((backup_count - 5)) | xargs rm -f
    fi
}

# Main function
main() {
    local epic_name="$1"
    
    if [[ -z "$epic_name" ]]; then
        echo "Usage: $0 <epic_name>"
        exit 1
    fi
    
    # Validate epic exists
    if [[ ! -f ".cccc/epics/$epic_name/sync-state.yaml" ]]; then
        echo "❌ Sync state not found for epic: $epic_name"
        echo "Run: /cccc:epic:sync $epic_name"
        exit 1
    fi
    
    # Update all issue statuses
    update_epic_status "$epic_name"
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi