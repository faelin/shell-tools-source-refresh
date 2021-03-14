#!/bin/zsh


### LOGGING UTILITY ###
source "$HOME/.zsh-custom/inject-logger.zsh"
log_source "live_reload.zsh"
# log_level 'debug'



###############################################
### auto reload modified shell and rc files ###
###############################################


# tracks the last reload of targeted files
#   targets should be defined in glob-form or absolute path
declare -Ag SOURCE_MOD_TIMES
export SOURCE_MOD_TIMES
declare -Ag SOURCE_AUTO_TRACK_TIMES
export SOURCE_AUTO_TRACK_TIMES
declare -Ag SOURCE_AUTO_TRACK_ARGS
export SOURCE_AUTO_TRACK_ARGS


# get the "last modified" time of a file
_live_reload_get_mod_time () {
  # [[ $# -gt 0 ]] && debug "=> called with '$@'"
  [[ $# -eq 0 ]] && return 1

  target=$(eval "echo \"$1\"")

  if [ -e "$target" ]
  then
    time=$(gstat -c "%Y" "$(realpath "$target")")
    # (($?)) && return 1
  else
    warn "cannot get last-modified time: no such path '$target'"
  fi

  echo $time

  return 0
}


# reload target files via 'source' command
#   targets should be defined in glob-form
source-reload () {
  [[ $# -gt 0 ]] && debug "=> called with '$@'" || debug "=> called with no args"

  if [[ $# -eq 0 ]];
  then
    for glob in ${(k)SOURCE_AUTO_TRACK_TIMES[@]}
    do
      # the mod-time here will reflect the parent directory of the glob path
      local mod_time=$( _live_reload_get_mod_time $(dirname "$glob") )
      [[ -z mod_time ]] && continue  # skip file if mod_time fails
      
      if [[ $SOURCE_AUTO_TRACK_TIMES[$glob] -lt $mod_time ]];
      then
          debug "exploring auto-track glob '$glob'"
          # debug "found configuration '${SOURCE_AUTO_TRACK_ARGS[$glob]}'"

        SOURCE_AUTO_TRACK_TIMES[$glob]="$mod_time"
        for file in $(eval "echo $glob")
        do
            debug "tracking-glob found '$file'"
          source-track $SOURCE_AUTO_TRACK_ARGS[$glob] "$file"
        done
      else
        debug "auto-track skipped glob '$glob' (up-to-date)"
      fi
    done
  fi

  local sources=( $@ )
  [[ $#sources -eq 0 ]] && sources=( ${(k)SOURCE_MOD_TIMES[@]} )
  for file in $sources
  do
    debug "checking file '$file' timestamps..."

    local mod_time=$(_live_reload_get_mod_time "$file")
    [[ -z mod_time ]] && continue  # skip file if mod_time fails

    debug "last: $SOURCE_MOD_TIMES[$file], curr: $mod_time"
    if [[ $SOURCE_MOD_TIMES[$file] -lt $mod_time ]];
    then
      # only log initial file load when state-logging is enabled
      [[ $SOURCE_MOD_TIMES[$file] -gt 0 ]] && echo "[reloading $file]" || state "[loading $file]"

      source "$file";
      SOURCE_MOD_TIMES[$file]=$mod_time
    fi
  done

  return 0
}

# automatically check one or more target path-globs for new files to track
source-auto-track () {
  [[ $# -gt 0 ]] && debug "=> called with '$@'"
  [[ $# -eq 0 ]] && return 1

  auto_track_args=()
  while [[ $# -gt 0 ]]
  do
    case "$1" in
      --set|-s)
        auto_track_args+=($1 $2)
        shift 2
        ;;
      --immediate|-i)
        auto_track_args+=($1)
        shift
        ;;
      --no-load|-n)
        auto_track_args+=($1)
        shift
        ;;
      --auto-track|-a)
        warn "invalid arg '$1' in source-auto-track"
        shift
        ;;
      *)
        local filepath="$1"
        shift

        SOURCE_AUTO_TRACK_TIMES[$filepath]='0'
        SOURCE_AUTO_TRACK_ARGS[$filepath]="${auto_track_args[@]}"
        state "following glob '$filepath' with configuration '${auto_track_args[@]}'"
        ;;
    esac
  done

  return 0
}

# track one or more targets indicated by the passed file-glob(s)
source-track () {
  [[ $# -gt 0 ]] && debug "=> called with '$@'"
  [[ $# -eq 0 ]] && return 1

  local time
  local filepath

  while [[ $# -gt 0 ]]
  do
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
      --auto-track|-a)
        shift
        source-auto-track $@
        return 0
        ;;
      --*)
        warn "live-reload: unknown argument '$1'" || echo "live-reload: unknown argument '$1'"
        return 1
        ;;
      *)
        filepath="$1"
        shift

        if [ -z "$SOURCE_MOD_TIMES[$filepath]" ]
        then
          [[ -z "$time" ]] && time="$(_live_reload_get_mod_time "$filepath")"
            debug "file init time is '$time'"

          SOURCE_MOD_TIMES[$filepath]="$time"
          state "tracking file '$filepath' with initial time '$time'"
        else
          state "already tracking file '$filepath'"
        fi
        ;;
    esac
  done

  return 0
}


source-untrack () {
  [[ $# -gt 0 ]] && debug "=> called with '$@'"
  [[ $# -eq 0 ]] && return 1

  for filepath in $@
  do
    [[ -n SOURCE_MOD_TIMES[$filepath] ]] && state "stopped tracking file '$filepath'"
    unset SOURCE_MOD_TIMES[$filepath]

    [[ -n SOURCE_AUTO_TRACK_TIMES[$filepath] ]] && state "stopped tracking auto-track path '$filepath'"
    unset SOURCE_AUTO_TRACK_TIMES[$filepath]
    unset SOURCE_AUTO_TRACK_ARGS[$filepath]
  done

  return 0
}


source-list () {
  [[ $# -gt 0 ]] && debug "=> called with '$@'" || debug "=> called with no args"

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
    echo "${(kj:\n:)SOURCE_MOD_TIMES[@]}"

    return 0
  fi
}


_source_updater_help () {
  [[ $# -gt 0 ]] && debug "=> called with '$@'" || debug "=> called with no args"

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
        _source_updater_short_help
        ;;
    esac
  fi

  return 0
}


_source_updater_short_help () {
  cat <<-HELP
    source-updater help blurb
          - todo - 
	HELP

  return 0
}


source-updater () {
  [[ $# -gt 0 ]] && debug "=> called with '$@'" || debug "=> called with no args"

  while [[ $# -gt 0 ]]
  do
    debug "arg '$1'"

    command="$1"
    shift
    case "$command" in
      init|reset)
        SOURCE_MOD_TIMES=() ;;
      --help|help)
        _source_updater_help $@ ;;
      list)
        source-list $@;;
      reload|update)
        source-reload $@ ;;
      track)
        source-track $@ ;;
      untrack|forget)
        source-untrack $@ ;;
      *)
        break ;;
    esac
  done

  _source_updater_short_help
  return 1
}


