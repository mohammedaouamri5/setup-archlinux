#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Added by LM Studio CLI tool (lms)
export PATH="$PATH:/home/mohammedaouamri/.lmstudio/bin"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/mohammedaouamri/HDD-2/.lmstudio/bin"
# End of LM Studio CLI section

