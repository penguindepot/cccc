# Worktree Operations

Git worktrees enable epic-level parallel development with issue branches within each worktree.

## Creating Epic Worktrees

Worktrees are created for entire epics, containing multiple issue branches:
```bash
# Get configured remote
GIT_REMOTE=$(grep "^git_remote:" .ccpls/pm-config.yml | cut -d: -f2 | tr -d ' ')
if [ -z "$GIT_REMOTE" ]; then
  GIT_REMOTE="origin"
fi

# Ensure main is up to date
git checkout main
git pull $GIT_REMOTE main

# Create worktree for epic with epic branch as default
git worktree add ../epic-{name} -b epic/{name}

# Push epic branch to remote
cd ../epic-{name}
git push -u $GIT_REMOTE epic/{name}
cd - > /dev/null
```

The worktree is created as a sibling directory with the epic branch as its main branch.

## Working with Issue Branches in Worktrees

### Creating Issue Branches
Each issue gets its own branch within the epic worktree:
```bash
# Navigate to epic worktree
cd ../epic-{name}

# Rebase epic main on project main first
git fetch $GIT_REMOTE
git rebase $GIT_REMOTE/main

# Create issue branch from epic main
git checkout -b issue/{issue-id}-{title-slug}

# Or rebase existing issue branch
git checkout issue/{issue-id}-{title-slug}
git rebase epic/{name}
```

### Agent Commits
- Agents work in issue branches within the worktree
- Use small, focused commits
- Commit message format: `Issue #{number}: {description}`
- Example: `Issue #1234: Add user authentication schema`

### File Operations
```bash
# Working directory is the epic worktree
cd ../epic-{name}

# Switch to issue branch
git checkout issue/{issue-id}-{title-slug}

# Normal git operations work
git add {files}
git commit -m "Issue #{number}: {change}"

# View branch status
git status
git branch -v
```

## Parallel Work in Same Worktree

Multiple agents can work in the same worktree on different issue branches:
```bash
# Agent A works on Issue #1234 branch
cd ../epic-feature
git checkout issue/1234-add-auth
git add src/api/*
git commit -m "Issue #1234: Add user endpoints"

# Agent B works on Issue #1235 branch (parallel!)
git checkout issue/1235-dashboard
git add src/ui/*
git commit -m "Issue #1235: Add dashboard component"
```

### Issue Branch Coordination
- Each issue branch is independent
- No conflicts between different issue branches
- Issues merge to epic main sequentially
- Rebase keeps history clean

## Issue to Epic Merging

When an issue is complete, merge to epic main with rebase:
```bash
# In epic worktree
cd ../epic-{name}

# Rebase epic main on project main
git checkout epic/{name}
git fetch $GIT_REMOTE
git rebase $GIT_REMOTE/main

# Rebase issue branch on epic main
git checkout issue/{issue-id}-{title-slug}
git rebase epic/{name}

# Fast-forward merge to epic main
git checkout epic/{name}
git merge issue/{issue-id}-{title-slug} --ff-only

# Clean up issue branch
git branch -d issue/{issue-id}-{title-slug}
```

## Epic to Project Merging

When epic is complete, merge back to main:
```bash
# Final rebase in worktree
cd ../epic-{name}
git fetch $GIT_REMOTE
git rebase $GIT_REMOTE/main

# Return to main repository
cd {main-repo}
git checkout main
git pull $GIT_REMOTE main

# Merge epic branch (fast-forward preferred)
git merge epic/{name} --ff-only

# Clean up
git worktree remove ../epic-{name} --force
git branch -d epic/{name}
git push $GIT_REMOTE --delete epic/{name}
```

## Handling Conflicts

If merge conflicts occur:
```bash
# Conflicts will be shown
git status

# Human resolves conflicts
# Then continue merge
git add {resolved-files}
git commit
```

## Worktree Management

### List Active Worktrees
```bash
git worktree list
```

### Remove Stale Worktree
```bash
# If worktree directory was deleted
git worktree prune

# Force remove worktree
git worktree remove --force ../epic-{name}
```

### Check Worktree Status
```bash
# From main repo, check worktree status
cd ../epic-{name}
git status
git branch -v  # See all branches and their status
cd - > /dev/null

# List all worktrees
git worktree list
```

## Best Practices

1. **One worktree per epic** - Contains multiple issue branches
2. **One branch per issue** - Within the epic worktree
3. **Always rebase before merge** - Epic main on project main, issue branch on epic main
4. **Fast-forward merges** - Clean linear history
5. **Clean before create** - Always start from updated main
6. **Commit frequently** - Small commits are easier to rebase
7. **Delete after merge** - Remove issue branches and worktrees
8. **Use descriptive branches** - `epic/feature-name` and `issue/123-description`

## Common Issues

### Worktree Already Exists
```bash
# Remove old worktree first
git worktree remove ../epic-{name} --force
git worktree prune
# Then create new one
```

### Issue Branch Already Exists
```bash
# In epic worktree
cd ../epic-{name}
git branch -D issue/{issue-id}-{title}
# Then create new one
git checkout -b issue/{issue-id}-{title}
```

### Rebase Conflicts
```bash
# During rebase conflicts
git status  # See conflicted files
# Ask Human to edit files, resolve conflicts
git add <resolved-files>
git rebase --continue

# Or abort if needed
git rebase --abort
```

### Cannot Remove Worktree
```bash
# Force removal (handles git locks)
git worktree remove --force ../epic-{name}
# Clean up references
git worktree prune
# Manual cleanup if needed
rm -rf ../epic-{name}
```