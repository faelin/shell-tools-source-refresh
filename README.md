source-reload
===

## SYNOPSIS
Track your dotfiles and shell source files and refresh your shell in real time!

## INSTALLATION

Clone this repository:

```
https://github.com/faelin/shell-tools-source-reload
```

Add the following somewhere in your shell configuration

```
source '/path/to/source-reload.zsh'
```

To trigger automatic loading of tracked files, call `source-reload` somewhere in your prompt generator:

### **ZSH**

```sh
(($precmd_functions[(Ie)source-reload])) || precmd_functions+=("source-reload")
```

### **Bash (coming soon, but not currently available!)**

```sh
PS1="{source-reload;}$PS1"
```

## USAGE

### source-track [--auto-track] [--set <time>|--immediate|--no-load] <file, ...>

Adds one or more files to the tracking index. Tracked file(s) will be monitored, and will be loaded into the current shell session via the configured loading command (defaults to 'source') any time the file is modified. Loading occurs whenever `source-reload` is called.

The following options may be invoked when tracking a new file:

```
    -a, --auto-track

          Send all remaining arguments to source-auto-track.

    -s, --set <time>

          Set the initial timestamp of the tracker to the indicated value.

    -i, --immediate

          Causes subsequent files to be loaded as soon as the tracker is created.

          Equivalent to "--set=0"

    -n, --no-load

          Track the file but do not reload it until the next time the file is modified.
```

### source-auto-track <pattern>

Use this command to automatically look for new files to track. When passed a specific filepath, that file be automatically added to the tracker anytime source-reload runs. When given a glob-pattern, _all_ files matching the pattern will be added to the tracker whenever source-reload runs. Globs are expanded at the time of `source-reload`, 

_NOTE: all paths should probably be Absolute paths, for safety!_

If a file added by an auto-track pattern cannot be found, that file will be automatically removed from the tracking index.

This function takes the same arguments as `source-track`, but will not accept the `--auto-track` flag.

### source-untrack <file, ...>

Removes the inidicated file(s) from the current shell's tracking index.

_NOTE: this action will not "unload" the file from your shell session!_

### source-reload [file, ...]

If no file is given, all tracked files will be checked for updates. If one or more filepaths are provided, the indicated files will be immediately reloaded.

If a file is specified, this will immediately load the file via the configured loading command (defaults to 'source'). The specified file will _not_ be added to the tracking index.

### source-list [file, ...]

If no file is given, lists all tracked files. Otherwise this will confirm which files from the provided arguments are being tracked.


## EXAMPLE
```bash
source '/Users/example/source-reload.zsh'

# track files with optional initialization timestamp
source-track --immediate $HOME/.p10k.zsh
source-track --no-load $HOME/.zshrc
source-track --auto-track '$HOME/.zsh-plugins/*.*sh'

# set a prompt-generator function to check file status
(($precmd_functions[(Ie)source-reload])) || precmd_functions+=("source-reload")
```
