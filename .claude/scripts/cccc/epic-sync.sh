#!/bin/bash
# epic-sync.sh - Core logic for syncing epic to GitLab/GitHub with proper YAML parsing

set -e  # Exit on any error

# Require yq for YAML parsing
command -v yq >/dev/null 2>&1 || {
    echo "❌ yq is required for YAML parsing. Install with:"
    echo "   macOS: brew install yq"
    echo "   Linux: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq"
    exit 1
}

# YAML parsing functions using yq
get_issue_count() {
    yq '.stats.total_issues' "$1"
}

get_issue_ids() {
    yq '.issues | keys | .[]' "$1" | tr -d '"'
}

get_issue_field() {
    local yaml_file="$1"
    local issue_id="$2"
    local field="$3"
    yq ".issues.\"$issue_id\".$field" "$yaml_file" | tr -d '"'
}

get_stat_field() {
    local yaml_file="$1"
    local field="$2"
    yq ".stats.$field" "$yaml_file"
}

get_phase_issues() {
    local yaml_file="$1"
    local phase="$2"
    yq ".phases.\"$phase\" | .[]" "$yaml_file" | tr -d '"'
}

# Get dependencies as array
get_issue_dependencies() {
    local yaml_file="$1"
    local issue_id="$2"
    yq ".issues.\"$issue_id\".depends_on | .[]" "$yaml_file" 2>/dev/null | tr -d '"' || echo ""
}

# Main sync function
sync_epic() {
    local epic_name="$1"
    local analysis_file=".cccc/epics/$epic_name/analysis.yaml"
    local current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "🚀 Starting epic sync: $epic_name"
    
    # Validate analysis file exists
    if [[ ! -f "$analysis_file" ]]; then
        echo "❌ Analysis file not found: $analysis_file"
        echo "Run: /cccc:epic:analyze $epic_name"
        exit 1
    fi
    
    # Get platform from config
    local git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)
    local git_remote=$(yq '.git_remote // "origin"' .cccc/cccc-config.yml)
    
    echo "📊 Platform: $git_platform"
    
    # Validate CLI tool
    if [[ "$git_platform" == "gitlab" ]]; then
        command -v glab >/dev/null 2>&1 || {
            echo "❌ GitLab CLI not found. Install: brew install glab"
            exit 1
        }
        # Get project path
        project_path=$(glab api projects/:id 2>/dev/null | yq '.path_with_namespace' || echo "unknown/project")
    else
        command -v gh >/dev/null 2>&1 || {
            echo "❌ GitHub CLI not found. Install: brew install gh"
            exit 1
        }
        # Get repo
        repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "unknown/repo")
    fi
    
    # Get issue count and IDs using yq
    local issue_count=$(get_issue_count "$analysis_file")
    echo "📋 Found $issue_count issues to sync"
    
    # Check for existing sync
    if [[ -f ".cccc/epics/$epic_name/sync-state.yaml" ]]; then
        echo "⚠️ Epic already synced. Continue anyway? (y/n)"
        read -r confirm
        [[ "$confirm" != "y" ]] && { echo "❌ Sync cancelled"; exit 1; }
    fi
    
    # Create epic body
    local epic_content=$(sed '1,/^---$/d; 1,/^---$/d' ".cccc/epics/$epic_name/epic.md")
    local summary_content=""
    if [[ -f ".cccc/epics/$epic_name/issues/summary.md" ]]; then
        summary_content=$(cat ".cccc/epics/$epic_name/issues/summary.md")
    fi
    
    cat > /tmp/epic-body.md << EOF
$epic_content

---

## Epic Analysis Summary

$summary_content
EOF
    
    # Create epic issue
    echo "📝 Creating epic issue..."
    local epic_number epic_url
    if [[ "$git_platform" == "gitlab" ]]; then
        local epic_output=$(glab issue create \
            --title "Epic: $epic_name" \
            --description "$(cat /tmp/epic-body.md)" \
            --label "epic,epic:$epic_name" \
            --yes 2>&1)
        epic_number=$(echo "$epic_output" | grep -o '/issues/[0-9]*' | grep -o '[0-9]*')
        epic_url="https://gitlab.com/$project_path/-/issues/$epic_number"
    else
        epic_number=$(gh issue create \
            --title "Epic: $epic_name" \
            --body-file /tmp/epic-body.md \
            --label "epic,epic:$epic_name" \
            --json number -q .number)
        epic_url="https://github.com/$repo/issues/$epic_number"
    fi
    
    echo "✅ Created epic issue: #$epic_number"
    echo "Epic URL: $epic_url"
    
    # Pre-calculate issue numbers
    echo "🔢 Pre-calculating issue numbers..."
    local current_issue_num=$((epic_number + 1))
    
    # Create issue mapping
    > /tmp/issue-mapping.txt
    for issue_id in $(get_issue_ids "$analysis_file"); do
        echo "$issue_id:$current_issue_num" >> /tmp/issue-mapping.txt
        current_issue_num=$((current_issue_num + 1))
    done
    
    echo "📋 Pre-calculated issue numbers: #$((epic_number + 1)) to #$((current_issue_num - 1))"
    
    # Create issues with cross-references
    echo "🔨 Creating individual issues..."
    while IFS=':' read -r issue_id issue_number; do
        echo "Creating issue $issue_id → #$issue_number"
        
        # Extract issue data using yq
        local title=$(get_issue_field "$analysis_file" "$issue_id" "title")
        local phase=$(get_issue_field "$analysis_file" "$issue_id" "phase")
        
        # Read issue body
        local body_file=".cccc/epics/$epic_name/issues/$issue_id.md"
        local issue_body
        if [[ -f "$body_file" ]]; then
            issue_body=$(cat "$body_file")
        else
            issue_body="# Issue $issue_id: $title\n\nImplementation details to be added."
        fi
        
        # Build cross-references from dependencies
        local cross_refs=""
        local deps=$(get_issue_dependencies "$analysis_file" "$issue_id")
        if [[ -n "$deps" ]]; then
            for dep_id in $deps; do
                local dep_number=$(grep "^$dep_id:" /tmp/issue-mapping.txt | cut -d: -f2)
                if [[ -n "$dep_number" ]]; then
                    cross_refs="${cross_refs}\nDepends on #$dep_number"
                fi
            done
        fi
        
        # Create final body with cross-references
        local final_body="$issue_body"
        if [[ -n "$cross_refs" ]]; then
            final_body="$final_body\n\n---$cross_refs"
        fi
        
        # Create issue
        if [[ "$git_platform" == "gitlab" ]]; then
            glab issue create \
                --title "$title" \
                --description "$final_body" \
                --label "task,epic:$epic_name,phase:$phase" \
                --yes >/dev/null
        else
            gh issue create \
                --title "$title" \
                --body "$final_body" \
                --label "task,epic:$epic_name,phase:$phase" >/dev/null
        fi
        
        echo "  ✅ Created #$issue_number: $title"
    done < /tmp/issue-mapping.txt
    
    # Create sync-state.yaml
    echo "💾 Creating sync state..."
    cat > ".cccc/epics/$epic_name/sync-state.yaml" << EOF
platform: $git_platform
project_path: ${project_path:-$repo}
last_sync: $current_date
epic_number: $epic_number
epic_url: $epic_url

# Issue mappings
issue_mappings:
EOF
    
    # Add each issue mapping
    while IFS=':' read -r issue_id issue_number; do
        local title=$(get_issue_field "$analysis_file" "$issue_id" "title")
        local url
        if [[ "$git_platform" == "gitlab" ]]; then
            url="https://gitlab.com/$project_path/-/issues/$issue_number"
        else
            url="https://github.com/$repo/issues/$issue_number"
        fi
        
        cat >> ".cccc/epics/$epic_name/sync-state.yaml" << EOF
  $issue_id:
    number: $issue_number
    url: $url
    title: "$title"
EOF
    done < /tmp/issue-mapping.txt
    
    # Update epic.md
    echo "📝 Updating epic.md..."
    local epic_file=".cccc/epics/$epic_name/epic.md"
    if [[ "$git_platform" == "gitlab" ]]; then
        sed -i.bak "s|^gitlab:.*|gitlab: $epic_url|" "$epic_file"
    else
        sed -i.bak "s|^github:.*|github: $epic_url|" "$epic_file"
    fi
    sed -i.bak "s|^updated:.*|updated: $current_date|" "$epic_file"
    sed -i.bak "s|^status:.*|status: synced|" "$epic_file"
    rm -f "$epic_file.bak"
    
    # Create development worktree
    echo "🌿 Setting up development environment..."
    git checkout main >/dev/null 2>&1
    git pull "$git_remote" main >/dev/null 2>&1
    
    # Create worktree for epic development
    if [[ ! -d "../epic-$epic_name" ]]; then
        git worktree add "../epic-$epic_name" -b "epic/$epic_name" >/dev/null 2>&1
        cd "../epic-$epic_name"
        git push -u "$git_remote" "epic/$epic_name" >/dev/null 2>&1
        cd - >/dev/null
        echo "✅ Created worktree: ../epic-$epic_name"
    else
        echo "⚠️ Worktree already exists: ../epic-$epic_name"
    fi
    
    # Final summary
    local phases=$(get_stat_field "$analysis_file" "phases")
    local parallel_hours=$(get_stat_field "$analysis_file" "parallel_hours")
    local speedup=$(get_stat_field "$analysis_file" "speedup")
    
    cat << EOF

✅ Epic Synced Successfully

📊 Sync Summary:
  - Platform: $git_platform
  - Epic: #$epic_number - Epic: $epic_name
  - Issues: $issue_count individual issues created
  - Phases: $phases execution phases
  - Time Estimate: ${parallel_hours}h parallel (${speedup}x speedup)
  - Worktree: ../epic-$epic_name

🔗 Cross-References:
  - All dependencies pre-calculated and included
  - Issues created with proper GitLab/GitHub references
  - Ready for parallel development

📁 Files Created:
  - sync-state.yaml: Complete sync metadata
  - Updated epic.md: Sync status and URLs

🚀 Next Steps:
  1. View epic: $epic_url
  2. Start development: cd ../epic-$epic_name
  3. Begin Phase 1 issues (no dependencies)
  4. Follow parallel execution plan from analysis

💡 All issues are properly cross-referenced and ready for development!
EOF
    
    # Cleanup
    rm -f /tmp/epic-body.md /tmp/issue-mapping.txt
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ -z "$1" ]]; then
        echo "Usage: $0 <epic_name>"
        exit 1
    fi
    sync_epic "$1"
fi