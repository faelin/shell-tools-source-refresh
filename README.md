source-refresh
===

## SYNOPSIS
Track changes to your dotfiles and shell source files and refresh your shell in real time!

## INSTALLATION

Clone this repository:

```
https://github.com/faelin/shell-tools-source-refresh
```

Add the following somewhere in your shell configuration

```
source '/path/to/source-refresh.zsh'
```

To trigger automatic loading of tracked files, call `source-refresh` somewhere in your prompt generator:

### **ZSH**

```sh
(($precmd_functions[(Ie)source-refresh])) || precmd_functions+=("source-refresh")
```

### **Bash (coming soon!)**

```sh
PS1="{source-refresh;}$PS1"
```

## USAGE

### source-track [--auto-track] [--set <time>|--immediate|--no-load] <file, ...>

Adds one or more files to the tracking index. Tracked file(s) will be monitored, and will be loaded into the current shell session via the configured loading command (defaults to 'source') any time the file is modified. Loading occurs whenever `source-refresh` is called.

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

          Track the file but do not refresh it until the next time the file is modified
```

### source-auto-track <pattern>

Use this command to automatically look for new files to track. When passed a specific filepath, that file be automatically added to the tracker anytime source-refresh runs. When given a glob-pattern, _all_ files matching the pattern will be added to the tracker whenever source-refresh runs. Globs are expanded at the time of `source-refresh`, 

_NOTE: all paths should probably be Absolute paths, for safety!_

If a file added by an auto-track pattern cannot be found, that file will be automatically removed from the tracking index.

This function takes the same arguments as `source-track`, but will not accept the `--auto-track` flag.

### source-untrack <file, ...>

Removes the inidicated file(s) from the current shell's tracking index.

_NOTE: this action will not "unload" the file from your shell session!_

### source-refresh [file, ...]

If no file is given, all tracked files will be checked for updates. If one or more filepaths are provided, the indicated files will be immediately refreshed.

If a file is specified, this will immediately load the file via the configured loading command (defaults to 'source'). The specified file will _not_ be added to the tracking index.

### source-list [file, ...]

If no file is given, lists all tracked files. Otherwise this will confirm which files from the provided arguments are being tracked.


## EXAMPLE
```bash
source '/Users/example/source-refresh.zsh'

# track files with optional initialization timestamp
source-track --immediate $HOME/.p10k.zsh
source-track --no-load $HOME/.zshrc
source-track --auto-track '$HOME/.zsh-plugins/*.*sh'

# set a prompt-generator function to check file status
(($precmd_functions[(Ie)source-refresh])) || precmd_functions+=("source-refresh")
```
