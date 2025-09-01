# Branch Operations

Git branch hierarchy enables epic-level development with issue branches, all within the main repository.

## Branch Hierarchy

The CCCC system uses a three-level branch hierarchy:
```
main (production)
├── epic/{name} (epic integration branch)
│   ├── issue/{id} (individual work branches)
│   ├── issue/{id}
│   └── issue/{id}
└── epic/{name}
    ├── issue/{id}
    └── issue/{id}
```

## Creating Epic Branches

Epic branches serve as integration points for related issues:
```bash
# Get configured remote
GIT_REMOTE=$(yq '.git_remote // "origin"' .cccc/cccc-config.yml)

# Ensure main is up to date
git checkout main
git pull $GIT_REMOTE main

# Create epic branch from main
git checkout -b epic/{name}

# Push epic branch to remote
git push -u $GIT_REMOTE epic/{name}
```

Epic branches are created by `/cccc:epic:sync` automatically.

## Working with Issue Branches

### Creating Issue Branches
Each issue gets its own branch created from the epic branch:
```bash
# Ensure epic is up to date
git checkout epic/{name}
git pull $GIT_REMOTE epic/{name}

# Create issue branch from epic
git checkout -b issue/{issue-id}

# Or use the command
/cccc:issue:start {epic-name} {issue-id}
```

### Agent Commits
- Agents work in issue branches
- Use small, focused commits
- Commit message format: `Issue #{number}: {description}`
- Example: `Issue #1234: Add user authentication schema`

### Branch Operations
```bash
# Switch to issue branch
git checkout issue/{issue-id}

# Normal git operations work
git add {files}
git commit -m "Issue #{number}: {change}"

# Push changes
git push -u $GIT_REMOTE issue/{issue-id}

# View branch status
git status
git branch -v
```

## Parallel Development

Multiple developers/agents can work on different issue branches simultaneously:
```bash
# Developer A works on Issue 001.1
git checkout issue/001.1
git add src/api/*
git commit -m "Issue #35: Add user endpoints"
git push

# Developer B works on Issue 001.2 (parallel!)
git checkout issue/001.2
git add src/ui/*
git commit -m "Issue #36: Add dashboard component"
git push
```

### Issue Branch Coordination
- Each issue branch is independent
- No conflicts between different issue branches
- Issues merge to epic via MR/PR
- Rebase keeps history clean

## Creating Merge Requests

When an issue is ready for review:
```bash
# Ensure branches are up to date
git checkout epic/{name}
git pull $GIT_REMOTE epic/{name}
git rebase $GIT_REMOTE/main

git checkout issue/{issue-id}
git rebase epic/{name}
git push --force-with-lease

# Create MR/PR using command
/cccc:issue:mr {epic-name} {issue-id}
```

This creates an MR/PR from `issue/{issue-id}` → `epic/{name}`

## Merging Strategy

### Issue to Epic Merging
When an MR is approved and ready to merge:
```bash
# Platform (GitLab/GitHub) handles the merge
# Then clean up with:
/cccc:mr:cleanup {epic-name} {issue-id}
```

### Epic to Main Merging
When epic is complete, create MR from epic to main:
```bash
# Rebase epic on main first
git checkout epic/{name}
git fetch $GIT_REMOTE
git rebase $GIT_REMOTE/main
git push --force-with-lease

# Create MR/PR through platform
# epic/{name} → main
```

## Branch Maintenance

### Rebasing All Branches
Keep all branches up to date:
```bash
# Rebase all epic branches on main
# and all issue branches on their epics
/utils:rebase-all

# Or for specific epic only
/utils:rebase-all {epic-name}
```

### Cleaning Up After Merge
```bash
# After MR is merged
/cccc:mr:cleanup {epic-name} {issue-id}

# This will:
# - Verify MR is merged
# - Delete local issue branch
# - Delete remote issue branch
# - Update sync-state.yaml
```

### Manual Branch Cleanup
```bash
# Delete local branch
git branch -D issue/{issue-id}

# Delete remote branch
git push $GIT_REMOTE --delete issue/{issue-id}

# Delete epic branch (after all issues merged)
git branch -D epic/{name}
git push $GIT_REMOTE --delete epic/{name}
```

## Handling Conflicts

If merge conflicts occur during rebase:
```bash
# Conflicts will be shown
git status

# Resolve conflicts in files
# Then continue rebase
git add {resolved-files}
git rebase --continue

# Or abort if needed
git rebase --abort
```

## Branch Management Commands

### List Branches
```bash
# Local branches
git branch

# All branches (including remote)
git branch -a

# With last commit info
git branch -v
```

### Check Branch Status
```bash
# Current branch status
git status

# Compare with remote
git status -sb

# See unpushed commits
git log origin/{branch}..HEAD
```

### Switch Between Branches
```bash
# Switch to branch
git checkout {branch-name}

# Create and switch to new branch
git checkout -b {new-branch}

# Switch to previous branch
git checkout -
```

## Best Practices

1. **One epic branch per epic** - Integration point for related issues
2. **One branch per issue** - Isolation of work
3. **Always rebase before merge** - Keep history clean
4. **Use descriptive names** - `epic/feature-name` and `issue/001.1`
5. **Delete after merge** - Clean up merged branches
6. **Commit frequently** - Small commits are easier to review
7. **Push regularly** - Backup work to remote
8. **Update before starting** - Pull latest changes

## Common Issues

### Branch Already Exists
```bash
# Delete old branch first
git branch -D issue/{issue-id}
# Then create new one
git checkout -b issue/{issue-id}
```

### Behind Remote
```bash
# Pull and rebase local changes
git pull --rebase $GIT_REMOTE {branch}
```

### Rebase Conflicts
```bash
# During rebase conflicts
git status  # See conflicted files
# Edit files, resolve conflicts
git add <resolved-files>
git rebase --continue

# Or abort if needed
git rebase --abort
```

### Push Rejected
```bash
# After rebase, force push safely
git push --force-with-lease $GIT_REMOTE {branch}
```

## Branch Naming Convention

- **Epic branches**: `epic/{epic-name}`
  - Example: `epic/user-auth`
  
- **Issue branches**: `issue/{issue-id}`
  - Example: `issue/001.1`
  - Example: `issue/002.3`

- **No feature branches**: Work happens in issue branches
- **No develop branch**: Epic branches serve this purpose
- **Main is stable**: Only tested, merged code reaches main