# Commands

Complete reference of all commands available in the Claude Code Command Center (CCCC) system.

## Initial Setup
- `/cccc:init` - Install dependencies and configure GitHub or Gitlab

## Context Management
- `/cccc:context:create` - Generate comprehensive project context documentation
- `/cccc:context:prime` - Load context at the start of new sessions
- `/cccc:context:update` - Keep context current as project evolves
- `/cccc:context:validate` - Ensure context integrity and freshness

## PRD Management
- `/cccc:prd:new <feature_name>` - Create structured Product Requirements Document
- `/cccc:prd:parse <feature_name>` - Convert PRD into actionable implementation epic

## Epic Management  
- `/cccc:epic:decompose <epic_name>` - Break epic into concrete, actionable tasks
- `/cccc:epic:analyze <epic_name>` - Analyze epic to decompose all tasks into parallel GitHub issues with implementation sketches
- `/cccc:epic:sync <epic_name>` - Sync epic and individual issues to GitLab/GitHub with cross-references
- `/cccc:epic:next-issue <epic_name>` - Get dependency-aware recommendations for next issue to work on
- `/cccc:epic:update-status <epic_name>` - Update local issue status from GitLab/GitHub API

## Issue Management
- `/cccc:issue:update <epic_name> <issue_id>` - Update local issue with latest platform content and comments
- `/cccc:issue:mr <epic_name> <issue_id>` - Create merge request (GitLab) or pull request (GitHub) for specific issue

## Merge Request Management
- `/cccc:mr:start <epic_name> <issue_id>` - Start implementation work on existing MR by launching agent

## Utilities
- `/cccc:utils:push` - Commit and push all changes with organized commits
- `/cccc:utils:rebase-all [--dry-run] [epic_name]` - Rebase all epic branches on main and all issue branches on epics
