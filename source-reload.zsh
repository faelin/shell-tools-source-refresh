#!/bin/zsh


### LOGGING UTILITY ###
#
# empty logging functions to avoid errors
#  for anyone who lacks inject-logger
warn () { return 1 }
debug () { return 1 }
state () { return 1 }
#
# source "$HOME/.zsh-custom/inject-logger.zsh"
# log_source "source_reload.zsh"
# log_level 'debug'



################################################
### auto refresh modified shell and rc files ###
################################################


alias SOURCE_RELOAD_METHOD='source'
export SOURCE_RELOAD_METHOD


# tracks the last reload of targeted files
#   targets should be defined in glob-form or absolute path
declare -Ag SOURCE_MOD_TIMES
export SOURCE_MOD_TIMES
declare -Ag SOURCE_AUTO_TRACK_TIMES
export SOURCE_AUTO_TRACK_TIMES
declare -Ag SOURCE_AUTO_TRACK_ARGS
export SOURCE_AUTO_TRACK_ARGS


# get the "last modified" time of a file
_source_reload_get_mod_time () {
  # (( $# )) && debug "=> called with '$@'"
  (( $# )) || return 1

  target=$(eval "echo \"$1\"")

  local _failed=0
  local _time=0

  if [ -e "$target" ]
  then
    _time=$(gstat -c "%Y" "$(realpath "$target")")
    (( $_time )) || _failed=1
  else
    warn "no such file or directory: $target" ||
    echo "no such file or directory: $target" >&2
    _failed=1
  fi

  echo $_time

  (( $_failed )) && return 1 || return 0
}


# reload target files via 'source' command
#   targets should be defined in glob-form
source-reload () {
  (( $# )) && debug "=> called with '$@'" || debug "=> called with no args"

  local _specified=0
  local _mod_time=0
  local _failed=0
  local _source=0
  local _sources=( $@ )

  ## if this function is called with no args
  if ! (( $#_sources ))
  then
    for glob in ${(k)SOURCE_AUTO_TRACK_TIMES[@]}
    do
      # the mod-time here will reflect the parent directory of the glob path
      _mod_time=$( _source_reload_get_mod_time "$(dirname "$glob")" )

      # skip file if _mod_time is 0 (i.e. failed)
      if ! (($_mod_time ))
      then
        _failed=1
        continue
      fi

      (( $SOURCE_MOD_TIMES[$file] )) && _source=$SOURCE_AUTO_TRACK_TIMES[$glob]
      if (( $_source < $_mod_time ))
      then
          debug "exploring auto-track glob '$glob'"
          # debug "found configuration '${SOURCE_AUTO_TRACK_ARGS[$glob]}'"

        SOURCE_AUTO_TRACK_TIMES[$glob]="$_mod_time"
        for file in $(eval "echo $glob")
        do
            debug "tracking-glob found '$file'"
          source-track $SOURCE_AUTO_TRACK_ARGS[$glob] "$file"
        done
      else
        debug "auto-track skipped glob '$glob' (up-to-date)"
      fi
    done

    _sources=( ${(k)SOURCE_MOD_TIMES[@]} )
  else
    _specified=1
  fi


  _mod_time=0
  _source=0
  for file in $_sources
  do
      debug "checking file '$file' timestamps..."

    _mod_time=$(_source_reload_get_mod_time "$file" 2>/dev/null )
    
    # skip file if _mod_time is 0 (i.e. failed)
    if ! (($_mod_time ))
    then
      # source-reload returns 1 if any specified file fails to load
      (( $_specified )) && _failed=1
      source-untrack "$file"
      continue
    fi

      debug "last: $SOURCE_MOD_TIMES[$file], curr: $_mod_time"

    (( $SOURCE_MOD_TIMES[$file] )) && _source=$SOURCE_MOD_TIMES[$file]
    if (( $_specified || $_source < $_mod_time ))
    then
      # only log initial file load when state-loggingstate is enabled
      if (( $_source ))
      then
        echo "[reloading $file]"
      elif (( $_specified ))
      then
        state "[loading $file]"
      else
        echo "[loading $file]"
      fi

      SOURCE_RELOAD_METHOD "$file";
      SOURCE_MOD_TIMES[$file]=$_mod_time
    fi
  done


  (( $_failed )) && return 1 || return 0
}

# automatically check one or more target path-globs for new files to track
source-auto-track () {
  (( $# )) && debug "=> called with '$@'"
  (( $# )) || return 1

  local _glob

  auto_track_args=()
  while (( $# ))
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
        _glob="$1"
        shift

        if ! (( $SOURCE_AUTO_TRACK_TIMES[$_glob] ))
        then
          SOURCE_AUTO_TRACK_TIMES[$_glob]=0
          SOURCE_AUTO_TRACK_ARGS[$_glob]="${auto_track_args[@]}"
          state "following glob '$_glob' with configuration '${auto_track_args[@]}'"
        else
          state "already following glob '$_glob'"
        fi
        ;;
    esac
  done

  return 0
}

# track one or more targets indicated by the passed file-glob(s)
source-track () {
  (( $# )) && debug "=> called with '$@'"
  (( $# )) || return 1

  local _time
  local _path

  while (( $# ))
  do
    case "$1" in
      --set|-s)
        _time="$2"
        shift 2
        ;;
      --set*|-s*)
        _time="${1##*=}"
        shift
        ;;
      --immediate|-i)
        _time='0'
        shift
        ;;
      --no-load|-n)
        _time=''
        shift
        ;;
      --auto-track|-a)
        shift
        source-auto-track $@
        return 0
        ;;
      --*)
        warn "source-reload: unknown argument '$1'" ||
        echo "source-reload: unknown argument '$1'" >&2
        return 1
        ;;
      *)
        _path="$1"
        shift

        if ! (( $SOURCE_MOD_TIMES[$_path] ))
        then
          # set $_time if it has not yet been set
          [[ -z "$_time" ]] && _time="$(_source_reload_get_mod_time "$_path")"
            debug "file init time is '$_time'"

          SOURCE_MOD_TIMES[$_path]="$_time"
          state "tracking file '$_path' with initial time '$_time'"
        else
          state "already tracking file '$_path'"
        fi
        ;;
    esac
  done

  return 0
}


source-untrack () {
  (( $# )) && debug "=> called with '$@'"
  (( $# )) || return 1

  local _path
  for _path in $@
  do
    if (( SOURCE_MOD_TIMES[$_path] ))
    then
      echo "[untracking $_path]"
      unset SOURCE_MOD_TIMES[$_path]
    fi

    if (( SOURCE_AUTO_TRACK_TIMES[$_path] ))
    then
      echo "[untracking $_path]"
      unset SOURCE_AUTO_TRACK_TIMES[$_path]
      unset SOURCE_AUTO_TRACK_ARGS[$_path]
    fi
  done

  return 0
}


source-list () {
  (( $# )) && debug "=> called with '$@'" || debug "=> called with no args"

  if (( $# ))
  then
    local _tracked=()
    
    for key in ${(k)hash[@]}
    do
      [[ "$@" =~ "$key" ]] && _tracked+="$key"
    done

    if (( $#_tracked ))
    then
      state 'the following files are being tracked:'
      echo "${(j:\n:)_tracked[@]}"

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


_source_reload_help () {
  (( $# )) && debug "=> called with '$@'" || debug "=> called with no args"

  if (( $# ))
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


_source_reload_short_help () {
  cat <<-HELP
    source-reload help blurb
          - todo - 
	HELP

  return 0
}


main () {
  (( $# )) && debug "=> called with '$@'" || debug "=> called with no args"

  while (( $# ))
  do
    debug "arg '$1'"

    command="$1"
    shift
    case "$command" in
      init|reset)
        SOURCE_MOD_TIMES=() ;;
      --help|help)
        _source_reload_help $@ ;;
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

  _source_reload_short_help
  return 1
}


