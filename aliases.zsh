# aliases.zsh — Zsh-Specific Aliases and Functions

# Global Aliases (expand anywhere in the command line)
alias -g G='| grep'
alias -g GI='| grep -i'
alias -g L='| less'
alias -g H='| head'
alias -g T='| tail'
alias -g W='| wc -l'
alias -g S='| sort'
alias -g U='| uniq'
alias -g Y='| pbcopy'
alias -g X='| xargs'
alias -g J='| jq'

# Named Directories (Hash)
hash -d desk="$HOME/Desktop"
hash -d xdots="$HOME/.config"
hash -d zdots="$ZDOTDIR"
hash -d projects="$HOME/projects"

# Directory Aliases (Zsh-friendly)
alias projects='nocorrect ~projects'
alias desk='nocorrect ~desk'
alias xdots='nocorrect ~xdots'
alias zdots='nocorrect ~zdots'

# Modern DSL Patterns (Zsh-specific fpath)
alias fpath='echo $fpath | tr " " "\n"'

# Zsh-only CLI tools
alias he='history_enquire'
alias bounce='reload'
alias claude-mem='bun "$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'

# Zsh Globbing shorthands
alias prunedirs='rm -d **/*(/^F)'

# Zdots Platform Control (z* prefix — work from any directory)
alias zstatus='zdots-status'                          # live TUI dashboard
# zaider is a shell function defined in providers/ai/aider.zsh (sourced by 95-ai.zsh)
alias zcheck='make -C "${ZDOTDIR}" check-fast'        # shell integrity (fast)
alias zcheck-full='make -C "${ZDOTDIR}" check'        # shell integrity (full)
alias ztest='make -C "${ZDOTDIR}" test'               # bats suite only
alias zhealth='zdots-ctl check'                       # platform + service health
alias zup='zdots-ctl up'                              # start all services
alias zdown='zdots-ctl down'                          # stop all services
alias zreset='zdots-ctl reset'                        # full platform restart
alias zmake='make -C "${ZDOTDIR}"'                    # any make target from anywhere
alias zlogs='llama-ctl logs'                          # tail llama.cpp server log
alias zlogs-otel='otel-collector logs'                # tail OTel collector log
alias zlogs-ci='local-ci logs'                        # tail LGTM stack log

# AI Recipes (pre-built scenarios — run with no args for usage)
alias zmorning='recipes/morning'                      # daily briefing: health + history + suggestions
alias zstandup='recipes/standup'                      # git history → standup summary
alias zpre-push='recipes/pre-push'                    # review unpushed commits before pushing
alias zcommit-recipe='recipes/commit'                 # review staged diff → generate message → commit
alias zlog-errors='recipes/log-errors'                # triage service log errors with AI

# AI Shell Intelligence (local model via ai-query)
alias zcommit='commit-msg'                            # draft commit message from staged diff
alias zreview='diff-review'                           # review staged diff for issues
alias zhistory='history-analyze'                      # shell history frequency report
alias zhistory-ai='history-analyze --ai'              # + AI optimization suggestions
alias zaliases='alias-suggest'                        # suggest aliases from history
