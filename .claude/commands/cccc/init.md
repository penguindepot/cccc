---
allowed-tools: Bash
---

Ask the user to choose their Git hosting platform:
1. GitHub
2. GitLab

Then run using a sub-agent the appropriate initialization command based on their choice:
- If they choose GitHub: run `bash .claude/scripts/cccc/init.sh github`
- If they choose GitLab: run `bash .claude/scripts/cccc/init.sh gitlab`

Show the complete output without truncation.
