#!/bin/zsh



### LOGGING UTILITY ###
source "$HOME/.zsh-custom/inject-logger.zsh"
log_source "rc-updater.zsh"
log_level '3'



###############################################
### auto reload modified shell and rc files ###
###############################################


# tracks the last reload of targeted files
#   targets should be defined in glob-form or absolute path
declare -Ag RC_MOD_TIMES
export RC_MOD_TIMES
declare -Ag RC_AUTO_ADD_TIMES
export RC_AUTO_ADD_TIMES
declare -Ag RC_AUTO_ADD_ARGS
export RC_AUTO_ADD_ARGS


# get the "last modified" time of a file
_rc_updater_get_mod_time () {
  [[ $# -gt 0 ]] && debug "received '$@'" || return 1

  if [ -e "$1" ]
  then
    time=$( gstat -c "%Y" "$(realpath $1)" )
    # (($?)) && return 1
  else
    warn "cannot get last-modified time: no such path '$1'"
  fi

  echo $time

  return 0
}


# reload target files via `source` command
#   targets should be defined in glob-form
rc-reload () {
  [[ $# -gt 0 ]] && debug "received '$@'"

  if [[ $# -eq 0 ]];
  then
    for filepath in ${RC_AUTO_ADD_TIMES[@]}
    do
      local mod_time=$(_rc_updater_get_mod_time "$filepath")
      [ -z mod_time ] && continue  # skip file if mod_time fails

      debug "found tracker '$filepath' in RC_AUTO_ADDS"
      rc-track "$RC_AUTO_ADD_ARGS[$filepath]" "$filepath"
    done

    for file in ${(k)RC_MOD_TIMES[@]}
    do
      debug "checking file '$file'..."

      local mod_time=$(_rc_updater_get_mod_time "$file")
      [ -z mod_time ] && continue  # skip file if mod_time fails

      debug "tracked: $RC_MOD_TIMES[$file], found: $mod_time"
      if [[ $RC_MOD_TIMES[$file] -lt $mod_time ]];
      then
        # only log initial file load when state-logging is enabled
        if [[ $RC_MOD_TIMES[$file] -eq 0 ]] && state "[loading $file]" || echo "[loading $file]"

        source "$file";
        RC_MOD_TIMES[$file]=$mod_time
        
        debug "RC_MOD_TIMES[$file] reloaded ($mod_time)"
      fi
    done
  else
    for rc in $@
    do
      debug "checking file '$file'..."

      local mod_time=$(_rc_updater_get_mod_time "$file")
      [ -z mod_time ] && continue  # skip file if mod_time fails

      echo "[loading $file]"

      source "$file";
      RC_MOD_TIMES[$file]=$mod_time
      
      debug "RC_MOD_TIMES[$file] reloaded ($mod_time)"
    done
  fi

  return 0
}

# automatically check one or more target path-globs for new files to track
rc-auto-add () {
  [[ $# -gt 0 ]] && debug "received '$@'" || return 1

  while [[ $# -gt 0 ]]
  do
    local args=()

      debug "arg '$1'"
    case "$1" in
      --set|-s)
        args+=($1 $2)
        shift 2
          debug "auto-add args: $args[@]"
        ;;
      --immediate|-i)
        args+=($1)
        shift
          debug "auto-add args: $args[@]"
        ;;
      --no-load|-n)
        args+=($1)
        shift
          debug "auto-add args: $args[@]"
        ;;
      --auto-add|-a)
        warn "invalid arg '$1' in rc-auto-add"
        shift
        ;;
      *)
        local filepath="$1"
        shift

        # the mod-time here will reflect the parent directory of the glob path
        local time="$(_rc_updater_get_mod_time `dirname "$filepath"`)"
          debug "auto-add path '$filepath' init time is '$time'"

        RC_AUTO_ADD_TIMES["$filepath"]="$time"
        RC_AUTO_ADD_ARGS["$filepath"]="${args[@]}"
        state "auto-tracking path '$filepath' with initial time '$time'"
        ;;
    esac
  done

  return 0
}

# track one or more targets indicated by the passed file-glob(s)
rc-track () {
  [[ $# -gt 0 ]] && debug "received '$@'" || return 1

  local time
  local filepath

  while [[ $# -gt 0 ]]
  do
      debug "arg '$1'"
    case "$1" in
      --set|-s)
        time="$2"
        shift 2
        ;;
      --immediate|-i)
        time='0'
        shift
        ;;
      --no-load|-n)
        time=''
        shift
        ;;
      --auto-add|-a)
        shift
        rc-auto-add $@
        break
        ;;
      *)
        filepath="$1"
        shift
          debug "filpath is '$filepath' with tracked timestamp '$RC_MOD_TIMES[$filepath]'"

        [ -z "$time" ] && time="$(_rc_updater_get_mod_time "$filepath")"
          debug "file init time is '$time'"

        if [ -n "$RC_MOD_TIMES[$filepath]" ]
        then
          state "already tracking file '$filepath'"
        else
          RC_MOD_TIMES[$filepath]="$time"
          state "tracking file '$filepath' with initial time '$time'"
        fi
        ;;
    esac
  done

  return 0
}


rc-untrack () {
  [[ $# -gt 0 ]] && debug "received '$@'" || return 1

  for filepath in $@
  do
    [[ -n RC_MOD_TIMES[$filepath] ]] && state "stopped tracking file '$filepath'"
    unset RC_MOD_TIMES[$filepath]

    [[ -n RC_AUTO_ADD_TIMES[$filepath] ]] && state "stopped tracking auto-add path '$filepath'"
    unset RC_AUTO_ADD_TIMES[$filepath]
    unset RC_AUTO_ADD_ARGS[$filepath]
  done

  return 0
}


rc-list () {
  if [[ $# -gt 0 ]]
  then
    local tracked=()
    
    for key in ${(k)hash[@]}
    do
      [[ "$key" =~ "$@" ]] && tracked+="$key"
    done

    if [[ $#tracked -gt 0 ]]
    then
      state 'the following files are being tracked:'
      echo "${(j:\n:)tracked[@]}"

      return 0
    else
      warn "not tracking any files like '$@'"
      return 1
    fi
  else
    state 'the following files are being tracked:'
    echo "${(kj:\n:)RC_MOD_TIMES[@]}"

    return 0
  fi
}


_rc_updater_help () {
  [[ $# -gt 0 ]] && debug "received '$@'"

  if [[ $# -gt 0 ]]
  then
    case "$1" in
      forget)
        cat <<-HELP
          - todo -
				HELP
        ;;
      init)
        cat <<-HELP
          - todo -
				HELP
        ;;
      help)
        cat <<-HELP
          - todo -
				HELP
        ;;
      list)
        cat <<-HELP
          - todo -
				HELP
        ;;
      reload)
        cat <<-HELP
          - todo -
				HELP
        ;;
      reset)
        cat <<-HELP
          - todo -
          alias of 'init'
				HELP
        ;;
      track)
        cat <<-HELP
          - todo -
				HELP
        ;;
      untrack)
        cat <<-HELP
          - todo -
				HELP
        ;;
      *)
        _rc_updater_short_help
        ;;
    esac
  fi

  return 0
}


_rc_updater_short_help () {
  cat <<-HELP
    rc-updater help blurb
          - todo - 
	HELP

  return 0
}


rc-updater () {
  [[ $# -gt 0 ]] && debug "received '$@'"

  while [[ $# -gt 0 ]]
  do
    debug "arg '$1'"

    command="$1"
    shift
    case "$command" in
      init|reset)
        RC_MOD_TIMES=() ;;
      --help|help)
        _rc_updater_help $@ ;;
      list)
        rc-list $@;;
      reload|update)
        rc-reload $@ ;;
      track)
        rc-track $@ ;;
      untrack|forget)
        rc-untrack $@ ;;
      *)
        break ;;
    esac
  done

  _rc_updater_short_help
  return 1
}


