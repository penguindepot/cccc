#!/bin/bash
# epic-next-issue.sh - Analyze dependencies and determine next actionable issues

set -e  # Exit on any error

# Require yq for YAML parsing
command -v yq >/dev/null 2>&1 || {
    echo "❌ yq is required for YAML parsing. Install with:"
    echo "   macOS: brew install yq"
    echo "   Linux: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq"
    exit 1
}

# YAML parsing functions using yq
get_issue_ids() {
    yq '.issues | keys | .[]' "$1" | tr -d '"'
}

get_issue_field() {
    local yaml_file="$1"
    local issue_id="$2"
    local field="$3"
    yq ".issues.\"$issue_id\".$field" "$yaml_file" | tr -d '"'
}

get_issue_dependencies() {
    local yaml_file="$1"
    local issue_id="$2"
    yq ".issues.\"$issue_id\".depends_on | .[]" "$yaml_file" 2>/dev/null | tr -d '"' || echo ""
}

get_issue_conflicts() {
    local yaml_file="$1"
    local issue_id="$2"
    yq ".issues.\"$issue_id\".conflicts_with | .[]" "$yaml_file" 2>/dev/null | tr -d '"' || echo ""
}

# Platform API functions
get_issue_status_gitlab() {
    local issue_number="$1"
    glab api "projects/:id/issues/$issue_number" 2>/dev/null | jq -r '.state' || echo "unknown"
}

get_issue_status_github() {
    local issue_number="$1"
    gh api "repos/:owner/:repo/issues/$issue_number" 2>/dev/null | jq -r '.state' || echo "unknown"
}

# Update sync-state.yaml with current issue statuses
update_issue_statuses() {
    local epic_name="$1"
    local sync_state_file=".cccc/epics/$epic_name/sync-state.yaml"
    local git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)
    local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "🔄 Updating issue statuses from $git_platform..."
    
    # Create temporary file for updates
    local temp_file="/tmp/sync-state-updated.yaml"
    cp "$sync_state_file" "$temp_file"
    
    # Get all issue IDs from sync state
    local issue_ids=$(yq '.issue_mappings | keys | .[]' "$sync_state_file" | tr -d '"')
    
    for issue_id in $issue_ids; do
        local issue_number=$(yq ".issue_mappings.\"$issue_id\".number" "$sync_state_file")
        local current_status
        
        if [[ "$git_platform" == "gitlab" ]]; then
            current_status=$(get_issue_status_gitlab "$issue_number")
        else
            current_status=$(get_issue_status_github "$issue_number")
        fi
        
        # Update status in temp file
        yq -i ".issue_mappings.\"$issue_id\".status = \"$current_status\"" "$temp_file"
        
        # If status changed to closed, add completion timestamp
        if [[ "$current_status" == "closed" ]]; then
            local existing_completed=$(yq ".issue_mappings.\"$issue_id\".completed_at" "$sync_state_file" 2>/dev/null || echo "null")
            if [[ "$existing_completed" == "null" ]]; then
                yq -i ".issue_mappings.\"$issue_id\".completed_at = \"$current_date\"" "$temp_file"
            fi
        fi
        
        echo "  ✅ #$issue_number: $current_status"
    done
    
    # Add last status update timestamp
    yq -i ".last_status_update = \"$current_date\"" "$temp_file"
    
    # Replace original file
    mv "$temp_file" "$sync_state_file"
    
    echo "✅ Issue statuses updated"
}

# Analyze dependencies and determine next actionable issues
analyze_next_issues() {
    local epic_name="$1"
    local analysis_file=".cccc/epics/$epic_name/analysis.yaml"
    local sync_state_file=".cccc/epics/$epic_name/sync-state.yaml"
    local epic_url=$(yq '.epic_url' "$sync_state_file")
    
    echo "🎯 Next Issues for Epic: $epic_name"
    echo
    
    # Get all issues and their statuses
    local ready_issues=()
    local blocked_issues=()
    local conflict_warnings=()
    local completed_count=0
    local total_count=0
    
    while IFS= read -r issue_id; do
        total_count=$((total_count + 1))
        
        local issue_number=$(yq ".issue_mappings.\"$issue_id\".number" "$sync_state_file")
        local title=$(yq ".issue_mappings.\"$issue_id\".title" "$sync_state_file" | tr -d '"')
        local status=$(yq ".issue_mappings.\"$issue_id\".status" "$sync_state_file" | tr -d '"')
        local phase=$(get_issue_field "$analysis_file" "$issue_id" "phase")
        local estimate=$(get_issue_field "$analysis_file" "$issue_id" "estimate_minutes")
        local url=$(yq ".issue_mappings.\"$issue_id\".url" "$sync_state_file" | tr -d '"')
        
        # Count completed issues
        if [[ "$status" == "closed" ]]; then
            completed_count=$((completed_count + 1))
            continue
        fi
        
        # Check if all dependencies are completed
        local deps=$(get_issue_dependencies "$analysis_file" "$issue_id")
        local all_deps_complete=true
        local blocking_deps=()
        
        if [[ -n "$deps" ]]; then
            for dep_id in $deps; do
                local dep_number=$(yq ".issue_mappings.\"$dep_id\".number" "$sync_state_file")
                local dep_status=$(yq ".issue_mappings.\"$dep_id\".status" "$sync_state_file" | tr -d '"')
                local dep_title=$(yq ".issue_mappings.\"$dep_id\".title" "$sync_state_file" | tr -d '"')
                
                if [[ "$dep_status" != "closed" ]]; then
                    all_deps_complete=false
                    blocking_deps+=("[$dep_id] #$dep_number - $dep_title ($dep_status)")
                fi
            done
        fi
        
        # Check for conflicts with open issues
        local conflicts=$(get_issue_conflicts "$analysis_file" "$issue_id")
        local conflict_issues=()
        
        if [[ -n "$conflicts" ]]; then
            for conflict_id in $conflicts; do
                local conflict_number=$(yq ".issue_mappings.\"$conflict_id\".number" "$sync_state_file")
                local conflict_status=$(yq ".issue_mappings.\"$conflict_id\".status" "$sync_state_file" | tr -d '"')
                local conflict_title=$(yq ".issue_mappings.\"$conflict_id\".title" "$sync_state_file" | tr -d '"')
                
                if [[ "$conflict_status" == "opened" ]]; then
                    conflict_issues+=("[$conflict_id] #$conflict_number - $conflict_title")
                fi
            done
        fi
        
        # Categorize the issue
        if [[ "$all_deps_complete" == true ]]; then
            ready_issues+=("$issue_id|$issue_number|$title|$phase|$estimate|$url")
            
            # Add conflict warning if any
            if [[ ${#conflict_issues[@]} -gt 0 ]]; then
                local conflict_list=$(printf ", %s" "${conflict_issues[@]}")
                conflict_list=${conflict_list:2} # Remove leading ", "
                conflict_warnings+=("[$issue_id] #$issue_number conflicts with: $conflict_list")
            fi
        else
            local blocking_list=$(printf "; %s" "${blocking_deps[@]}")
            blocking_list=${blocking_list:2} # Remove leading "; "
            blocked_issues+=("$issue_id|#$issue_number - $title|$blocking_list")
        fi
        
    done < <(get_issue_ids "$analysis_file")
    
    # Sort ready issues by phase, then by estimate
    if [[ ${#ready_issues[@]} -gt 0 ]]; then
        echo "✅ Ready to Start (no blockers):"
        printf '%s\n' "${ready_issues[@]}" | sort -t'|' -k4,4n -k5,5n | while IFS='|' read -r issue_id issue_number title phase estimate url; do
            echo "  [$issue_id] #$issue_number - $title (Phase $phase, ~${estimate}min)"
            echo "    🔗 $url"
        done
        echo
    else
        echo "❌ No issues ready to start"
        echo
    fi
    
    # Show blocked issues
    if [[ ${#blocked_issues[@]} -gt 0 ]]; then
        echo "⏸️ Blocked (waiting on dependencies):"
        for blocked in "${blocked_issues[@]}"; do
            local issue_id=${blocked%%|*}
            local remaining=${blocked#*|}
            local issue_info=${remaining%|*}
            local deps=${remaining#*|}
            echo "  [$issue_id] $issue_info"
            echo "    └─ Waiting on: $deps"
        done
        echo
    fi
    
    # Show conflict warnings
    if [[ ${#conflict_warnings[@]} -gt 0 ]]; then
        echo "⚠️ Conflicts to Consider:"
        for warning in "${conflict_warnings[@]}"; do
            echo "  $warning (avoid parallel work)"
        done
        echo
    fi
    
    # Show progress summary
    local progress_percent=$((completed_count * 100 / total_count))
    echo "📊 Progress: $completed_count/$total_count issues completed (${progress_percent}%)"
    echo "🔗 Epic: $epic_url"
    
    # Show recommendations
    if [[ ${#ready_issues[@]} -gt 0 ]]; then
        echo
        echo "💡 Recommendations:"
        echo "  1. Start with Phase 1 issues first for optimal workflow"
        echo "  2. Consider shorter tasks (~25-30min) for quick wins"
        echo "  3. Check conflict warnings before starting parallel work"
        echo "  4. Run '/cccc:epic:next-issue $epic_name' after completing issues"
    fi
}

# Main function
main() {
    local epic_name="$1"
    
    if [[ -z "$epic_name" ]]; then
        echo "Usage: $0 <epic_name>"
        exit 1
    fi
    
    # Update issue statuses from platform
    update_issue_statuses "$epic_name"
    echo
    
    # Analyze and show next actionable issues
    analyze_next_issues "$epic_name"
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi