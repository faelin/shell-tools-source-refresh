#!/bin/zsh


### LOGGING UTILITY ###
#
# load simple-logger if it is available
SOURCE_REFRESH_LOG_PATH="$HOME/.source-refresh/$$/log"
SOURCE_REFRESH_LOG_TTL=864000  # 10 days in seconds
if source "$LOGGER_SOURCE_LOCATION" 2>/dev/null;
then
  log_source "source_refresh.zsh"
  log_level 'warn'
  log_destination "$SOURCE_REFRESH_LOG_PATH"
else
  # empty logging functions to avoid errors
  #  for anyone who lacks simple-logger
  warn  () { echo $@ > /dev/null }
  state () { echo $@ > /dev/null }
  debug () { echo $@ > /dev/null }
fi


################################################
### auto refresh modified shell and rc files ###
################################################


declare -g SOURCE_REFRESH_METHOD
export SOURCE_REFRESH_METHOD='source'


# tracks the last refresh of targeted files
#   targets should be defined in glob-form or absolute path
declare -Ag SOURCE_TRACKER_TIMES  # (per-file) mod-times
export SOURCE_TRACKER_TIMES
declare -Ag SOURCE_TRACKER_ARGS  # (per-file) arguments called while sourcing
export SOURCE_TRACKER_ARGS
declare -Ag SOURCE_AUTO_TRACKER_TIMES  # (per-glob) last-checked times for trackers
export SOURCE_AUTO_TRACKER_TIMES
declare -Ag SOURCE_AUTO_TRACKER_ARGS  # (per-glob) arguments for each tracker
export SOURCE_AUTO_TRACKER_ARGS
declare -Ag SOURCE_AUTO_TRACKED   # (per-file) mod-times for globbed files
export SOURCE_AUTO_TRACKED


_source_refresh_setup_logs () {
  mkdir -p "$(dirname "$1")"
  for dir in $HOME/.source-refresh/*
  do
    # remove unused log directories
    if (( `gstat -c "%Y" "$dir"` < `date +%s` - $SOURCE_REFRESH_LOG_TTL )) && ! ps -p $(basename "$dir") 2>&1 > /dev/null
    then
      rm -rf "$HOME/.source-refresh/$(basename "$dir")"
    fi
  done
  echo > "$1"
}
_source_refresh_setup_logs "$SOURCE_REFRESH_LOG_PATH"


# get the "last modified" time of a file or directory
_source_refresh_get_mod_time () {
  # (( $# )) && debug "=> called with '$@'"
  (( $# )) || return 1

  target="$(eval "echo \"$1\"")"

  local _failed=0
  local _time=0

  if [ -e "$target" ]
  then
    _time="$(gstat -c "%Y" "$(realpath "$target")")"
    (( $_time )) || _failed=1
  else
    _failed=1
    warn "no such file or directory: $target" ||
    echo "no such file or directory: $target" >&2
  fi

  echo $_time

  return $_failed
}


_source_refresh_import_file () {
  local file="$1"
  local _failed=0

  # turn even array of key/value pairs into associative-array
    debug "tracker_args: ${SOURCE_TRACKER_ARGS[$file]}"
  declare -A tracker_args;
  tracker_args=(${SOURCE_TRACKER_ARGS[$file]})

  local SOURCE_REFRESH_METHOD="$SOURCE_REFRESH_METHOD"
  if [ "$tracker_args[method]" ]
  then
    debug "found configured import method '${tracker_args[method]}'"
    SOURCE_REFRESH_METHOD="${tracker_args[method]}"
  fi


    debug "attempting to load file via '$SOURCE_REFRESH_METHOD'..."

  if ! $SOURCE_REFRESH_METHOD "$file"
  then
    _failed=1
    warn "failed to load file!"
  else
    SOURCE_TRACKER_TIMES[$file]="$_mod_time"
    debug "success, tracking index updated!"
  fi

  return $_failed;
}


_source_refresh_conf_string () {
  [ "$@" ] && echo "with configuration '$@'"
}


# refresh target files via 'source' command
#   targets should be defined in glob-form
source-refresh () {
  (( $# )) && debug "=> called with '$@'" || debug "=> called with no args"

  local _specified=0
  local _mod_time=0
  local _failed=0
  local _tracked_time=0
  local _sources=( $@ )

  ## if this function is called with no args, then check all trackers
  if (( $#_sources ))
  then
    _specified=1
  else
    for glob in ${(k)SOURCE_AUTO_TRACKER_TIMES[@]}
    do
      # the mod-time here will reflect the parent directory of the glob path
      _mod_time="$( _source_refresh_get_mod_time "$(dirname "$glob")" )"

      # skip glob if _mod_time is 0 (i.e. failed)
      if ! (($_mod_time ))
      then
        _failed=1
        continue
      fi

      [ "$SOURCE_TRACKER_TIMES[$file]" ] && _tracked_time="${SOURCE_AUTO_TRACKER_TIMES[$glob]}"
      if (( $_tracked_time < $_mod_time ))
      then
          debug "exploring auto-track glob '$glob'"
          # debug "found configuration '${SOURCE_AUTO_TRACKER_ARGS[$glob]}'"

        SOURCE_AUTO_TRACKER_TIMES[$glob]="$_mod_time"
        for file in $(eval "echo $glob")
        do
            debug "tracking-glob found '$file'"

          source-track ${SOURCE_AUTO_TRACKER_ARGS[$glob]} "$file" &&
          SOURCE_AUTO_TRACKED[$file]="$_mod_time"
        done
      else
        debug "auto-track skipped glob '$glob' (up-to-date)"
      fi
    done

    _sources=( ${(k)SOURCE_TRACKER_TIMES[@]} )
  fi


  _mod_time=0
  _tracked_time=0
  for file in $_sources
  do
      debug "checking file '$file'"

    _mod_time="$(_source_refresh_get_mod_time "$file" 2>/dev/null )"

      debug "last: '${SOURCE_TRACKER_TIMES[$file]}', curr: '$_mod_time'"
    
    # skip file if _mod_time is 0 (i.e. failed)
    if ! (( $_mod_time ))
    then
        debug "could not get mod-time for file '$file'"

      if (( $_specified ))
      then
          debug "file was specified for manual refresh"
        _failed=(( $_failed | $(_source_refresh_import_file "$file") ))
        # bitwise OR to avoid accidentally resetting _failed
      else
        if [ "$(k)SOURCE_AUTO_TRACKED[(e)$file]" ]
        then
          # if file exists in the auto-tracked list, untrack it
            debug "removing auto-tracked file..."
          source-untrack "$file"
        fi
      fi
      continue
    fi

    [ "$SOURCE_TRACKER_TIMES[$file]" ] && _tracked_time="${SOURCE_TRACKER_TIMES[$file]}"
    if (( $_specified || $_tracked_time < $_mod_time ))
    then
      # only log initial file load when state-logging is enabled
      (( $_tracked_time )) && echo "[refreshing $file]" || echo "[loading $file]"

      _source_refresh_import_file "$file"
    fi
  done

  return $_failed
}

# automatically check one or more target path-globs for new files to track
source-auto-track () {
  (( $# )) && debug "=> called with '$@'"
  (( $# )) || return 1

  local _glob

  auto_tracker_args=()
  while (( $# ))
  do
    case "$1" in
      --set|-s)
        auto_tracker_args+=($1 $2)
        shift 2
        ;;
      --method|-m)
        auto_tracker_args+=($1 $2)
        shift 2
        ;;
      --immediate|-i)
        auto_tracker_args+=($1)
        shift
        ;;
      --no-load|-n)
        auto_tracker_args+=($1)
        shift
        ;;
      --auto-track|-a)
        warn "invalid arg '$1' in source-auto-track"
        shift
        ;;
      *)
        _glob="$1"
        shift

        if ! (( ${SOURCE_AUTO_TRACKER_TIMES[$_glob]} ))
        then
          SOURCE_AUTO_TRACKER_TIMES[$_glob]=0
          SOURCE_AUTO_TRACKER_ARGS[$_glob]="${auto_tracker_args[@]}"
          state "following glob '$_glob' $(_source_refresh_conf_string "${auto_tracker_args[@]}")"
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

  tracker_args=()
  while (( $# ))
  do
    case "$1" in
      --set=*|-s=*)
        _time="${1#*=}"
        shift
        ;;
      --set|-s)
        _time="$2"
        shift 2
        ;;
      --immediate|-i)
        _time='0'
        shift
        ;;
      --source-command=*|--method=*|-m=*)
        tracker_args+=("method" "'${1#*=}'")
        shift 2
        ;;
      --source-command|--method|-m)
        tracker_args+=("method" "'$2'")
        shift 2
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
      --refresh|-r)
        shift
        source-refresh
        ;;
      --*|-*)
        warn "source-refresh: unknown argument '$1'" ||
        echo "source-refresh: unknown argument '$1'" >&2
        return 1
        ;;
      *)
        _path="$1"
        shift

        if ! (( ${SOURCE_TRACKER_TIMES[$_path]} ))
        then
          # set $_time if it has not yet been set
          [[ -z "$_time" ]] && _time="$(_source_refresh_get_mod_time "$_path")"
            debug "file init time is '$_time'"

          SOURCE_TRACKER_TIMES[$_path]="$_time"
          SOURCE_TRACKER_ARGS[$_path]="${tracker_args[@]}"
          state "tracking file '$_path' with initial time '$_time' $(_source_refresh_conf_string "${tracker_args[@]}")"
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
    if [ "$SOURCE_TRACKER_TIMES[$_path]" ]
    then
      state "[untracking $_path]"
      unset SOURCE_TRACKER_TIMES[$_path]
    fi

    if [ "$SOURCE_AUTO_TRACKER_TIMES[$_path]" ]
    then
      state "[untracking $_path]"
      unset SOURCE_AUTO_TRACKER_TIMES[$_path]
      unset SOURCE_AUTO_TRACKER_ARGS[$_path]

    fi
  done

  return 0
}


source-list () {
  (( $# )) && debug "=> called with '$@'" || debug "=> called with no args"

  local _tracked=()
  for key in $@
  do
    if [[ ${(k)SOURCE_TRACKER_TIMES[(Ie)$key]} ]]
    then
      _tracked+="$key"
    else
      warn "not tracking any files like '$key'" ||
      echo "not tracking any files like '$key'" >&2
      return 1
    fi
  done

  if (( $#_tracked ))
  then
    state 'the following files are being tracked:'
    echo "${(j:\n:)_tracked[@]}"

    return 0
  else
    if (( $#SOURCE_TRACKER_TIMES ))
    then
      state 'the following files are being tracked:'
      echo "${(kj:\n:)SOURCE_TRACKER_TIMES}"
    fi

    if (( $#SOURCE_AUTO_TRACKER_TIMES )) && (( $#SOURCE_TRACKER_TIMES ))
    then
      state '----' || echo ""
    fi

    if (( $#SOURCE_AUTO_TRACKER_TIMES ))
    then
      state 'the following patterns are being auto-tracked:'
      echo "${(kj:\n:)SOURCE_AUTO_TRACKER_TIMES}"
    fi

    return 0
  fi
}


_source_refresh_help () {
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
      refresh)
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


_source_refresh_short_help () {
  cat <<-HELP
    source-refresh help blurb
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
        SOURCE_TRACKER_TIMES=() ;;
      --help|help)
        _source_refresh_help $@ ;;
      list)
        source-list $@;;
      refresh|update)
        source-refresh $@ ;;
      track)
        source-track $@ ;;
      untrack|forget)
        source-untrack $@ ;;
      *)
        break ;;
    esac
  done

  _source_refresh_short_help
  return 1
}

