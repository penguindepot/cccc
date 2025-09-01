---
allowed-tools: Bash, Read, LS
---

# utils:rebase-all

Rebase all epic branches on main and all issue branches on their respective epic branches, with automatic force-push handling when needed.

## Usage
```
/utils:rebase-all              # Rebase all epics and issues
/utils:rebase-all --dry-run    # Preview what would be rebased
/utils:rebase-all <epic_name>  # Rebase only specific epic and its issues
```

## Quick Check

1. **Check for worktrees:**
   ```bash
   worktree_count=$(git worktree list | grep -c "epic-" || true)
   [ "$worktree_count" -eq 0 ] && {
     echo "❌ No epic worktrees found"
     echo "Create worktrees using: /cccc:epic:sync <epic_name>"
     exit 1
   }
   echo "✅ Found $worktree_count epic worktree(s)"
   ```

2. **Check git status is clean:**
   ```bash
   if [ -n "$(git status --porcelain)" ]; then
     echo "❌ Working directory not clean. Commit or stash changes first."
     exit 1
   fi
   ```

## Instructions

### Execute Rebase All Script
```bash
# Parse arguments
if [ "$1" = "--dry-run" ]; then
  DRY_RUN="--dry-run"
  EPIC_FILTER="$2"
elif [ -n "$1" ] && [ "$1" != "--dry-run" ]; then
  EPIC_FILTER="$1" 
  DRY_RUN="$2"
else
  EPIC_FILTER=""
  DRY_RUN=""
fi

# Call the rebase-all script
if [ -n "$EPIC_FILTER" ]; then
  .claude/scripts/cccc/rebase-all.sh "$EPIC_FILTER" $DRY_RUN
else
  .claude/scripts/cccc/rebase-all.sh $DRY_RUN
fi
```

## Error Handling

If rebasing fails:
- Script will skip the conflicted branch and continue
- Conflicts are reported at the end
- User must resolve conflicts manually and re-run
- Use `git status` and `git rebase --abort` if needed

## Important Notes

1. **Safe Force Push**: Uses `--force-with-lease` to prevent overwriting others' work
2. **Conflict Handling**: Automatically skips conflicts and reports them
3. **Two-Phase Process**: First rebases epics on main, then issues on epics
4. **Dry Run**: Preview mode shows what would be rebased without making changes
5. **Selective Mode**: Can target specific epic and its issues only

## Expected Output

```
🔄 Starting rebase workflow for all branches...

Phase 1: Rebasing epic branches on main
========================================
Epic test-prd:
  ✅ epic/test-prd rebased on main (3 commits ahead)
  📤 Pushed with --force-with-lease

Phase 2: Rebasing issue branches on epics  
==========================================
Epic test-prd:
  ✅ issue/001.1 rebased on epic/test-prd (up to date)
  📤 Pushed with --force-with-lease

🎉 Rebase Complete!
Epics processed: 1/1 ✅
Issues processed: 1/1 ✅
Conflicts: 0

🔗 All branches are now up to date with main!
```

## Conflict Resolution

If conflicts occur:
```
⚠️  Conflicts detected in epic/test-prd
    Run manually:
    cd ../epic-test-prd
    git checkout epic/test-prd
    git rebase origin/main
    # Resolve conflicts, then:
    git rebase --continue
    git push --force-with-lease origin epic/test-prd
```