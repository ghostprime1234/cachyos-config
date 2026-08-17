# ~/.zshrc

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# 1. ALIASES
alias resource='source ~/.zshrc'
alias zshrc='micro ~/.zshrc'
alias obsidian='obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland'

alias mds-bak="$HOME/cachyos-config/scripts/mds_backup.sh"
alias mds-pull="$HOME/cachyos-config/scripts/mds_pull.sh"
alias unisync='/usr/local/bin/unisync'

alias lab-push="~/Big-Data-Cluster/infra/sync_labs.sh --push"
alias lab-pull="~/Big-Data-Cluster/infra/sync_labs.sh --pull"

# =====================================================================
# 🗄 MULTI-DEVICE COMPATIBLE CLIENT ALIASES (The Pure Way)
# =====================================================================

# Dynamically pull in shared university data science shortcuts
[[ -f ~/Big-Data-Cluster/zshrc_aliases.txt ]] && source ~/Big-Data-Cluster/zshrc_aliases.txt

# 2. ENVIRONMENT VARIABLES
export TERM=xterm-256color
export TERMINFO_DIRS=/usr/share/terminfo
export EDITOR=micro
export VISUAL=micro
export GTK_USE_PORTAL=1
export XDG_CURRENT_DESKTOP=KDE
export XDG_MENU_PREFIX=plasma-

# 3. FAST SSH AGENT (Safe Version)
if ! pgrep -u $USER ssh-agent > /dev/null; then
    eval $(ssh-agent -s) > /dev/null
else
    # Native Zsh globbing assignment (N[1] extracts the first match cleanly)
    local active_sockets=( /tmp/ssh-*/agent.*(N[1]) )
    [[ -n $active_sockets ]] && export SSH_AUTH_SOCK=$active_sockets
fi

# 4. FAST CONDA INITIALIZATION

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/michael/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/michael/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/michael/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/michael/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# Big Data Cluster tools
export PATH="$HOME/Big-Data-Cluster/bin:$PATH"

# 5. UNIVERSITY AUTO-ENV SYNC
university_auto_env_sync() {
    local root_home="$HOME/Documents/University"
    local root_mnt="/mnt/Data/University"

    [[ ! -d "$root_home" ]] && root_home="/dev/null"
    [[ ! -d "$root_mnt" ]] && root_mnt="/dev/null"

    # 1. THE EXIT GUARD - Now keeps 'base' active instead of full deactivation
    if [[ "$PWD" != "$root_home"* ]] && [[ "$PWD" != "$root_mnt"* ]]; then
        if [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
            conda activate base
        fi
        return
    fi

    # 2. FIND THE SUBJECT CODE
    local subject_code=$(echo "$PWD" | grep -oP "(?<=[0-9]{4}/)[A-Z]{3}[0-9]{4}(?= - )" | head -n 1)
    if [[ -z "$subject_code" ]]; then
        subject_code=$(echo "$PWD" | grep -oP "[A-Z]{3}[0-9]{4}" | head -n 1)
    fi

    # 3. ACTIVATION LOGIC
    if [[ -n "$subject_code" ]]; then
        if [[ -d "$HOME/.conda/envs/$subject_code" ]]; then
            [[ "$CONDA_DEFAULT_ENV" != "$subject_code" ]] && conda activate "$subject_code"
            return
        fi
    fi

    # 4. NEUTRAL ZONE
    if [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
        conda activate base
    fi
}

# Hooks and Startup
autoload -U add-zsh-hook
add-zsh-hook chpwd university_auto_env_sync
university_auto_env_sync

# 6. PERSONAL PROJECT AUTOMATION (direnv)
if command -v direnv > /dev/null; then
    eval "$(direnv hook zsh)"
fi

if [[ -f ~/Big-Data-Cluster/.env ]]; then
  source ~/Big-Data-Cluster/.env
fi

spark-master() {
  local rel_dir="${PWD#$COURSE_WORKSPACE}"

  docker exec -it spark-master \
    /opt/spark/bin/spark-submit "/course/${rel_dir}/$1"
}
# 7. THE FINAL WORD (Source p10k ONCE at the very end)
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export PATH="$HOME/.local/bin:$PATH"

