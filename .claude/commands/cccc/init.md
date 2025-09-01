---
allowed-tools: Bash
---

# Initialize CCCC System

Initialize the CCCC system by detecting your Git hosting platform and configuring the appropriate CLI tools.

## Purpose

This command sets up CCCC for your specific Git platform (GitHub or GitLab) by:
- Installing and configuring the appropriate CLI tools (gh/glab)
- Setting up authentication 
- Detecting git remote configuration
- Creating CCCC configuration file

## Usage

Ask the user to choose their Git hosting platform:
1. GitHub
2. GitLab

Then run the initialization command based on their choice:
- If they choose GitHub: run `bash .claude/scripts/cccc/init.sh github`
- If they choose GitLab: run `bash .claude/scripts/cccc/init.sh gitlab`

Show the complete output without truncation.

## Next Steps

After initialization, recommend:
1. Run `/context:create` to set up project context
2. Start workflow with `/cccc:prd:new <feature-name>`
