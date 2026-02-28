##############################################
# Initialize zsh completion system (must be early)
##############################################
autoload -Uz compinit
compinit

##############################################
export PATH=/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
##############################################

##############################################
# Lazy-load nvm (defers ~1.2s of startup time)
# nvm, node, npm, npx, and yarn will load nvm on first use
##############################################
export NVM_DIR="$HOME/.nvm"

# Add node to PATH immediately (no nvm overhead) so commands work instantly
export PATH="$NVM_DIR/versions/node/v24.12.0/bin:$PATH"

# Lazy-load nvm itself only when explicitly called
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
  nvm "$@"
}

##############################################
# Development Aliases
##############################################

# Code quality
alias prettier='yarn run prettier'
alias eslint='yarn eslint --fix'
alias fmt='yarn run prettier'

# Git helpers
alias gpr='gh pr create --draft'
alias gprv='gh pr view --web'

# Quick search (uses ripgrep)
alias rgts='rg --type-add "ts:*.{ts,tsx}" --type ts'
alias rgjs='rg --type js'

# DNS and cache flush (Mac)
alias flushcache='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo "DNS cache flushed"'
alias fix-dns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo "DNS cache flushed"'

# Node/npm troubleshooting
alias npmci='npm ci'

# Claude Code alias
alias c="claude"

# claude-statusline
export PATH="$HOME/.local/bin:$PATH"

##############################################
# Starship prompt (fast, cross-shell prompt)
##############################################
eval "$(starship init zsh)"

# pyenv config
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"
