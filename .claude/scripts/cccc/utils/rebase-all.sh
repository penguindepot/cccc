#!/bin/bash

echo "🔄 Starting rebase workflow for all branches..."
echo ""

# Parse arguments
DRY_RUN=""
EPIC_FILTER=""

for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN="--dry-run"
      echo "🔍 DRY RUN MODE - No changes will be made"
      echo ""
      ;;
    *)
      if [ -z "$EPIC_FILTER" ]; then
        EPIC_FILTER="$arg"
      fi
      ;;
  esac
done

# Get git remote configuration
if [ -f ".cccc/cccc-config.yml" ]; then
  git_remote=$(yq '.git_remote // "origin"' .cccc/cccc-config.yml 2>/dev/null || echo "origin")
else
  git_remote="origin"
fi

echo "🔧 Using remote: $git_remote"
echo ""

# Discover worktrees
if [ -n "$EPIC_FILTER" ]; then
  # Check if specific epic worktree exists
  if [ ! -d "../epic-$EPIC_FILTER" ]; then
    echo "❌ Epic worktree not found: ../epic-$EPIC_FILTER"
    exit 1
  fi
  worktrees=("../epic-$EPIC_FILTER")
  echo "🎯 Targeting specific epic: $EPIC_FILTER"
else
  # Find all epic worktrees
  worktrees=($(ls -d ../epic-* 2>/dev/null | sort))
  if [ ${#worktrees[@]} -eq 0 ]; then
    echo "❌ No epic worktrees found"
    echo "Create worktrees using: /cccc:epic:sync <epic_name>"
    exit 1
  fi
  echo "📁 Found ${#worktrees[@]} epic worktree(s)"
fi

echo ""

# Track statistics
epic_success=0
epic_conflicts=0  
issue_success=0
issue_conflicts=0
conflict_list=()

# Phase 1: Rebase epic branches on main
echo "Phase 1: Rebasing epic branches on main"
echo "========================================"

for worktree_path in "${worktrees[@]}"; do
  epic_name=$(basename "$worktree_path" | sed 's/^epic-//')
  epic_branch="epic/$epic_name"
  echo "Epic $epic_name:"
  
  # Navigate to worktree
  if ! cd "$worktree_path" 2>/dev/null; then
    echo "  ❌ Cannot access worktree: $worktree_path"
    ((epic_conflicts++))
    conflict_list+=("$epic_name: worktree inaccessible")
    cd - >/dev/null 2>&1
    continue
  fi
  
  # Fetch latest
  echo "  📥 Fetching latest from $git_remote..."
  if [ -z "$DRY_RUN" ]; then
    if ! git fetch "$git_remote" >/dev/null 2>&1; then
      echo "  ❌ Failed to fetch from remote"
      ((epic_conflicts++))
      conflict_list+=("$epic_name: fetch failed")
      cd - >/dev/null 2>&1
      continue
    fi
  else
    echo "  🔍 [DRY RUN] Would fetch from $git_remote"
  fi
  
  # Pull latest epic branch from remote to get any merged changes
  echo "  📥 Pulling latest $epic_branch from $git_remote..."
  if [ -z "$DRY_RUN" ]; then
    # Check if remote branch exists first
    if git ls-remote --heads "$git_remote" "$epic_branch" | grep -q "$epic_branch"; then
      if git pull "$git_remote" "$epic_branch" --rebase >/dev/null 2>&1; then
        echo "  ✅ Pulled and rebased local changes"
      else
        echo "  ⚠️  Pull failed or had conflicts (will continue with rebase)"
      fi
    else
      echo "  ⚠️  Remote epic branch doesn't exist yet"
    fi
  else
    echo "  🔍 [DRY RUN] Would pull $epic_branch from $git_remote"
  fi
  
  # Check if epic branch exists
  if ! git show-ref --verify --quiet "refs/heads/$epic_branch"; then
    echo "  ❌ Epic branch not found: $epic_branch"
    ((epic_conflicts++))
    conflict_list+=("$epic_name: epic branch missing")
    cd - >/dev/null 2>&1
    continue
  fi
  
  # Checkout epic branch
  if [ -z "$DRY_RUN" ]; then
    git checkout "$epic_branch" >/dev/null 2>&1
  else
    echo "  🔍 [DRY RUN] Would checkout $epic_branch"
  fi
  
  # Check if rebase is needed
  if [ -z "$DRY_RUN" ]; then
    behind_count=$(git rev-list --count HEAD.."$git_remote/main" 2>/dev/null || echo "unknown")
    if [ "$behind_count" = "0" ]; then
      echo "  ✅ $epic_branch already up to date"
      ((epic_success++))
      cd - >/dev/null 2>&1
      continue
    elif [ "$behind_count" = "unknown" ]; then
      echo "  ⚠️  Cannot determine if rebase needed"
    else
      echo "  📊 $epic_branch is $behind_count commit(s) behind main"
    fi
  else
    echo "  🔍 [DRY RUN] Would check if rebase needed"
  fi
  
  # Attempt rebase
  if [ -z "$DRY_RUN" ]; then
    echo "  🔄 Rebasing $epic_branch on $git_remote/main..."
    if git rebase "$git_remote/main" >/dev/null 2>&1; then
      echo "  ✅ $epic_branch rebased successfully"
      
      # Verify we're not losing commits before pushing
      local_commits=$(git rev-list --count "$git_remote/$epic_branch".."$epic_branch" 2>/dev/null || echo "0")
      if [ "$local_commits" -gt 0 ]; then
        echo "  📊 Local branch has $local_commits new commit(s) to push"
      fi
      
      # Check if remote has commits we don't have (safety check)
      remote_commits=$(git rev-list --count "$epic_branch".."$git_remote/$epic_branch" 2>/dev/null || echo "0")
      if [ "$remote_commits" -gt 0 ]; then
        echo "  ⚠️  WARNING: Remote has $remote_commits commit(s) not in local"
        echo "  💡 This should not happen after pull - skipping push for safety"
        ((epic_conflicts++))
        conflict_list+=("$epic_name: remote has unpulled commits")
      else
        # Push with force-with-lease
        echo "  📤 Pushing with --force-with-lease..."
        if git push --force-with-lease "$git_remote" "$epic_branch" >/dev/null 2>&1; then
          echo "  ✅ Pushed successfully"
          ((epic_success++))
        else
          echo "  ❌ Push failed"
          ((epic_conflicts++))
          conflict_list+=("$epic_name: push failed after rebase")
        fi
      fi
    else
      echo "  ❌ Rebase failed - conflicts detected"
      git rebase --abort >/dev/null 2>&1
      ((epic_conflicts++))
      conflict_list+=("$epic_name: rebase conflicts")
    fi
  else
    echo "  🔍 [DRY RUN] Would rebase $epic_branch on $git_remote/main"
    echo "  🔍 [DRY RUN] Would push with --force-with-lease"
    ((epic_success++))
  fi
  
  cd - >/dev/null 2>&1
done

echo ""

# Phase 2: Rebase issue branches on epics
echo "Phase 2: Rebasing issue branches on epics"
echo "=========================================="

for worktree_path in "${worktrees[@]}"; do
  epic_name=$(basename "$worktree_path" | sed 's/^epic-//')
  echo "Epic $epic_name:"
  
  # Navigate to worktree
  if ! cd "$worktree_path" 2>/dev/null; then
    echo "  ❌ Cannot access worktree: $worktree_path"
    cd - >/dev/null 2>&1
    continue
  fi
  
  # Find all issue branches
  issue_branches=($(git branch | grep "issue/" | sed 's/^[* ] //' | sort))
  
  if [ ${#issue_branches[@]} -eq 0 ]; then
    echo "  📝 No issue branches found"
    cd - >/dev/null 2>&1
    continue
  fi
  
  echo "  📋 Found ${#issue_branches[@]} issue branch(es)"
  
  epic_branch="epic/$epic_name"
  
  for issue_branch in "${issue_branches[@]}"; do
    echo "  🌿 Processing $issue_branch..."
    
    # Checkout issue branch
    if [ -z "$DRY_RUN" ]; then
      if ! git checkout "$issue_branch" >/dev/null 2>&1; then
        echo "    ❌ Failed to checkout $issue_branch"
        ((issue_conflicts++))
        conflict_list+=("$epic_name/$issue_branch: checkout failed")
        continue
      fi
    else
      echo "    🔍 [DRY RUN] Would checkout $issue_branch"
    fi
    
    # Check if rebase is needed
    if [ -z "$DRY_RUN" ]; then
      behind_count=$(git rev-list --count HEAD.."$epic_branch" 2>/dev/null || echo "unknown")
      if [ "$behind_count" = "0" ]; then
        echo "    ✅ $issue_branch already up to date with epic"
        ((issue_success++))
        continue
      elif [ "$behind_count" = "unknown" ]; then
        echo "    ⚠️  Cannot determine if rebase needed"
      else
        echo "    📊 $issue_branch is $behind_count commit(s) behind epic"
      fi
    else
      echo "    🔍 [DRY RUN] Would check if rebase needed"
    fi
    
    # Attempt rebase
    if [ -z "$DRY_RUN" ]; then
      echo "    🔄 Rebasing $issue_branch on $epic_branch..."
      if git rebase "$epic_branch" >/dev/null 2>&1; then
        echo "    ✅ $issue_branch rebased successfully"
        
        # Push with force-with-lease
        echo "    📤 Pushing with --force-with-lease..."
        if git push --force-with-lease "$git_remote" "$issue_branch" >/dev/null 2>&1; then
          echo "    ✅ Pushed successfully"
          ((issue_success++))
        else
          echo "    ❌ Push failed"
          ((issue_conflicts++))
          conflict_list+=("$epic_name/$issue_branch: push failed after rebase")
        fi
      else
        echo "    ❌ Rebase failed - conflicts detected"
        git rebase --abort >/dev/null 2>&1
        ((issue_conflicts++))
        conflict_list+=("$epic_name/$issue_branch: rebase conflicts")
      fi
    else
      echo "    🔍 [DRY RUN] Would rebase $issue_branch on $epic_branch"
      echo "    🔍 [DRY RUN] Would push with --force-with-lease"
      ((issue_success++))
    fi
  done
  
  cd - >/dev/null 2>&1
done

echo ""

# Final summary
if [ -z "$DRY_RUN" ]; then
  echo "🎉 Rebase Complete!"
else
  echo "🔍 Dry Run Complete!"
fi
echo "==================="
echo ""
echo "📊 Statistics:"
echo "  Epics processed: $epic_success/$(($epic_success + $epic_conflicts)) $([ $epic_conflicts -eq 0 ] && echo "✅" || echo "⚠️")"
echo "  Issues processed: $issue_success/$(($issue_success + $issue_conflicts)) $([ $issue_conflicts -eq 0 ] && echo "✅" || echo "⚠️")"
echo "  Total conflicts: $(($epic_conflicts + $issue_conflicts))"

if [ ${#conflict_list[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Conflicts requiring manual resolution:"
  for conflict in "${conflict_list[@]}"; do
    echo "    • $conflict"
  done
  echo ""
  echo "💡 Resolve conflicts manually, then re-run this command"
  exit 1
else
  echo ""
  if [ -z "$DRY_RUN" ]; then
    echo "🔗 All branches are now up to date with main!"
  else
    echo "🔗 All branches would be rebased successfully!"
  fi
  exit 0
fi