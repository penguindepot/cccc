# CCCC Context Management Strategy

## Overview

Effective context management is critical for CCCC's performance and usability. This document outlines best practices, optimization strategies, and guidelines for managing context across AI-assisted development workflows while minimizing overhead and maximizing effectiveness.

## Context Management Principles

### Core Principles

1. **Context Minimalism**: Load only the information necessary for the specific operation
2. **Lazy Loading**: Defer context loading until decision points require it
3. **Smart Caching**: Cache frequently accessed context with intelligent invalidation
4. **Hierarchical Loading**: Progress from minimal → light → full context as needed
5. **Agent Isolation**: Provide task-specific context to sub-agents, not full system context

### Performance Philosophy

- **AI for Decisions, Bash for Execution**: Use LLM context for reasoning, bash for routine operations
- **Context as a Service**: Treat context loading as an expensive operation to be optimized
- **Progressive Enhancement**: Start with minimal context and add complexity only when needed
- **Separation of Concerns**: Keep human-readable and machine-processable context separate

## Context Categories and Usage Patterns

### Context Hierarchy

```
CCCC Context Hierarchy
├── No Context (Pure Bash)
│   ├── System operations (status, log, file management)
│   ├── Git operations (branch, commit, push)
│   └── Utility functions (backup, cleanup, monitoring)
├── Minimal Context (Summaries Only)
│   ├── Quick decision-making operations  
│   ├── Status updates and simple validations
│   └── API calls with predetermined parameters
├── Light Context (1-2 Files)
│   ├── Issue management operations
│   ├── MR status and basic updates
│   └── Simple integrations
└── Full Context (All Files)
    ├── PRD creation and complex planning
    ├── Epic analysis and decomposition  
    └── System-wide decisions and architecture
```

### Context Loading Decision Matrix

| Operation Type | Context Level | Files Loaded | Use Case Examples |
|---------------|---------------|--------------|-------------------|
| **Pure Bash** | None | 0 files | `git status`, `ls`, `backup create` |
| **Minimal** | Summary | 1-3 summary files | `issue status`, `mr comment`, `quick update` |
| **Light** | Targeted | 2-4 specific files | `issue update`, `mr review`, `branch merge` |
| **Full** | Complete | All 9 context files | `prd create`, `epic analyze`, `system design` |

## Context File Strategy

### Current Context Files (9 Files)

#### Essential Context (Always Load for Full Context)
1. **project-overview.md**: High-level project understanding and goals
2. **progress.md**: Current status, recent work, and active tasks
3. **tech-context.md**: Technology stack and key technical decisions

#### Contextual Files (Load Based on Operation Type)
4. **project-structure.md**: Directory organization (for file operations)
5. **system-patterns.md**: Architecture patterns (for design decisions)
6. **product-context.md**: User needs and requirements (for feature work)
7. **project-style-guide.md**: Coding standards (for implementation)
8. **project-vision.md**: Long-term direction (for strategic decisions)
9. **project-brief.md**: Core purpose and scope (for requirement alignment)

### Context Summarization Strategy

#### Automated Summary Generation
```bash
# Generate context summaries for efficient loading
generate_context_summaries() {
    local context_dir="/.cccc/context"
    local summary_dir="/.cccc/context/summaries"
    
    mkdir -p "$summary_dir"
    
    for context_file in "$context_dir"/*.md; do
        local basename=$(basename "$context_file" .md)
        local summary_file="$summary_dir/${basename}.yaml"
        
        # Extract key information
        {
            echo "# Auto-generated summary of $basename"
            echo "file: $(basename "$context_file")"
            echo "last_updated: $(stat -f %Sm -t %Y-%m-%dT%H:%M:%SZ "$context_file")"
            echo "size_lines: $(wc -l < "$context_file")"
            echo ""
            echo "key_sections:"
            grep "^## " "$context_file" | sed 's/^## /- /'
            echo ""
            echo "highlights:"
            grep -E "^\*\*|^- \*\*|^### " "$context_file" | head -5 | sed 's/^\*\*/- /' | sed 's/^### /- /'
            echo ""
            echo "summary: |"
            head -10 "$context_file" | tail -5 | sed 's/^/  /'
        } > "$summary_file"
    done
}
```

#### Smart Summary Content
```yaml
# Example: project-overview.yaml (summary)
file: project-overview.md
last_updated: 2025-08-28T17:40:00Z
size_lines: 203
token_estimate: 1200

key_sections:
- System Architecture
- Core Components  
- Current Status
- Technology Stack

highlights:
- CCCC is a command and context management system
- Production-ready with comprehensive workflow automation
- 5-layer architecture: Command → Context → PRD → Rules → Integration
- GitLab/GitHub dual-platform support

summary: |
  CCCC (Claude Code Command Center) provides persistent session management,
  structured requirement tracking, and deep GitLab/GitHub integration for
  enhanced developer productivity with Claude Code. Currently production-ready
  with complete MR lifecycle and context management capabilities.

context_triggers:
- epic_analysis: full_context_needed
- issue_management: light_context_sufficient  
- status_operations: minimal_context_sufficient
```

## Context Loading Optimization

### Lazy Loading Implementation

#### Context-Aware Command Pattern
```bash
#!/bin/bash
# Context loading decision engine

determine_context_level() {
    local command="$1" operation="$2"
    
    case "$command" in
        # No context needed - pure bash operations
        "status"|"log"|"branch"|"backup"|"cleanup")
            echo "none"
            ;;
        # Minimal context - simple decisions
        "issue:status"|"mr:comment"|"quick:*")
            echo "minimal"
            ;;
        # Light context - targeted operations  
        "issue:update"|"mr:review"|"epic:status")
            echo "light"
            ;;
        # Full context - complex reasoning
        "prd:*"|"epic:analyze"|"context:create")
            echo "full"
            ;;
        *)
            # Safe default - can be optimized based on usage patterns
            echo "light"
            ;;
    esac
}

load_context_by_level() {
    local level="$1"
    
    case "$level" in
        "none")
            # No context loading
            return 0
            ;;
        "minimal")
            load_context_summaries
            ;;
        "light")
            load_targeted_context "$OPERATION_TYPE"
            ;;
        "full")
            load_all_context_files
            ;;
    esac
}
```

#### Progressive Context Loading
```bash
# Start with minimal and upgrade as needed
progressive_context_loading() {
    local operation="$1"
    
    # Always start minimal
    load_context_summaries
    
    # Check if decision can be made
    if can_complete_operation "$operation" "minimal"; then
        return 0
    fi
    
    # Upgrade to light context
    load_targeted_context "$operation"
    
    if can_complete_operation "$operation" "light"; then
        return 0
    fi
    
    # Final upgrade to full context if needed
    log_info "Operation requires full context - upgrading"
    load_all_context_files
}

can_complete_operation() {
    local operation="$1" context_level="$2"
    
    case "$operation" in
        "issue_status_check")
            [[ "$context_level" != "none" ]]
            ;;
        "epic_decomposition")
            [[ "$context_level" == "full" ]]
            ;;
        "simple_git_operation")
            [[ "$context_level" == "none" ]]
            ;;
        *)
            # Conservative default - assume light context needed
            [[ "$context_level" != "none" ]]
            ;;
    esac
}
```

### Context Caching Strategy

#### Multi-Level Caching
```bash
# Level 1: Parsed Context Cache
cache_parsed_context() {
    local context_file="$1"
    local cache_file="/.cccc/cache/context/$(basename "$context_file" .md).json"
    
    # Parse and cache structured data
    {
        echo "{"
        echo "  \"file\": \"$context_file\","
        echo "  \"parsed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","  
        echo "  \"checksum\": \"$(sha256sum "$context_file" | cut -d' ' -f1)\","
        echo "  \"sections\": ["
        grep "^## " "$context_file" | sed 's/^## /    "/' | sed 's/$/"/' | paste -sd ',' -
        echo "  ],"
        echo "  \"size_lines\": $(wc -l < "$context_file")"
        echo "}"
    } > "$cache_file"
}

# Level 2: Context Summary Cache  
cache_context_summaries() {
    local summary_cache="/.cccc/cache/context/summaries.json"
    
    jq -n --argjson summaries "$(
        for summary in /.cccc/context/summaries/*.yaml; do
            yq -o json "$summary"
        done | jq -s .
    )" '{
        generated_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
        summaries: $summaries
    }' > "$summary_cache"
}

# Cache Validation and Invalidation
validate_context_cache() {
    local context_file="$1"
    local cache_file="/.cccc/cache/context/$(basename "$context_file" .md).json"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1  # Cache miss
    fi
    
    local cached_checksum=$(jq -r '.checksum' "$cache_file")
    local current_checksum=$(sha256sum "$context_file" | cut -d' ' -f1)
    
    [[ "$cached_checksum" == "$current_checksum" ]]
}
```

## Agent Context Management

### Agent Context Isolation Strategy

#### Minimal Agent Context Passing
```bash
# Instead of loading full context in agents
spawn_agent_with_minimal_context() {
    local agent_type="$1" task="$2" issue_number="$3"
    
    # Prepare minimal context environment
    export CCCC_TASK="$task"
    export CCCC_ISSUE_NUMBER="$issue_number"
    export CCCC_ISSUE_FILE="/.cccc/epics/${EPIC_NAME}/issues/${issue_number}.md"
    export CCCC_EPIC_NAME="$EPIC_NAME"
    export CCCC_CURRENT_PHASE="implementation"
    
    # Pass only the specific file content needed
    local context_data="{
        \"issue_body\": \"$(cat "$CCCC_ISSUE_FILE")\",
        \"epic_name\": \"$EPIC_NAME\",
        \"dependencies\": \"$(get_issue_dependencies "$issue_number")\"
    }"
    
    # Spawn agent with minimal context
    echo "$context_data" | claude-agent "$agent_type" --stdin-context
}

get_issue_dependencies() {
    local issue_number="$1"
    yq eval ".issues[] | select(.number == \"$issue_number\") | .dependencies // []" \
        "/.cccc/epics/${EPIC_NAME}/analysis.yaml" | \
        tr '\n' ',' | sed 's/,$//'
}
```

#### Agent-Specific Context Providers
```bash
# Specialized context functions for different agent types

# For file-analyzer agents
provide_file_context() {
    local file_path="$1"
    echo "{
        \"file_path\": \"$file_path\",
        \"file_size\": $(stat -f%z "$file_path"),
        \"last_modified\": \"$(stat -f %Sm -t %Y-%m-%dT%H:%M:%SZ "$file_path")\",
        \"file_type\": \"$(file -b "$file_path")\"
    }"
}

# For code-analyzer agents  
provide_code_context() {
    local issue_number="$1"
    local issue_body=$(cat "/.cccc/epics/${EPIC_NAME}/issues/${issue_number}.md")
    
    echo "{
        \"issue_description\": \"$issue_body\",
        \"related_files\": $(find_related_files "$issue_number"),
        \"git_context\": {
            \"branch\": \"$(git branch --show-current)\",
            \"recent_changes\": \"$(git log --oneline -5)\"
        }
    }"
}

# For test-runner agents
provide_test_context() {
    local test_pattern="$1"
    echo "{
        \"test_pattern\": \"$test_pattern\",
        \"test_files\": $(find . -name "*test*" -o -name "*spec*" | jq -R . | jq -s .),
        \"test_framework\": \"$(detect_test_framework)\"
    }"
}
```

## Context Usage Patterns by Operation

### Issue Management Operations

#### Light Context Pattern
```bash
# Issue operations typically need minimal project context
handle_issue_operation() {
    local operation="$1" issue_number="$2"
    
    # Load only progress and current status
    local context=$(jq -n \
        --arg progress "$(cat /.cccc/context/progress.md)" \
        --arg issue_body "$(cat "/.cccc/epics/${EPIC_NAME}/issues/${issue_number}.md")" \
        '{
            current_status: $progress,
            issue_details: $issue_body,
            context_level: "light"
        }')
    
    case "$operation" in
        "update")
            update_issue_with_light_context "$issue_number" "$context"
            ;;
        "status")
            check_issue_status "$issue_number"  # No context needed
            ;;
        "assign")
            assign_issue_with_context "$issue_number" "$context"
            ;;
    esac
}
```

### MR/PR Operations

#### Context Based on MR Stage
```bash
# Different MR operations need different context levels
handle_mr_operation() {
    local operation="$1" mr_id="$2"
    
    case "$operation" in
        "create"|"start")
            # Needs issue context + technical details
            local context_level="light"
            load_context_files "tech-context.md" "progress.md"
            ;;
        "review"|"approve")  
            # Needs minimal context for decisions
            local context_level="minimal"
            load_context_summaries
            ;;
        "fix"|"update")
            # Needs full technical context for implementation
            local context_level="full"
            load_context_files "tech-context.md" "system-patterns.md" "project-style-guide.md"
            ;;
        "cleanup")
            # Pure bash operation, no context
            local context_level="none"
            ;;
    esac
    
    execute_mr_operation "$operation" "$mr_id" "$context_level"
}
```

### Epic and PRD Operations

#### Full Context Pattern
```bash
# Complex operations that need comprehensive understanding
handle_complex_operation() {
    local operation="$1"
    
    case "$operation" in
        "prd:create"|"epic:analyze"|"system:design")
            # These operations require full context
            log_info "Loading full context for complex operation: $operation"
            load_all_context_files
            
            # Additional validation for complex operations
            validate_full_context_integrity
            ;;
        "epic:sync"|"project:migrate")
            # These need full context but can work with cached summaries initially
            if context_cache_valid "full"; then
                load_cached_full_context
            else
                load_all_context_files
                cache_full_context
            fi
            ;;
    esac
}

validate_full_context_integrity() {
    local missing_files=()
    
    for required_file in project-overview.md progress.md tech-context.md; do
        if [[ ! -f "/.cccc/context/$required_file" ]]; then
            missing_files+=("$required_file")
        fi
    done
    
    if (( ${#missing_files[@]} > 0 )); then
        log_error "Missing required context files: ${missing_files[*]}"
        return 1
    fi
}
```

## Context Quality and Maintenance

### Context Freshness Management

#### Automated Freshness Checking
```bash
# Check context file freshness and alert when stale
check_context_freshness() {
    local context_dir="/.cccc/context"
    local now=$(date +%s)
    local stale_threshold=259200  # 3 days in seconds
    
    for context_file in "$context_dir"/*.md; do
        local file_age=$(( now - $(stat -f %m "$context_file") ))
        local basename=$(basename "$context_file")
        
        if (( file_age > stale_threshold )); then
            local days_old=$(( file_age / 86400 ))
            echo "⚠️ $basename is $days_old days old (consider updating)"
            
            # Add to stale context report
            jq -n \
                --arg file "$basename" \
                --arg age_days "$days_old" \
                --arg last_modified "$(stat -f %Sm -t %Y-%m-%dT%H:%M:%SZ "$context_file")" \
                '{
                    file: $file,
                    age_days: $age_days,
                    last_modified: $last_modified,
                    status: "stale"
                }' >> "/.cccc/logs/stale-context.json"
        fi
    done
}
```

#### Context Update Recommendations
```bash
# Suggest context updates based on recent activity
suggest_context_updates() {
    local git_activity=$(git log --since="3 days ago" --oneline | wc -l)
    local issue_activity=$(find /.cccc/epics -name "*.md" -mtime -3 | wc -l)
    
    if (( git_activity > 5 )); then
        echo "📝 Consider updating progress.md (${git_activity} recent commits)"
    fi
    
    if (( issue_activity > 2 )); then
        echo "📝 Consider updating project-structure.md (${issue_activity} issue changes)"
    fi
    
    # Check for configuration changes
    if [[ /.cccc/cccc-config.yml -nt /.cccc/context/tech-context.md ]]; then
        echo "📝 Consider updating tech-context.md (config changed)"
    fi
}
```

### Context Consistency Validation

#### Cross-Reference Validation
```bash
# Validate consistency between context files
validate_context_consistency() {
    local errors=()
    
    # Check project name consistency
    local overview_name=$(grep -E "^# " /.cccc/context/project-overview.md | head -1 | cut -d' ' -f2-)
    local brief_name=$(grep -E "^# " /.cccc/context/project-brief.md | head -1 | cut -d' ' -f2-)
    
    if [[ "$overview_name" != "$brief_name" ]]; then
        errors+=("Project name mismatch between overview and brief")
    fi
    
    # Check status consistency between progress and overview
    local overview_status=$(grep -A5 "## Current Status" /.cccc/context/project-overview.md | grep -E "Phase|Status" | head -1)
    local progress_status=$(grep -A5 "## Project Status" /.cccc/context/progress.md | grep -E "Phase|Status" | head -1)
    
    # Report consistency issues
    if (( ${#errors[@]} > 0 )); then
        echo "Context Consistency Issues:"
        printf "❌ %s\n" "${errors[@]}"
        return 1
    else
        echo "✅ Context files are consistent"
        return 0
    fi
}
```

## Context Performance Monitoring

### Context Usage Analytics
```bash
# Track context loading patterns and performance
track_context_usage() {
    local operation="$1" context_level="$2" load_time="$3"
    
    jq -n \
        --arg operation "$operation" \
        --arg level "$context_level" \
        --arg time "$load_time" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            operation: $operation,
            context_level: $level,
            load_time_seconds: $time,
            timestamp: $timestamp
        }' >> "/.cccc/metrics/context-usage.json"
}

# Generate context efficiency reports
generate_context_report() {
    local report_file="/.cccc/reports/context-efficiency-$(date +%Y-%m-%d).json"
    
    # Analyze context usage patterns
    local total_operations=$(jq -s length /.cccc/metrics/context-usage.json)
    local minimal_ops=$(jq -s 'map(select(.context_level == "minimal")) | length' /.cccc/metrics/context-usage.json)
    local light_ops=$(jq -s 'map(select(.context_level == "light")) | length' /.cccc/metrics/context-usage.json)
    local full_ops=$(jq -s 'map(select(.context_level == "full")) | length' /.cccc/metrics/context-usage.json)
    
    # Calculate efficiency metrics
    local efficiency_score=$(echo "scale=2; ($minimal_ops + $light_ops * 0.7) / $total_operations * 100" | bc)
    
    jq -n \
        --arg total "$total_operations" \
        --arg minimal "$minimal_ops" \
        --arg light "$light_ops" \
        --arg full "$full_ops" \
        --arg efficiency "$efficiency_score" \
        '{
            report_date: (now | strftime("%Y-%m-%d")),
            summary: {
                total_operations: $total,
                context_distribution: {
                    minimal: $minimal,
                    light: $light,
                    full: $full
                },
                efficiency_score: $efficiency
            },
            recommendations: [
                if ($efficiency | tonumber) < 60 then
                    "Consider converting more operations to minimal/light context"
                else empty end,
                if ($full | tonumber) > ($total | tonumber) * 0.3 then
                    "High full-context usage detected - review operation classifications"
                else empty end
            ]
        }' > "$report_file"
        
    echo "Context efficiency report generated: $report_file"
}
```

This context strategy provides a comprehensive framework for optimizing CCCC's context management while maintaining the system's powerful workflow capabilities. The key is progressive loading, intelligent caching, and operation-specific context determination to achieve the 60-80% context reduction target.