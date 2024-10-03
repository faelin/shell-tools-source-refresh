# This file needs to be `sourced` to ensure a drop-in behaviour for `source` or `.`
# The shell passess "$@" to source if no arguments are given after the file to be sourced.

# Works in bash.

# Required aliases are:
# alias source='builtin source compile-source-file source "$#" "$@"'
# alias      .='builtin .      compile-source-file .      "$#" "$@"'

# zsh: compile functions before sourcing
# This function expects to be called with:
# $1 builtin to use, either `.` or `source`.
# $2 file to source
# $3... arguments to pass to sourced file
function compile_then_source () {
  local method=$1 file=$2; shift 2; local args=("$@")

  # ${var@Q} gives value of var quoted in a format that can be reused as input
  [[ $BASH_VERSION ]] && { eval builtin "$method" "$file" "${args@Q}"; return $?; }

  if [[ ! $file.zwc -nt $file ]]; then
    # Use canonical pathname for zrecompile's happiness
    if [[ -r $file && -w ${file:h} ]]; then zcompile "${file:P}"; fi
  fi

  eval builtin "$method" "$file" "${(q)args[@]}"
}

function main () {
  local use_builtin=$1  # '.' or 'source'
  local num_args=$2     # Number of elements in calling shell's $@, which follow
  shift 2;
  local wrapper_args=("$@")
  wrapper_args=("${wrapper_args[@]:0:$num_args}")
  shift "$num_args"
  local file=$1; shift;

  # Now $@ is the arguments passed after the file to be soured
  if [[ $# -ge 1 ]]; then # arguments were passed
    use_args=("$@")
  else  # use $@ from the wrapper args
    use_args=("${wrapper_args[@]}")
  fi
  compile_then_source "$use_builtin" "$file" "${use_args[@]}"
}

main "$@"

unset -f main compile_then_source