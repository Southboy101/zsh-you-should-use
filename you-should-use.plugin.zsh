#!/bin/zsh

export YSU_VERSION='0.7.2'

if ! type "tput" > /dev/null; then
    printf "WARNING: tput command not found on your PATH.\n"
    printf "zsh-you-should-use will fallback to uncoloured messages\n"
else
    NONE="$(tput sgr0)"
    BOLD="$(tput bold)"
    RED="$(tput setaf 1)"
    YELLOW="$(tput setaf 3)"
    PURPLE="$(tput setaf 5)"
fi

function ysu_message() {
  DEFAULT_MESSAGE_FORMAT="${BOLD}${YELLOW}\
Found existing %alias_type for ${PURPLE}\"%command\"${YELLOW}. \
You should use: ${PURPLE}\"%alias\"${NONE}"

  local MESSAGE="${YSU_MESSAGE_FORMAT:-"$DEFAULT_MESSAGE_FORMAT"}"
  MESSAGE="${MESSAGE//\%alias_type/$1}"
  MESSAGE="${MESSAGE//\%command/$2}"
  MESSAGE="${MESSAGE//\%alias/$3}"

  (>&2 printf "$MESSAGE\n")
}


# Prevent command from running if hardcore mode enabled
function _check_ysu_hardcore() {
  if [[ "$YSU_HARDCORE" = 1 ]]; then
      (>&2 printf "${BOLD}${RED}You Should Use hardcore mode enabled. Use your aliases!${NONE}\n")
      kill -s INT $$
  fi
}


function _check_git_aliases() {
  if [[ "$1" = "git "* ]]; then
      local found=false
      local tokens
      local k
      local v
      git config --get-regexp "^alias\..+$" | sort | while read entry; do
        tokens=("${(@s/ /)entry}")
        k="${tokens[1]#alias.}"
        v="${tokens[2]}"

        if [[ "$2" = "git $v" || "$2" = "git $v "* ]]; then
          ysu_message "git alias" "$v" "git $k"
          found=true
        fi
      done

      if $found; then
       _check_ysu_hardcore
      fi
  fi
}


function _check_global_aliases() {
  local found=false
  local tokens
  local k
  local v
  alias -g | sort | while read entry; do
    tokens=("${(@s/=/)entry}")
    k="${tokens[1]}"
    # Need to remove leading and trailing ' if they exist
    v="${(Q)tokens[2]}"

    if [[ "$1" = *"$v"* ]]; then
      ysu_message "global alias" "$v" "$k"
      found=true
    fi
  done

  if $found; then
   _check_ysu_hardcore
  fi
}


function _check_aliases() {
  local found_aliases
  found_aliases=()
  local best_match=""
  local best_match_value=""
  local v

  # Find alias matches
  for k in "${(@k)aliases}"; do
    v="${aliases[$k]}"

    if [[ "$1" = "$v" || "$1" = "$v "* ]]; then

      # if the alias longer or the same length as its command
      # we assume that it is there to cater for typos.
      # If not, then the alias would not save any time
      # for the user and so doesn't hold much value anyway
      if [[ "${#v}" -gt "${#k}" ]]; then

        found_aliases+="$k"

        # Match aliases to longest portion of command
        if [[ "${#v}" -gt "${#best_match_value}" ]]; then
          best_match="$k"
          best_match_value="$v"
        # on equal length, choose the shortest alias
        elif [[ "${#v}" -eq "${#best_match}" && ${#k} -lt "${#best_match}" ]]; then
          best_match="$k"
          best_match_value="$v"
        fi
      fi
    fi
  done

  # Print result matches based on current mode
  if [[ "$YSU_MODE" = "ALL" ]]; then
    for k in ${(@ok)found_aliases}; do
      v="${aliases[$k]}"
      ysu_message "alias" "$v" "$k"
    done

  elif [[ (-z "$YSU_MODE" || "$YSU_MODE" = "BESTMATCH") && -n "$best_match" ]]; then
    v="${aliases[$best_match]}"
    ysu_message "alias" "$v" "$best_match"
  fi

  if [[ -n "$found_aliases" ]]; then
    _check_ysu_hardcore
  fi
}

function disable_you_should_use() {
    add-zsh-hook -D preexec _check_aliases
    add-zsh-hook -D preexec _check_global_aliases
    add-zsh-hook -D preexec _check_git_aliases
}

function enable_you_should_use() {
    disable_you_should_use   # Delete any possible pre-existing hooks
    add-zsh-hook preexec _check_aliases
    add-zsh-hook preexec _check_global_aliases
    add-zsh-hook preexec _check_git_aliases
}

autoload -Uz add-zsh-hook
enable_you_should_use
