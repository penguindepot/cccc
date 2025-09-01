---
allowed-tools: 
---

# context:close

End your development session cleanly by updating context, committing changes, and rebasing branches.

## Description

This command performs three essential end-of-session tasks in sequence:
1. **Updates context** - Refreshes project documentation to reflect current state
2. **Commits and pushes** - Saves and shares your work to remote
3. **Rebases branches** - Ensures all branches are up-to-date with main

## Usage
```
/context:close
```

## Instructions

This is a meta-command that executes three Claude Code commands in sequence.
The assistant should execute these commands in order:

### Execution Sequence

**Step 1: Execute `/context:update`**
- Update the project context documentation 
- Ensure all context files reflect current project state

**Step 2: Execute `/utils:push`**
- Commit and push all changes to remote
- Create appropriate commit messages for different changes

**Step 3: Execute `/utils:rebase-all`**
- Rebase all epic branches on main
- Rebase all issue branches on their respective epics

### Output Format

```
🔄 Closing development session...

📝 Step 1/3: Updating context...
[Execute /context:update command and show results]

📤 Step 2/3: Committing and pushing changes...
[Execute /utils:push command and show results]

🔄 Step 3/3: Rebasing all branches...
[Execute /utils:rebase-all command and show results]

🎉 Session closed successfully!

Your development session has been cleanly closed with:
  ✅ Context documentation updated
  ✅ Changes committed and pushed  
  ✅ All branches rebased and synchronized

Ready for your next session! Use /context:prime to restore context.
```

## Error Handling

If any step fails:
- Stop execution at the failed step
- Report the error clearly to the user
- User can run remaining commands manually if needed
- Each command has its own error handling

## Important Notes

1. **Meta-Command**: This coordinates other Claude Code commands, doesn't run bash scripts
2. **Sequential Execution**: Each command must complete before starting the next
3. **Order Matters**: Commands run in specific order for consistency
4. **Clean State**: Ensures you leave the project in a good state
5. **Session Continuity**: Sets up for easy context restoration next time
6. **No Arguments**: Simple command with no configuration needed