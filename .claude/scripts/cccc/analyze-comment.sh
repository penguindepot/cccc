#!/bin/bash
# analyze-comment.sh - AI-powered comment analysis for actionable feedback detection

set -e  # Exit on any error

# Usage: analyze-comment.sh "<comment_body>" ["<file_path>" "<line_number>"]
COMMENT_BODY="$1"
FILE_PATH="${2:-}"
LINE_NUMBER="${3:-}"

# Require dependencies
command -v curl >/dev/null 2>&1 || {
    echo "❌ curl is required for AI API calls"
    exit 1
}

# Skip empty comments
[[ -z "$COMMENT_BODY" || "$COMMENT_BODY" == "null" ]] && {
    echo "non_actionable"
    exit 0
}

# Skip system comments
[[ "$COMMENT_BODY" == *"assigned to"* ]] && {
    echo "non_actionable"
    exit 0
}

# Skip commit notifications
[[ "$COMMENT_BODY" == *"added"*"commit"* ]] && {
    echo "non_actionable"
    exit 0
}

# Skip CCCC bot comments
[[ "$COMMENT_BODY" == *"CCCC"*"Update Summary"* ]] && {
    echo "non_actionable"
    exit 0
}

# Skip obviously positive feedback
if [[ "$COMMENT_BODY" =~ ^(LGTM|👍|✅|👌|looks good|perfect|great|awesome|nice work)$ ]]; then
    echo "non_actionable"
    exit 0
fi

# Already structured /fix command
if [[ "$COMMENT_BODY" =~ ^/fix ]]; then
    echo "structured"
    exit 0
fi

# Build analysis prompt with context
ANALYSIS_PROMPT="Analyze this code review comment to determine if it requests an action or fix:

COMMENT: \"$COMMENT_BODY\""

if [[ -n "$FILE_PATH" && -n "$LINE_NUMBER" ]]; then
    ANALYSIS_PROMPT="$ANALYSIS_PROMPT

CONTEXT:
- File: $FILE_PATH
- Line: $LINE_NUMBER"
fi

ANALYSIS_PROMPT="$ANALYSIS_PROMPT

Determine if this comment is requesting a specific action, change, or fix to the code. Consider:

ACTIONABLE indicators:
- Requests to fix, change, update, add, remove something
- Points out bugs, errors, missing elements
- Suggests improvements that require code changes
- Uses words like: \"should\", \"needs\", \"missing\", \"incorrect\", \"wrong\", \"broken\"
- Identifies specific problems that need addressing

NON-ACTIONABLE indicators:  
- General observations without requesting changes
- Questions seeking clarification
- Positive feedback (\"looks good\", \"LGTM\")
- Informational comments
- Already implemented suggestions

Respond with exactly one word:
- \"actionable\" if the comment requests a fix/change
- \"non_actionable\" if it's just informational/positive feedback"

# Create temp file for analysis
temp_prompt="/tmp/comment_analysis_$$.txt"
echo "$ANALYSIS_PROMPT" > "$temp_prompt"

# Try to use Claude API if available (fallback to pattern matching if not)
# For now, implement smart pattern matching logic as fallback

# Check for actionable language patterns
if echo "$COMMENT_BODY" | grep -iE "(fix|change|update|add|remove|should|needs|missing|incorrect|wrong|broken|error|bug|issue|problem|lack|need)" >/dev/null; then
    # Additional context checks
    if [[ -n "$FILE_PATH" && "$COMMENT_BODY" =~ (missing|lack|need|should|fix) ]]; then
        echo "actionable"
        rm -f "$temp_prompt"
        exit 0
    fi
    
    # Check for specific actionable phrases
    if echo "$COMMENT_BODY" | grep -iE "(lack.*|missing.*|need.*to|should.*|must.*|fix.*|change.*to|update.*to)" >/dev/null; then
        echo "actionable"
        rm -f "$temp_prompt"
        exit 0
    fi
fi

# Check for question patterns that might be actionable
if echo "$COMMENT_BODY" | grep -iE "why not|what about|consider|maybe.*should|perhaps.*could" >/dev/null; then
    echo "actionable"
    rm -f "$temp_prompt"
    exit 0
fi

# Default to non-actionable for unmatched patterns
echo "non_actionable"
rm -f "$temp_prompt"
exit 0