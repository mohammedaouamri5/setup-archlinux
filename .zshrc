# Path to your oh-my-zsh installation.
ZSH=/usr/share/oh-my-zsh/

# Path to powerlevel10k theme

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
    # timer
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
eval "$(starship init zsh)"

POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
 

# zoxide alias 
alias za='zoxide add'
alias zq='zoxide query'
alias zr='zoxide remove'


# from know thows are my aliases
alias zz='z $(zoxide query -i)'
alias zfzf='cd $(zoxide query -i) && fzf'
alias fgit='git branch | fzf'
alias fgit='git ' checkout="checkout \$(git branch | fzf) "


alias clone='cd ~/clone' 

export PATH=$PATH
export SCRIPTS="$HOME/.scripts" 
export PATH=$PATH:$SCRIPTS
export PATH=$PATH:"$(go env GOPATH)/bin"
export PATH=$PATH:"$HOME/.cargo/bin"
export EDITOR=nvim






clear && fastfetch

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

if [ $(date +"%Y") -eq 2025 ]; then
    cowsay "Go get Ghostty terminal"
fi

 
export PATH=$HOME/.local/bin:$PATH
for dir in ~/.pyenv/versions/*/bin; do export PATH="$PATH:$dir" ; done


# >>> conda initialize >>>
# # !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/home/mohammedaouamri/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/home/mohammedaouamri/anaconda3/etc/profile.d/conda.sh" ]; then
#         . "/home/mohammedaouamri/anaconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/home/mohammedaouamri/anaconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# # <<< conda initialize <<<
# conda deactivate              

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

cowsay $(ajoke)  


alias nv='nvim'
alias clear='clear && cowsay $(ajoke) '
