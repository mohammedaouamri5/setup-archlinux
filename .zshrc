# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="arrow"




#  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
#  fi


# wallust run ~/.THE-WALLPAPER





# List of plugins used
plugins=( 
    git 
    sudo 
    zsh-256color 
    zsh-autosuggestions 
    # you-should-use
    # zsh-default-behavior
    zsh-autosuggestions 
    zsh-syntax-highlighting 
    vscode 
    zoxide 
    battery 
    emoji 
    cp 
    extract
    git-auto-fetch
    git-commit 
    git-escape-magic 
    git-extras 
    git-flow 
    git-flow-avh 
    git-hubflow 
    git-lfs 
    gitfast 
    github 
    gitignore
    golang
    history
    npm 
    nvm
    postgres
    redis-cli
    themes
    timer
 )
source $ZSH/oh-my-zsh.sh

# In case a command is not found, try to find the package that has it
function command_not_found_handler {
    local purple='\e[1;35m' bright='\e[0;1m' green='\e[1;32m' reset='\e[0m'
    printf 'zsh: command not found: %s\n' "$1"
    local entries=( ${(f)"$(/usr/bin/pacman -F --machinereadable -- "/usr/bin/$1")"} )
    if (( ${#entries[@]} )) ; then
        printf "${bright}$1${reset} may be found in the following packages:\n"
        local pkg
        for entry in "${entries[@]}" ; do
            local fields=( ${(0)entry} )
            if [[ "$pkg" != "${fields[2]}" ]] ; then
                printf "${purple}%s/${bright}%s ${green}%s${reset}\n" "${fields[1]}" "${fields[2]}" "${fields[3]}"
            fi
            printf '    /%s\n' "${fields[4]}"
            pkg="${fields[2]}"
        done
    fi
    return 127
}

# Detect the AUR wrapper
if pacman -Qi yay &>/dev/null ; then
   aurhelper="yay"
elif pacman -Qi paru &>/dev/null ; then
   aurhelper="paru"
fi

function in {
    local -a inPkg=("$@")
    local -a arch=()
    local -a aur=()

    for pkg in "${inPkg[@]}"; do
        if pacman -Si "${pkg}" &>/dev/null ; then
            arch+=("${pkg}")
        else 
            aur+=("${pkg}")
        fi
    done

    if [[ ${#arch[@]} -gt 0 ]]; then
        sudo pacman -S "${arch[@]}"
    fi

    if [[ ${#aur[@]} -gt 0 ]]; then
        ${aurhelper} -S "${aur[@]}"
    fi
}

# Helpful aliases
alias  c='clear' # clear terminal
alias  l='eza -lh  --icons=auto' # long list
alias  cls='clear' # clear terminal
alias ls='eza -1   --icons=auto' # short list
alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
alias ld='eza -lhD --icons=auto' # long list dirs
alias lt='eza --icons=auto --tree' # list folder as tree
alias la='eza -lha --icons=auto --group-directories-first' # list all



alias gls='eza -1   --icons=auto | grep ' # short list
alias gll='eza -lha --icons=auto --sort=name --group-directories-first | grep ' # long list all
alias gld='eza -lhD --icons=auto | grep ' # long list dirs
alias glt='eza --icons=auto --tree | grep ' # list folder as tree
alias gla='eza -lha --icons=auto --group-directories-first | grep ' # list all



alias un='$aurhelper -Rns' # uninstall package
alias up='$aurhelper -Syu' # update system/package/aur
alias pl='$aurhelper -Qs' # list installed package
alias pa='$aurhelper -Ss' # list availabe package
alias pc='$aurhelper -Sc' # remove unused cache
alias po='$aurhelper -Qtdq | $aurhelper -Rns -' # remove unused packages, also try > $aurhelper -Qqd | $aurhelper -Rsu --print -
alias vc='code' # gui code editor

# Handy change dir shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
alias DEV='cd ~/DEV'

# Always mkdir a path (this doesn't inhibit functionality to make a single dir)
alias mkdir='mkdir -p'

# python alias 
alias mkpyvenv="python3 -m venv .venv  "
alias runpyvenv="source ./.venv/bin/activate"




### ZNT's installer added snippet ###
fpath=( "$fpath[@]" "$HOME/.config/znt/zsh-navigation-tools" )
autoload n-aliases n-cd n-env n-functions n-history n-kill n-list n-list-draw n-list-input n-options n-panelize n-help
autoload znt-usetty-wrapper znt-history-widget znt-cd-widget znt-kill-widget
alias naliases=n-aliases ncd=n-cd nenv=n-env nfunctions=n-functions nhistory=n-history
alias nkill=n-kill noptions=n-options npanelize=n-panelize nhelp=n-help
zle -N znt-history-widget
bindkey '^R' znt-history-widget
setopt AUTO_PUSHD HIST_IGNORE_DUPS PUSHD_IGNORE_DUPS
zstyle ':completion::complete:n-kill::bits' matcher 'r:|=** l:|=*'
### END ###

 

eval "$(zoxide init zsh)"
eval "$(starship  init zsh)"
eval "$(pyenv init - zsh)"

# POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
 

# zoxide alias 
alias za='zoxide add'
alias zq='zoxide query'
alias zr='zoxide remove'


# from know thows are my aliases
alias zz='z $(zoxide query -i)'
alias zfzf='cd $(zoxide query -i) && fzf'
alias fgit='git branch | fzf'
alias fgit='git ' checkout="checkout \$(git branch | fzf) "


alias fp=readpath 

alias clone='cd ~/clone' 

export PATH=$PATH
export SCRIPTS="$HOME/.scripts" 
export PATH=$PATH:$SCRIPTS
export PATH=$PATH:"$(go env GOPATH)/bin"
export PATH=$PATH:"$HOME/.cargo/bin"
export PATH=$PATH:"$HOME/.local/lib"
export EDITOR=nvim

export XDG_DATA_DIRS="$HOME/.desktop:$XDG_DATA_DIRS"

desktop_update() {
    # Split XDG_DATA_DIRS by ":" into an array
    for dir in ${(s/:/)XDG_DATA_DIRS}; do
        update-desktop-database -q "$dir"
    done
}





# clear && fastfetch
cowsay $(ajoke)  


# Handy change dir function 
cd(){
    z "$1"
    za  . 
}

function mkdirg ()
{
        mkdir -p "$1"
        cd "$1"
}

function fzfon() {
        z "$1"
    fzf
}


function dfzf() {
    BRUH=${1:-$(".")}
    find $BRUH -type d | fzf --preview ' basename {} && [[ -d {} ]] && eza -l --color=always --icons {}'  
}

function fd() {
    BRUH=${1:-$(".")}
    cd $(dfzf $BRUH)
}


function JDM() {
    BRUH=${3:-$(pwd)}
    curl -X POST http://localhost:8080/download \
    -H "Content-Type: application/json" \
    -d '{"Name": "$1", "Path": "$3", "Url": "$2"}'
}

 
# Copy file(s) to clipboard and store in history
f-copy() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: f-copy <file1> [file2 ...]"
    return 1
  fi

  local uris=()
  for file in "$@"; do
    if [[ -e "$file" ]]; then
      uris+=("file://$(realpath "$file")")
    else
      echo "f-copy: '$file' does not exist"
      return 1
    fi
  done

  printf "%s\n" "${uris[@]}" | wl-copy --type text/uri-list
}

# Pick from clipboard history using fzf
f-paste() {
  cliphist list \
    | fzf --prompt="Clipboard ❯ " \
          --preview='echo {} | cliphist decode' \
          --preview-window=down:3:wrap \
    | cliphist decode \
    | wl-copy
}




export PATH=$HOME/.local/bin:$PATH
for dir in ~/.pyenv/versions/*/bin; do export PATH="$PATH:$dir" ; done




alias nv="nvim ."
alias clear='clear && cowsay $(ajoke) '

# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
function acp(){git add . ; git commit -m  $1 ;  git push }

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion




notify-send "Welcome back" "Have a nice day"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Added by LM Studio CLI tool (lms)
export PATH="$PATH:/home/mohammedaouamri/.lmstudio/bin"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/mohammedaouamri/HDD-2/.lmstudio/bin"
# End of LM Studio CLI section

