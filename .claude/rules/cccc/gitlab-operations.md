# GitLab Operations Rule

Standard patterns for GitLab CLI operations across all commands.

## Authentication

**Don't pre-check authentication.** Just run the command and handle failure:

```bash
glab {command} || echo "❌ GitLab CLI failed. Run: glab auth login"
```

## Common Operations

### Get Issue Details
```bash
glab issue view {number} --json state,title,labels,description
```

### Create Issue
```bash
# Standard issue creation (no JSON output available)
glab issue create \
  --title "{title}" \
  --description "$(cat {file})" \
  --label "{labels}" \
  --yes

# Get issue number after creation
issue_number=$(glab issue list --label "{unique-label}" | head -n 1 | awk '{print $1}' | sed 's/#//')

# With assignee
glab issue create \
  --title "{title}" \
  --description "$(cat {file})" \
  --label "{labels}" \
  --assignee @me \
  --yes
```

### Update Issue
```bash
# Add labels
glab issue update {number} --label-add "{label}"

# Assign to self
glab issue update {number} --assignee @me

# Update description
glab issue update {number} --description-file {file}

# Close issue
glab issue update {number} --state closed
```

### Add Comment
```bash
# Add note to issue
glab issue note {number} --message-file {file}

# Quick comment
glab issue note {number} --message "Comment text"
```

### List Issues
```bash
# List all open issues
glab issue list --state opened

# List issues with specific label
glab issue list --label "epic:{name}"

# Get JSON output
glab issue list --format json --label "task"
```

## GitLab-Specific Features

### Issue IDs
GitLab uses IID (internal ID) for project-level references:
```bash
# Create issue first, then get IID from list
glab issue create --title "Title" --description "Body" --label "labels" --yes

# Get IID from issue list (since no JSON output on create)
issue_number=$(glab issue list --label "unique-label" | head -n 1 | awk '{print $1}' | sed 's/#//')

# Reference in GitLab: #123 (uses IID)
# Full reference: group/project#123
```

### Epics (Premium Feature)
```bash
# Create epic (if available)
glab epic create \
  --title "{title}" \
  --description-file {file} \
  --label "{labels}"

# Note: Epics require GitLab Premium
# Fallback: Use issues with "epic" label
```

### Milestones
```bash
# Create issue with milestone
glab issue create \
  --title "{title}" \
  --description-file {file} \
  --milestone "{milestone_name}"

# List milestones
glab milestone list
```

### Project Information
```bash
# Get project path
project_path=$(glab repo view --json path_with_namespace -q .path_with_namespace)

# Get project URL
project_url=$(glab repo view --json web_url -q .web_url)

# Get default branch
default_branch=$(glab repo view --json default_branch -q .default_branch)
```

## URL Construction

GitLab URLs follow different patterns:
```bash
# Issue URL
https://gitlab.com/{project_path}/-/issues/{iid}

# Merge Request URL
https://gitlab.com/{project_path}/-/merge_requests/{iid}

# File URL
https://gitlab.com/{project_path}/-/blob/{branch}/{file_path}
```

## Error Handling

If any glab command fails:
1. Show clear error: "❌ GitLab operation failed: {command}"
2. Common fixes:
   - Authentication: "Run: glab auth login"
   - Project detection: "Run: glab repo set-default"
   - Permission issue: "Check project access permissions"
3. Don't retry automatically

## Platform Detection

Check if in GitLab repository:
```bash
# Check remote URL
git remote get-url origin | grep -q gitlab && echo "GitLab detected"

# Or use glab
glab repo view >/dev/null 2>&1 && echo "GitLab project"
```

## Important Notes

- **Trust glab CLI**: Assume it's installed and authenticated
- **Use --format json**: For structured output when parsing
- **IID vs ID**: Always use IID for local references
- **Premium features**: Some features (epics, iterations) require paid plans
- **Project context**: glab auto-detects project from git remote
- **Keep operations atomic**: One glab command per action
- **Don't check rate limits**: GitLab has generous API limits

## Common Patterns

### Batch Operations
```bash
# Create multiple issues from list
for title in "Issue 1" "Issue 2" "Issue 3"; do
  glab issue create --title "$title" --label "batch"
done
```

### Label Management
```bash
# Multiple labels (comma-separated)
glab issue create --label "bug,priority::high,epic:feature"

# GitLab scoped labels (::)
--label "priority::high"  # Only one priority:: label allowed
--label "status::in-progress"
```

### Search and Filter
```bash
# Search issues
glab issue list --search "authentication"

# Filter by author
glab issue list --author @me

# Filter by assignee
glab issue list --assignee @me
```