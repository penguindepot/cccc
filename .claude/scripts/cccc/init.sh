#!/bin/bash

echo "Initializing..."
echo ""
echo ""

echo " ██████╗ ██████╗ ██████╗ ██████╗"
echo "██╔════╝██╔════╝██╔════╝██╔════╝"
echo "██║     ██║     ██║     ██║     "
echo "╚██████╗╚██████╗╚██████╗╚██████╗"
echo " ╚═════╝ ╚═════╝ ╚═════╝ ╚═════╝"

echo "┌─────────────────────────────────┐"
echo "│ Claude Code Command Center      │"
echo "│ by NOONE                        │"
echo "└─────────────────────────────────┘"
echo ""
echo ""

echo "🚀 Initializing Claude Code CC System"
echo "======================================"
echo ""

# Hybrid mode: Check for command-line arguments or use interactive prompts
if [ $# -gt 0 ]; then
  # Automated mode - argument provided
  case "$1" in
    github)
      GIT_SYSTEM="github"
      echo "🔧 Git hosting platform: GitHub (automated mode)"
      ;;
    gitlab)
      GIT_SYSTEM="gitlab"
      echo "🔧 Git hosting platform: GitLab (automated mode)"
      ;;
    *)
      echo "❌ Invalid argument. Usage: $0 [github|gitlab]"
      echo "   Or run without arguments for interactive mode."
      exit 1
      ;;
  esac
else
  # Interactive mode - no arguments provided
  echo "🔧 Choose your Git hosting platform:"
  echo "  1. GitHub"
  echo "  2. GitLab"
  echo ""
  read -p "Enter your choice (1-2): " git_choice

  case $git_choice in
    1)
      GIT_SYSTEM="github"
      echo "  ✅ GitHub selected"
      ;;
    2)
      GIT_SYSTEM="gitlab"
      echo "  ✅ GitLab selected"
      ;;
    *)
      echo "  ❌ Invalid choice. Initialization cancelled."
      exit 1
      ;;
  esac
fi

echo ""

# Check for required tools
echo "🔍 Checking dependencies..."

# Check and install CLI tools based on selected system
if [ "$GIT_SYSTEM" = "github" ]; then
  # Check gh CLI
  if command -v gh &> /dev/null; then
    echo "  ✅ GitHub CLI (gh) installed"
  else
    echo "  ❌ GitHub CLI (gh) not found"
    echo ""
    echo "  Installing gh..."
    if command -v brew &> /dev/null; then
      brew install gh
    elif command -v apt-get &> /dev/null; then
      sudo apt-get update && sudo apt-get install gh
    else
      echo "  Please install GitHub CLI manually: https://cli.github.com/"
      exit 1
    fi
  fi
elif [ "$GIT_SYSTEM" = "gitlab" ]; then
  # Check glab CLI
  if command -v glab &> /dev/null; then
    echo "  ✅ GitLab CLI (glab) installed"
  else
    echo "  ❌ GitLab CLI (glab) not found"
    echo ""
    echo "  Installing glab..."
    if command -v brew &> /dev/null; then
      brew install glab
    elif command -v apt-get &> /dev/null; then
      sudo apt-get update && sudo apt-get install glab
    else
      echo "  Please install GitLab CLI manually: https://gitlab.com/gitlab-org/cli"
      exit 1
    fi
  fi
fi

# Check for yq (required for YAML parsing)
echo ""
echo "🔍 Checking YAML parser..."
if command -v yq &> /dev/null; then
  echo "  ✅ yq installed"
else
  echo "  ❌ yq not found (required for YAML parsing)"
  echo ""
  echo "  Installing yq..."
  if command -v brew &> /dev/null; then
    brew install yq
    echo "  ✅ yq installed via Homebrew"
  elif command -v apt-get &> /dev/null; then
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
    echo "  ✅ yq installed to /usr/local/bin/yq"
  else
    echo "  ⚠️ Could not auto-install yq"
    echo "  Please install manually:"
    echo "    macOS: brew install yq"
    echo "    Linux: wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq"
    echo "  ℹ️ Continuing initialization..."
  fi
fi

# Authentication based on selected system
echo ""
if [ "$GIT_SYSTEM" = "github" ]; then
  echo "🔐 Checking GitHub authentication..."
  if gh auth status &> /dev/null; then
    echo "  ✅ GitHub authenticated"
  else
    echo "  ⚠️ GitHub not authenticated"
    if [ $# -gt 0 ]; then
      # Automated mode - provide instructions
      echo "  📝 To authenticate, run: gh auth login"
      echo "  ℹ️ Continuing without authentication..."
    else
      # Interactive mode - attempt login
      echo "  Please authenticate with GitHub:"
      gh auth login
    fi
  fi
elif [ "$GIT_SYSTEM" = "gitlab" ]; then
  echo "🔐 Checking GitLab authentication..."
  if glab auth status &> /dev/null; then
    echo "  ✅ GitLab authenticated"
  else
    echo "  ⚠️ GitLab not authenticated"
    if [ $# -gt 0 ]; then
      # Automated mode - provide instructions
      echo "  📝 To authenticate, run: glab auth login"
      echo "  ℹ️ Continuing without authentication..."
    else
      # Interactive mode - attempt login
      echo "  Please authenticate with GitLab:"
      glab auth login
    fi
  fi
fi

# Check for extensions based on selected system
echo ""
if [ "$GIT_SYSTEM" = "github" ]; then
  echo "📦 Checking GitHub CLI extensions..."
  if gh extension list | grep -q "yahsan2/gh-sub-issue"; then
    echo "  ✅ gh-sub-issue extension installed"
  else
    echo "  📥 Installing gh-sub-issue extension..."
    gh extension install yahsan2/gh-sub-issue
  fi
elif [ "$GIT_SYSTEM" = "gitlab" ]; then
  echo "📦 GitLab CLI ready (no additional extensions needed)"
fi

# Create CCCC data directory structure
echo ""
echo "📁 Creating CCCC data directories..."
mkdir -p .cccc/prds
mkdir -p .cccc/epics
mkdir -p .cccc/context
echo "  ✅ CCCC directories created"

# Check for git
echo ""
echo "🔗 Checking Git configuration..."
if git rev-parse --git-dir > /dev/null 2>&1; then
  echo "  ✅ Git repository detected"

  # Check remote
  if git remote -v | grep -q origin; then
    remote_url=$(git remote get-url origin)
    echo "  ✅ Remote configured: $remote_url"
  else
    echo "  ⚠️ No remote configured"
    echo "  Add with: git remote add origin <url>"
  fi
else
  echo "  ⚠️ Not a git repository"
  echo "  Initialize with: git init"
fi


# Detect appropriate git remote based on platform choice
echo "🔍 Detecting git remote for $GIT_SYSTEM..."
GIT_REMOTE=""

if git remote -v | grep -q origin; then
  remote_url=$(git remote get-url origin)
  if [ "$GIT_SYSTEM" = "github" ] && echo "$remote_url" | grep -q "github"; then
    GIT_REMOTE="origin"
    echo "  ✅ Using 'origin' remote (GitHub): $remote_url"
  elif [ "$GIT_SYSTEM" = "gitlab" ] && echo "$remote_url" | grep -q "gitlab"; then
    GIT_REMOTE="origin"
    echo "  ✅ Using 'origin' remote (GitLab): $remote_url"
  fi
fi

# If origin doesn't match platform, look for platform-specific remote
if [ -z "$GIT_REMOTE" ]; then
  if [ "$GIT_SYSTEM" = "github" ] && git remote -v | grep -q github; then
    GIT_REMOTE=$(git remote -v | grep github | head -1 | cut -f1)
    echo "  ✅ Using '$GIT_REMOTE' remote (GitHub)"
  elif [ "$GIT_SYSTEM" = "gitlab" ] && git remote -v | grep -q gitlab; then
    GIT_REMOTE=$(git remote -v | grep gitlab | head -1 | cut -f1)
    echo "  ✅ Using '$GIT_REMOTE' remote (GitLab)"
  fi
fi

# Fallback to origin if nothing else found
if [ -z "$GIT_REMOTE" ]; then
  GIT_REMOTE="origin"
  echo "  ⚠️ Using fallback 'origin' remote (may not match platform)"
fi

# Save platform choice and remote to config file
echo "💾 Saving configuration..."
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > .cccc/cccc-config.yml << EOF
# CCCC System Configuration
# This file is created by /cccc:init and stores the chosen git platform and remote

git_platform: $GIT_SYSTEM
git_remote: $GIT_REMOTE
initialized_date: $current_date
EOF

# Summary
echo ""
echo "✅ Initialization Complete!"
echo "=========================="
echo ""
echo "📊 System Status:"
if [ "$GIT_SYSTEM" = "github" ]; then
  gh --version | head -1
  echo "  Extensions: $(gh extension list | wc -l) installed"
  echo "  Auth: $(gh auth status 2>&1 | grep -o 'Logged in to [^ ]*' || echo 'Not authenticated')"
elif [ "$GIT_SYSTEM" = "gitlab" ]; then
  glab --version | head -1
  echo "  Auth: $(glab auth status 2>&1 | grep -o 'Logged in to [^ ]*' || echo 'Not authenticated')"
fi
echo "  Platform: $GIT_SYSTEM"
echo "  YAML Parser: $(command -v yq >/dev/null && echo 'yq installed' || echo 'yq missing')"
echo "  Git Remote: $GIT_REMOTE (saved to .cccc/cccc-config.yml)"
echo ""
echo "🎯 Next Steps:"
echo "  1. Set up project context: /context:create"
echo "  2. Create your first PRD: /cccc:prd:new <feature-name>"
echo "  3. Start development workflow"
echo ""
echo "💡 Tips:"
echo "  - Use /context:prime at the start of each AI session"
echo "  - PRISM has already configured your CLAUDE.md with CCCC rules"

exit 0
