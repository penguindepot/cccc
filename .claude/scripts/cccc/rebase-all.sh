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

# Save current branch to return to it later
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Discover epic branches
if [ -n "$EPIC_FILTER" ]; then
  # Check if specific epic branch exists
  if ! git branch -a | grep -q "epic/$EPIC_FILTER"; then
    echo "❌ Epic branch not found: epic/$EPIC_FILTER"
    exit 1
  fi
  epic_branches=("epic/$EPIC_FILTER")
  echo "🎯 Targeting specific epic: $EPIC_FILTER"
else
  # Find all epic branches
  epic_branches=($(git branch -a | grep "epic/" | sed 's/^[* ]*//' | sed 's/^remotes\/[^\/]*\///' | sort -u))
  if [ ${#epic_branches[@]} -eq 0 ]; then
    echo "❌ No epic branches found"
    echo "Create epic branches using: /cccc:epic:sync <epic_name>"
    exit 1
  fi
  echo "📁 Found ${#epic_branches[@]} epic branch(es)"
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

for epic_branch in "${epic_branches[@]}"; do
  epic_name=$(echo "$epic_branch" | sed 's/^epic\///')
  echo "Epic $epic_name:"
  
  # Fetch latest
  echo "  📥 Fetching latest from $git_remote..."
  if [ -z "$DRY_RUN" ]; then
    if ! git fetch "$git_remote" >/dev/null 2>&1; then
      echo "  ❌ Failed to fetch from remote"
      ((epic_conflicts++))
      conflict_list+=("$epic_name: fetch failed")
      continue
    fi
  else
    echo "  🔍 [DRY RUN] Would fetch from $git_remote"
  fi
  
  # Check if epic branch exists locally
  if ! git show-ref --verify --quiet "refs/heads/$epic_branch"; then
    echo "  ⚠️  Epic branch exists only on remote, checking out..."
    if [ -z "$DRY_RUN" ]; then
      git checkout -b "$epic_branch" "$git_remote/$epic_branch" >/dev/null 2>&1
    else
      echo "  🔍 [DRY RUN] Would checkout remote branch"
    fi
  fi
  
  # Checkout epic branch
  if [ -z "$DRY_RUN" ]; then
    git checkout "$epic_branch" >/dev/null 2>&1
  else
    echo "  🔍 [DRY RUN] Would checkout $epic_branch"
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
  
  # Check if rebase is needed
  if [ -z "$DRY_RUN" ]; then
    behind_count=$(git rev-list --count HEAD.."$git_remote/main" 2>/dev/null || echo "unknown")
    if [ "$behind_count" = "0" ]; then
      echo "  ✅ $epic_branch already up to date"
      ((epic_success++))
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
done

echo ""

# Phase 2: Rebase issue branches on epics
echo "Phase 2: Rebasing issue branches on epics"
echo "=========================================="

for epic_branch in "${epic_branches[@]}"; do
  epic_name=$(echo "$epic_branch" | sed 's/^epic\///')
  echo "Epic $epic_name:"
  
  # Find all issue branches (both local and remote)
  issue_branches=($(git branch -a | grep "issue/" | sed 's/^[* ]*//' | sed 's/^remotes\/[^\/]*\///' | sort -u))
  
  # Filter issue branches that belong to this epic (based on analysis.yaml if it exists)
  epic_issue_branches=()
  if [ -f ".cccc/epics/$epic_name/analysis.yaml" ]; then
    # Get issue IDs from analysis.yaml
    issue_ids=$(yq '.issues | keys | .[]' ".cccc/epics/$epic_name/analysis.yaml" 2>/dev/null | tr -d '"')
    for issue_id in $issue_ids; do
      issue_branch="issue/$issue_id"
      # Check if this issue branch exists
      for branch in "${issue_branches[@]}"; do
        if [ "$branch" = "$issue_branch" ]; then
          epic_issue_branches+=("$issue_branch")
        fi
      done
    done
  else
    # If no analysis.yaml, we can't determine which issues belong to which epic
    echo "  ⚠️  No analysis.yaml found, skipping issue branches for $epic_name"
    continue
  fi
  
  if [ ${#epic_issue_branches[@]} -eq 0 ]; then
    echo "  📝 No issue branches found for this epic"
    continue
  fi
  
  echo "  📋 Found ${#epic_issue_branches[@]} issue branch(es)"
  
  for issue_branch in "${epic_issue_branches[@]}"; do
    echo "  🌿 Processing $issue_branch..."
    
    # Check if issue branch exists locally
    if ! git show-ref --verify --quiet "refs/heads/$issue_branch"; then
      echo "    ⚠️  Issue branch exists only on remote, checking out..."
      if [ -z "$DRY_RUN" ]; then
        git checkout -b "$issue_branch" "$git_remote/$issue_branch" >/dev/null 2>&1
      else
        echo "    🔍 [DRY RUN] Would checkout remote branch"
      fi
    fi
    
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
done

# Return to original branch
if [ -z "$DRY_RUN" ]; then
  git checkout "$current_branch" >/dev/null 2>&1
fi

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