#!/usr/bin/env zsh

# fish shell-like abbreviation management for zsh.
# https://github.com/olets/zsh-abbr
# v1.1.0
# Copyright (c) 2019-2020 Henry Bley-Vroman


# References that helped in writing this
# https://www.zsh.org/mla/users/2012/msg00014.html
# Unsetting an associative array entry: http://www.zsh.org/mla/workers/2018/msg01078.html

# CONFIGURATION
# -------------

# File abbreviations are stored in
ABBR_UNIVERSALS_SOURCE="${ABBR_UNIVERSALS_SOURCE="${HOME}/.config/zsh-abbr/universal"}"
# Whether to add default bindings (expand on SPACE, expand and accept on ENTER,
# add CTRL for normal SPACE/ENTER; in incremental search mode expand on CTRL+SPACE)
ABBRS_DEFAULT_BINDINGS="${ABBRS_DEFAULT_BINDINGS=true}"

# INITIALIZE
# ----------

typeset -gA ABBRS_UNIVERSAL
typeset -gA ABBRS_GLOBAL
ABBRS_UNIVERSAL=()
ABBRS_GLOBAL=()

# Load saved universal abbreviations
if [ -f "$ABBR_UNIVERSALS_SOURCE" ]; then
  while read -r k v; do
    ABBRS_UNIVERSAL[$k]="$v"
  done < "$ABBR_UNIVERSALS_SOURCE"
else
  mkdir -p $(dirname "$ABBR_UNIVERSALS_SOURCE")
  touch "$ABBR_UNIVERSALS_SOURCE"
fi

# Scratch file
ABBRS_UNIVERSAL_SCRATCH_FILE="${TMPDIR}/abbr_universals"

rm "$ABBRS_UNIVERSAL_SCRATCH_FILE" 2> /dev/null
mktemp "$ABBRS_UNIVERSAL_SCRATCH_FILE" 1> /dev/null
typeset -p ABBRS_UNIVERSAL > "$ABBRS_UNIVERSAL_SCRATCH_FILE"

# Bind
if [ "$ABBRS_DEFAULT_BINDINGS" = true ]; then
  # spacebar expands abbreviations
  zle -N _zsh_abbr_expand_space
  bindkey " " _zsh_abbr_expand_space

  # control-spacebar is a normal space
  bindkey "^ " magic-space

  # when running an incremental search,
  # spacebar behaves normally and control-space expands abbreviations
  bindkey -M isearch "^ " _zsh_abbr_expand_space
  bindkey -M isearch " " magic-space

  # enter key expands and accepts abbreviations
  zle -N _zsh_abbr_expand_accept
  bindkey "^M" _zsh_abbr_expand_accept
fi


# FUNCTIONS
# ---------
function _zsh_abbr_expand_accept() {
  zle _zsh_abbr_expand_widget
  zle autosuggest-clear # if using zsh-autosuggestions, clear any suggestion
  zle accept-line
}

function _zsh_abbr_expand_space() {
  zle _zsh_abbr_expand_widget
  LBUFFER="$LBUFFER "
}


# WIDGETS
# -------

function _zsh_abbr_expand_widget() {
  abbr_expand "$@"
}

zle -N _zsh_abbr_expand_widget


# FUNCTIONS
# ---------

function abbr_expand() {
  {
    function abbr_expand_error() {
      printf "abbr%s\\nFor help run abbr -h\\n" "$@"
      abbr_should_exit=true
    }

    function abbr_expand_get_expansion() {
      printf "%s\\n" "${ABBRS_UNIVERSAL[$1]}"
    }

    local abbreviation=$1
    local expansion

    if ! zle; then
      if [[ "$#" -ne 1 ]]; then
        printf "abbr_expand requires exactly one argument\\n"
        return
      fi

      abbreviation=$1
    else
      abbreviation="${LBUFFER/*[ ,;|&\n\t]/}"
    fi

    expansion="${ABBRS_GLOBAL[$abbreviation]}"

    if [[ ! -n $expansion ]]; then
      source "$ABBRS_UNIVERSAL_SCRATCH_FILE"
      expansion="${ABBRS_UNIVERSAL[$abbreviation]}"
    fi

    if ! zle; then
      printf "%s\\n" "$expansion"
    else
      if [ "$expansion" ]; then
        local rest="${LBUFFER%%$abbreviation}"
        LBUFFER="$rest$expansion"
        _zsh_highlight # if using zsh-syntax-highlighting, update the highlighting
      fi
    fi
  } always {
    unfunction -m "abbr_expand_error"
    unfunction -m "abbr_expand_get_expansion"
  }
}

function abbr() {
  {
    local abbr_action_set=false
    local abbr_number_opts=0
    local abbr_opt_add=false
    local abbr_opt_create_aliases=false
    local abbr_opt_erase=false
    local abbr_opt_git_populate=false
    local abbr_opt_global=false
    local abbr_opt_list=false
    local abbr_opt_rename=false
    local abbr_opt_show=false
    local abbr_opt_populate=false
    local abbr_opt_universal=false
    local abbr_scope_set=false
    local abbr_should_exit=false
    local abbr_usage="
       \e[1mabbr\e[0m: fish shell-like abbreviations for zsh

   \e[1mSynopsis\e[0m
       \e[1mabbr\e[0m --add|-a [SCOPE] WORD EXPANSION
       \e[1mabbr\e[0m --create-aliases|-c [SCOPE] [DESTINATION_FILE]
       \e[1mabbr\e[0m --erase|-e [SCOPE] WORD
       \e[1mabbr\e[0m --rename|-r [SCOPE] OLD_WORD NEW_WORD
       \e[1mabbr\e[0m --show|-s
       \e[1mabbr\e[0m --list|-l
       \e[1mabbr\e[0m --populate|-p [SCOPE]
       \e[1mabbr\e[0m --git-populate|-i [SCOPE]
       \e[1mabbr\e[0m --help|-h

   \e[1mDescription\e[0m
       \e[1mabbr\e[0m manages abbreviations - user-defined words that are
       replaced with longer phrases after they are entered.

       For example, a frequently-run command like git checkout can be
       abbreviated to gco. After entering gco and pressing [\e[1mSpace\e[0m],
       the full text git checkout will appear in the command line.

       To prevent expansion, press [\e[1mCTRL-SPACE\e[0m] in place of [\e[1mSPACE\e[0m].

   \e[1mOptions\e[0m
       The following options are available:

       o --add WORD EXPANSION or -a WORD EXPANSION Adds a new abbreviation,
         causing WORD to be expanded to PHRASE.

       o --create-aliases [-g] [DESTINATION_FILE] or -c [-g] [DESTINATION_FILE]
         Outputs a list of alias command for universal abbreviations, suitable
         for pasting or piping to whereever you keep aliases. Add -g to output
         alias commands for global abbreviations. If a DESTINATION_FILE is
         provided, the commands will be appended to it.

       o --erase WORD or -e WORD Erases the abbreviation WORD.

       o --git-populate or -i Adds abbreviations for all git aliases. WORDs are
         prefixed with g, EXPANSIONs are prefixed with git[Space].

       o --list -l Lists all abbreviated words.

       o --populate or -p Adds abbreviations for all aliases.

       o --rename OLD_WORD NEW_WORD -r OLD_WORD NEW_WORD Renames an
         abbreviation, from OLD_WORD to NEW_WORD.

       o --show or -s Show all abbreviations in a manner suitable for export
         and import.

       In addition, when adding abbreviations use

       o --global or -g to create a global abbreviation, available only in the
         current session.

       o --universal or -U to create a universal abbreviation (default),
         immediately available to all sessions.

       See the 'Internals' section for more on them.

   \e[1mExamples\e[0m
       \e[1mabbr\e[0m -a -g gco git checkout
       \e[1mabbr\e[0m --add --global gco git checkout

         Add a new abbreviation where gco will be replaced with git checkout
         global to the current shell. This abbreviation will not be
         automatically visible to other shells unless the same command is run
         in those shells.

       \e[1mabbr\e[0m -a l less
       \e[1mabbr\e[0m --add l less

         Add a new abbreviation where l will be replaced with less universal so
         all shells. Note that you omit the -U since it is the default.

       \e[1mabbr\e[0m -c -g
       \e[1mabbr\e[0m --create-aliases -global

         Output alias declaration commands for each *global* abbreviation.
         Output lines look like alias -g <WORD>='<EXPANSION>'

       \e[1mabbr\e[0m -c
       \e[1mabbr\e[0m --create-aliases

         Output alias declaration commands for each *universal* abbreviation.
         Output lines look like alias -g <WORD>='<EXPANSION>'

       \e[1mabbr\e[0m -c ~/aliases
       \e[1mabbr\e[0m --create-aliases ~/aliases

         Add alias definitions to ~/aliases

       \e[1mabbr\e[0m -e -g gco
       \e[1mabbr\e[0m --erase --global gco

         Erase the global gco abbreviation.

       \e[1mabbr\e[0m -r -g gco gch
       \e[1mabbr\e[0m --rename --global gco gch

         Rename the existing global abbreviation from gco to gch.

       \e[1mabbr\e[0m -r l le
       \e[1mabbr\e[0m --rename l le

        Rename the existing universal abbreviation from l to le. Note that you
        can omit the -U since it is the default.

   \e[1mInternals\e[0m
       The WORD cannot contain a space but all other characters are legal.

       Defining an abbreviation with global scope is slightly faster than
       universal scope (which is the default).

       You can create abbreviations interactively and they will be visible to
       other zsh sessions if you use the -U flag or don't explicitly specify
       the scope. If you want it to be visible only to the current shell
       use the -g flag.

       The options -a -c -e -r -s -l -p and -i are mutually exclusive,
       as are the scope options -g and -U.

       The function abbr_expand is available to return an abbreviation's
       expansion. The result is the global expansion if one exists, otherwise
       the universal expansion if one exists.

       Version 1.1.0 January 26 2019"

    function abbr_util_add() {
      key="$1"
      shift
      # $* is value

      if $abbr_opt_global; then
        if [ ${ABBRS_GLOBAL[(I)$key]} ]; then
          abbr_error " -a: A global abbreviation $key already exists"
          return
        fi

        ABBRS_GLOBAL[$key]="$*"
      else
        if [ ${ABBRS_UNIVERSAL[(I)$key]} ]; then
          abbr_error " -a: A universal abbreviation $key already exists"
          return
        fi

        source "$ABBRS_UNIVERSAL_SCRATCH_FILE"
        ABBRS_UNIVERSAL[$key]="$*"
        abbr_sync_universal
      fi
    }

    function abbr_add() {
      if [[ $# -lt 2 ]]; then
        abbr_error " -a: Requires at least two arguments"
        return
      fi

      abbr_util_add $*
    }

    function abbr_bad_options() {
      abbr_error ": Illegal combination of options"
    }

    function abbr_create_aliases() {
      local source
      local alias_definition

      if [ $# -gt 1 ]; then
        abbr_error " -c: Unexpected argument"
        return
      fi

      if $abbr_opt_global; then
        source=ABBRS_GLOBAL
      else
        source=ABBRS_UNIVERSAL
      fi

      for k v in ${(kv)${(P)source}}; do
        alias_definition="alias -g $k='$v'"

        if [ $# -gt 0 ]; then
          echo "$alias_definition" >> "$1"
        else
          print "$alias_definition"
        fi
      done
    }

    function abbr_erase() {
      if [ $# -gt 1 ]; then
        abbr_error " -e: Expected one argument"
        return
      elif [ $# -lt 1 ]; then
        abbr_error " -e: Erase needs a variable name"
        return
      fi

      if $abbr_opt_global; then
        if (( ${+ABBRS_GLOBAL[$1]} )); then
          unset "ABBRS_GLOBAL[${(b)1}]"
        else
          abbr_error " -e: No global abbreviation named $1"
          return
        fi
      else
        source "$ABBRS_UNIVERSAL_SCRATCH_FILE"

        if (( ${+ABBRS_UNIVERSAL[$1]} )); then
          unset "ABBRS_UNIVERSAL[${(b)1}]"
          abbr_sync_universal
        else
          abbr_error " -e: No universal abbreviation named $1"
          return
        fi
      fi
    }

    function abbr_error() {
      printf "abbr%s\\nFor help run abbr --help\\n" "$@"
      abbr_should_exit=true
    }

    function abbr_git_populate() {
      if [ $# -gt 0 ]; then
        abbr_error " -p: Unexpected argument"
        return
      fi

      local git_aliases abbr_git_aliases
      git_aliases=("${(@f)$(git config --get-regexp '^alias\.')}")
      typeset -A abbr_git_aliases

      for i in $git_aliases; do
        key="${$(echo $i | awk '{print $1;}')##alias.}"
        value="${$(echo $i)##alias.$key }"

        abbr_util_add "g$key" "git ${value# }"
      done
    }

    function abbr_list() {
      if [ $# -gt 0 ]; then
        abbr_error " -l: Unexpected argument"
        return
      fi

      source "$ABBRS_UNIVERSAL_SCRATCH_FILE"

      print -l ${(k)ABBRS_UNIVERSAL}
      print -l ${(k)ABBRS_GLOBAL}
    }

    function abbr_populate() {
      if [ $# -gt 0 ]; then
        abbr_error " -p: Unexpected argument"
        return
      fi

      for k v in ${(kv)aliases}; do
        abbr_util_add "$k" "${v# }"
      done
    }

    function abbr_sync_universal() {
      local abbr_universals_updated="$ABBRS_UNIVERSAL_SCRATCH_FILE"_updated

      typeset -p ABBRS_UNIVERSAL > "$ABBRS_UNIVERSAL_SCRATCH_FILE"

      rm "$abbr_universals_updated" 2> /dev/null
      mktemp "$abbr_universals_updated" 1> /dev/null

      for k v in ${(kv)ABBRS_UNIVERSAL}; do
        echo "$k $v" >> "$abbr_universals_updated"
      done

      mv "$abbr_universals_updated" "$ABBR_UNIVERSALS_SOURCE"
    }

    function abbr_rename() {
      if [ $# -ne 2 ]; then
        abbr_error " -r: Requires exactly two arguments"
        return
      fi

      if $abbr_opt_global; then
        if (( ${+ABBRS_GLOBAL[$1]} )); then
          ABBRS_GLOBAL[$2]="${ABBRS_GLOBAL[$1]}"
          unset "ABBRS_GLOBAL[${(b)1}]"
        else
          abbr_error " -r: No global abbreviation named $1"
        fi
      else
        source "$ABBRS_UNIVERSAL_SCRATCH_FILE"

        if (( ${+ABBRS_UNIVERSAL[$1]} )); then
          ABBRS_UNIVERSAL[$2]="${ABBRS_UNIVERSAL[$1]}"
          unset "ABBRS_UNIVERSAL[${(b)1}]"
          abbr_sync_universal
        else
          abbr_error " -r: No universal abbreviation named $1"
        fi
      fi
    }

    function abbr_show() {
      if [ $# -gt 0 ]; then
        abbr_error " -s: Unexpected argument"
        return
      fi

      source "$ABBRS_UNIVERSAL_SCRATCH_FILE"

      for key value in ${(kv)ABBRS_UNIVERSAL}; do
        printf "abbr -a -U -- %s %s\\n" "$key" "$value"
      done

      for key value in ${(kv)ABBRS_GLOBAL}; do
        printf "abbr -a -g -- %s %s\\n" "$key" "$value"
      done
    }

    function abbr_usage() {
      print "$abbr_usage\\n"
    }

    local abbr_number_opts=0
    for opt in "$@"; do
      if $abbr_should_exit; then
        abbr_should_exit=false
        return
      fi

      case "$opt" in
        "-h"|"--help")
          abbr_usage
          abbr_should_exit=true
          ;;
        "-a"|"--add")
          [ "$abbr_action_set" = true ] && abbr_bad_options
          abbr_action_set=true
          abbr_opt_add=true
          ((abbr_number_opts++))
          ;;
        "-e"|"--erase")
          [ "$abbr_action_set" = true ] && abbr_bad_options
          abbr_action_set=true
          abbr_opt_erase=true
          ((abbr_number_opts++))
          ;;
        "-r"|"--rename")
          [ "$abbr_action_set" = true ] && abbr_bad_options
          abbr_action_set=true
          abbr_opt_rename=true
          ((abbr_number_opts++))
          ;;
        "-s"|"--show")
          [ "$abbr_action_set" = true ] && abbr_bad_options
          abbr_action_set=true
          abbr_opt_show=true
          ((abbr_number_opts++))
          ;;
        "-l"|"--list")
          [ "$abbr_action_set" = true ] && abbr_bad_options
          abbr_action_set=true
          abbr_opt_list=true
          ((abbr_number_opts++))
          ;;
        "-p"|"--populate")
          [ "$abbr_action_set" = true ] && abbr_bad_options
          abbr_action_set=true
          abbr_opt_populate=true
          ((abbr_number_opts++))
          ;;
        "-i"|"--git-populate")
          [ "$abbr_action_set" = true ] && abbr_bad_options
          abbr_action_set=true
          abbr_opt_git_populate=true
          ((abbr_number_opts++))
          ;;
        "-c"|"--create-aliases")
          [ "$abbr_action_set" = true ] && abbr_bad_options
          abbr_action_set=true
          abbr_opt_create_aliases=true
          ((abbr_number_opts++))
          ;;
        "-g"|"--global")
          [ "$abbr_scope_set" = true ] && abbr_bad_options
          abbr_opt_global=true
          ((abbr_number_opts++))
          ;;
        "-U"|"--universal")
          [ "$abbr_scope_set" = true ] && abbr_bad_options
          ((abbr_number_opts++))
          ;;
        "-"*)
          abbr_error ": Unknown option '$opt'"
          ;;
      esac
    done

    if $abbr_should_exit; then
      abbr_should_exit=false
      return
    fi

    shift $abbr_number_opts

    if ! $abbr_opt_global; then
      abbr_opt_universal=true
    fi

    if $abbr_opt_rename; then
      abbr_rename "$@"
    elif $abbr_opt_list; then
      abbr_list "$@"
    elif $abbr_opt_erase; then
      abbr_erase "$@"
    elif $abbr_opt_populate; then
      abbr_populate "$@"
    elif $abbr_opt_git_populate; then
      abbr_git_populate "$@"
    elif $abbr_opt_create_aliases; then
      abbr_create_aliases "$@"
    elif $abbr_opt_add; then
       abbr_add "$@"
    elif ! $abbr_opt_show && [ $# -gt 0 ]; then
       abbr_add "$@"
    else
      abbr_show "$@"
    fi
  } always {
    unfunction -m "abbr_util_add"
    unfunction -m "abbr_add"
    unfunction -m "abbr_create_aliases"
    unfunction -m "abbr_erase"
    unfunction -m "abbr_error"
    unfunction -m "abbr_git_populate"
    unfunction -m "abbr_check_options"
    unfunction -m "abbr_list"
    unfunction -m "abbr_rename"
    unfunction -m "abbr_show"
    unfunction -m "abbr_sync_universal"
    unfunction -m "abbr_usage"
  }
}