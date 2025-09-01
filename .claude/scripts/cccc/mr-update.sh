#!/bin/bash
# mr-update.sh - Fetch and process merge request comments from GitLab/GitHub API

set -e  # Exit on any error

# Require dependencies
for cmd in yq jq; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "❌ $cmd is required for YAML/JSON parsing. Install with:"
        echo "   macOS: brew install $cmd"
        exit 1
    }
done

EPIC_NAME="$1"
ISSUE_ID="$2"

if [ -z "$EPIC_NAME" ] || [ -z "$ISSUE_ID" ]; then
    echo "❌ Usage: $0 <epic_name> <issue_id>"
    exit 1
fi

echo "🔄 Fetching MR feedback for issue $ISSUE_ID..."

# Get current datetime for updates
current_datetime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get platform and sync state info
git_platform=$(yq '.git_platform // "gitlab"' .cccc/cccc-config.yml)
sync_state_file=".cccc/epics/$EPIC_NAME/sync-state.yaml"

# Get MR details from sync-state
mr_number=$(yq ".issue_mappings.\"$ISSUE_ID\".mr_number" "$sync_state_file")
mr_url=$(yq -r ".issue_mappings.\"$ISSUE_ID\".mr_url" "$sync_state_file")
issue_title=$(yq -r ".issue_mappings.\"$ISSUE_ID\".title" "$sync_state_file")

echo "  📥 Found MR: $mr_url (#$mr_number)"

# GitLab API functions
get_mr_discussions_gitlab() {
    local mr_number="$1"
    local result=$(glab api "projects/:id/merge_requests/$mr_number/discussions" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        return 0
    else
        return 1
    fi
}

post_comment_mr_gitlab() {
    local mr_number="$1"
    local comment_body="$2"
    glab api "projects/:id/merge_requests/$mr_number/notes" \
        --method POST \
        --field "body=$comment_body" >/dev/null 2>&1
}

# GitHub API functions  
get_pr_comments_github() {
    local pr_number="$1"
    # Get both review comments and issue comments for PR
    local review_comments=$(gh api "repos/:owner/:repo/pulls/$pr_number/comments" 2>/dev/null)
    local issue_comments=$(gh api "repos/:owner/:repo/issues/$pr_number/comments" 2>/dev/null)
    
    # Combine both types of comments
    echo "[$review_comments, $issue_comments]" | jq -c 'flatten'
}

post_comment_pr_github() {
    local pr_number="$1"
    local comment_body="$2"
    gh api "repos/:owner/:repo/issues/$pr_number/comments" \
        --method POST \
        --field "body=$comment_body" >/dev/null 2>&1
}

# Fetch MR/PR discussions/comments
echo "  💬 Fetching discussions and comments..."

if [[ "$git_platform" == "gitlab" ]]; then
    discussions_data=$(get_mr_discussions_gitlab "$mr_number")
    if [[ $? -ne 0 ]]; then
        echo "❌ Failed to fetch MR discussions for #$mr_number"
        exit 1
    fi
    
    # Extract all notes from discussions
    comments_data=$(echo "$discussions_data" | jq '[.[].notes[]? // empty]')
else
    comments_data=$(get_pr_comments_github "$mr_number")
    if [[ $? -ne 0 ]]; then
        echo "❌ Failed to fetch PR comments for #$mr_number"
        exit 1
    fi
fi

# Count total comments
total_comments=$(echo "$comments_data" | jq '. | length')
echo "  💬 Fetched discussions with $total_comments total comments"

# Process comments for structured fixes and feedback
echo "  🔍 Processing comments for actionable feedback..."

temp_feedback="/tmp/mr_feedback_$ISSUE_ID.yaml"

# Initialize feedback structure
cat > "$temp_feedback" << EOF
mr_feedback:
  last_fetched: "$current_datetime"
  comments: []
  has_actionable: false
  fix_required: false
  actionable_count: 0
  feedback_count: 0
EOF

structured_count=0
feedback_count=0

# Process each comment
for ((i = 0; i < total_comments; i++)); do
    comment_body=$(echo "$comments_data" | jq -r ".[$i].body // .[$i].note // \"\"")
    comment_author=$(echo "$comments_data" | jq -r ".[$i].author.username // .[$i].user.login // \"unknown\"")
    comment_date=$(echo "$comments_data" | jq -r ".[$i].created_at // .[$i].updated_at // \"\"")
    
    # Extract position data if available (GitLab line-specific comments)
    comment_position=$(echo "$comments_data" | jq -r ".[$i].position // null")
    file_path=""
    line_number=""
    line_range=""
    
    if [[ "$comment_position" != "null" && "$comment_position" != "" ]]; then
        file_path=$(echo "$comment_position" | jq -r '.new_path // .old_path // ""')
        line_number=$(echo "$comment_position" | jq -r '.new_line // .old_line // ""')
        if [[ "$line_number" == "null" ]]; then line_number=""; fi
        
        # Extract line range if available
        line_range_start=$(echo "$comment_position" | jq -r '.line_range.start.new_line // .line_range.start.old_line // ""')
        line_range_end=$(echo "$comment_position" | jq -r '.line_range.end.new_line // .line_range.end.old_line // ""')
        if [[ "$line_range_start" != "null" && "$line_range_start" != "" ]]; then
            if [[ "$line_range_start" == "$line_range_end" ]]; then
                line_range="$line_range_start"
            else
                line_range="$line_range_start-$line_range_end"
            fi
        fi
    fi
    
    # Skip system comments, empty comments, and CCCC bot comments
    [[ -z "$comment_body" || "$comment_body" == "null" ]] && continue
    [[ "$comment_body" == *"CCCC"* && "$comment_body" == *"Update Summary"* ]] && continue
    [[ "$comment_body" == *"Applied requested fixes"* ]] && continue
    [[ "$comment_body" == *"assigned to"* ]] && continue
    [[ "$comment_body" == *"added"*"commit"* ]] && continue
    
    # Check for structured /fix commands
    if echo "$comment_body" | grep -q "^/fix"; then
        structured_count=$((structured_count + 1))
        
        # Parse /fix commands
        while IFS= read -r line; do
            if [[ "$line" =~ ^/fix[[:space:]]+(.*):[[:space:]]*(.*) ]]; then
                fix_category="${BASH_REMATCH[1]}"
                fix_description="${BASH_REMATCH[2]}"
                
                # Create comment entry using jq for proper JSON
                comment_entry=$(jq -n \
                    --arg author "$comment_author" \
                    --arg date "$comment_date" \
                    --arg body "$line" \
                    --arg type "structured" \
                    --arg fix_category "$fix_category" \
                    --arg fix_description "$fix_description" \
                    --arg file_path "$file_path" \
                    --arg line_number "$line_number" \
                    --arg line_range "$line_range" \
                    '{author: $author, date: $date, body: $body, type: $type, fix_category: $fix_category, fix_description: $fix_description, file_path: $file_path, line_number: $line_number, line_range: $line_range}')
                yq eval -i ".mr_feedback.comments += [$comment_entry]" "$temp_feedback"
            elif [[ "$line" =~ ^/fix[[:space:]]+(.*) ]]; then
                fix_description="${BASH_REMATCH[1]}"
                
                # Generic fix command using jq for proper JSON
                comment_entry=$(jq -n \
                    --arg author "$comment_author" \
                    --arg date "$comment_date" \
                    --arg body "$line" \
                    --arg type "structured" \
                    --arg fix_category "general" \
                    --arg fix_description "$fix_description" \
                    --arg file_path "$file_path" \
                    --arg line_number "$line_number" \
                    --arg line_range "$line_range" \
                    '{author: $author, date: $date, body: $body, type: $type, fix_category: $fix_category, fix_description: $fix_description, file_path: $file_path, line_number: $line_number, line_range: $line_range}')
                yq eval -i ".mr_feedback.comments += [$comment_entry]" "$temp_feedback"
            fi
        done <<< "$comment_body"
    else
        # Use AI to analyze if comment is actionable
        analysis_result=$(.claude/scripts/cccc/analyze-comment.sh "$comment_body" "$file_path" "$line_number")
        
        if [[ "$analysis_result" == "actionable" ]]; then
            # AI detected actionable feedback
            structured_count=$((structured_count + 1))
            
            comment_entry=$(jq -n \
                --arg author "$comment_author" \
                --arg date "$comment_date" \
                --arg body "$comment_body" \
                --arg type "ai_detected_action" \
                --arg fix_category "general" \
                --arg fix_description "$comment_body" \
                --arg file_path "$file_path" \
                --arg line_number "$line_number" \
                --arg line_range "$line_range" \
                '{author: $author, date: $date, body: $body, type: $type, fix_category: $fix_category, fix_description: $fix_description, file_path: $file_path, line_number: $line_number, line_range: $line_range}')
            yq eval -i ".mr_feedback.comments += [$comment_entry]" "$temp_feedback"
        elif [[ ${#comment_body} -gt 10 && ! "$comment_body" =~ ^(LGTM|👍|✅|👌)$ ]]; then
            # Regular feedback (informational only)
            feedback_count=$((feedback_count + 1))
            
            comment_entry=$(jq -n \
                --arg author "$comment_author" \
                --arg date "$comment_date" \
                --arg body "$comment_body" \
                --arg type "feedback" \
                --arg file_path "$file_path" \
                --arg line_number "$line_number" \
                --arg line_range "$line_range" \
                '{author: $author, date: $date, body: $body, type: $type, file_path: $file_path, line_number: $line_number, line_range: $line_range}')
            yq eval -i ".mr_feedback.comments += [$comment_entry]" "$temp_feedback"
        fi
    fi
done

# Update feedback summary
yq eval -i ".mr_feedback.actionable_count = $structured_count" "$temp_feedback"
yq eval -i ".mr_feedback.feedback_count = $feedback_count" "$temp_feedback"

if [[ $structured_count -gt 0 ]]; then
    yq eval -i ".mr_feedback.has_actionable = true" "$temp_feedback"
    yq eval -i ".mr_feedback.fix_required = true" "$temp_feedback"
else
    yq eval -i ".mr_feedback.has_actionable = false" "$temp_feedback"
    yq eval -i ".mr_feedback.fix_required = false" "$temp_feedback"
fi

structured_fixes=$(yq eval '.mr_feedback.comments[] | select(.type == "structured") | .body' "$temp_feedback" | wc -l || echo "0")
ai_detected_fixes=$(yq eval '.mr_feedback.comments[] | select(.type == "ai_detected_action") | .body' "$temp_feedback" | wc -l || echo "0")
total_actionable=$((structured_fixes + ai_detected_fixes))

echo "  ✅ Found $structured_fixes structured fix commands (/fix)"
echo "  🤖 Found $ai_detected_fixes AI-detected actionable comments"
echo "  📝 Found $feedback_count general feedback comments"

# Merge feedback into sync-state.yaml
echo "  💾 Updating sync-state with MR feedback..."

# Create backup
cp "$sync_state_file" "${sync_state_file}.bak"

# Merge the feedback YAML directly
yq eval-all 'select(fileIndex == 0) as $base | select(fileIndex == 1) as $new | $base | .issue_mappings."'$ISSUE_ID'".mr_feedback = $new.mr_feedback' "$sync_state_file" "$temp_feedback" > "${sync_state_file}.tmp"
mv "${sync_state_file}.tmp" "$sync_state_file"

# Verify the update was successful
if [[ $? -eq 0 ]]; then
    rm -f "${sync_state_file}.bak"
    echo "  ✅ Successfully updated sync-state with MR feedback"
else
    mv "${sync_state_file}.bak" "$sync_state_file"
    echo "  ❌ Failed to update sync-state, restored backup"
    exit 1
fi

# Cleanup temp file
rm -f "$temp_feedback"

echo ""
echo "📊 MR Feedback Summary:"
echo "  - MR: #$mr_number - $issue_title"
echo "  - Total Comments: $total_comments"
echo "  - Structured Fixes: $structured_fixes (/fix commands)"
echo "  - AI-Detected Actions: $ai_detected_fixes items"
echo "  - General Feedback: $feedback_count items"
echo "  - Actionable Items: $([ $total_actionable -gt 0 ] && echo "Yes ($total_actionable fixes required)" || echo "No")"
echo "  - Last Fetched: $current_datetime"
echo ""

if [[ $total_actionable -gt 0 ]]; then
    echo "💡 Next Steps:"
    echo "  - Run: /cccc:mr:fix $EPIC_NAME $ISSUE_ID (to implement fixes)"
    echo "  - Or review feedback manually in sync-state.yaml"
else
    echo "✅ No actionable fixes found - MR feedback is informational only"
fi

echo ""
echo "🔗 View MR: $mr_url"

exit 0