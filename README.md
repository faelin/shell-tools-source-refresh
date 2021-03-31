# source-reload
Track your dotfiles and shell source files and refresh your shell in real time!

## Usage
```
    COMMAND [options] <path>

        <path>  -  this program accepts any filepath or glob (or 
                   single-quoted glob string) which indicates one or more 
                   files to operate on.

                   All paths should be absolute, for safety!
```

## Commands
```bash
source-track [--auto-track] [--set <time>|--immediate|--no-load] <file, ...>

    The indicated file(s) will be monitored, and will be loaded into the
    current shell session via the appropriate loading command (defaults to
    the 'source' command).

    The following options can be used when tracking a new file:

      -a, --auto-track

        

      -s, --set <time>



      -i, --immediate



      -n, --no-load




source-auto-track <file|glob>

    


source-untrack <file, ...>

    Causes the current shell session to stop updating from the indicates file(s).


source-reload [file, ...]

    If no file is given, all tracked files will be updated if needed.
    With provided args, the indicated files will be immediately reloaded.


source-list [file, ...]

    If no file is given, lists all tracked files. Otherwise this will 
    confirm which files from the provided arguments are being tracked.
```

## Usage Example
```bash
source '/Users/flandy/.zsh-custom/source-reload.zsh'

# track rc files with optional initialization timestamp
source-track --immediate $HOME/.p10k.zsh
source-track $HOME/.zshrc
source-track $HOME/.p10krc
source-track --auto-track --immediate '$HOME/.zsh-plugins/*.*sh'

# set pre-prompt function to check RC status
(($precmd_functions[(Ie)source-reload])) || precmd_functions+=("source-reload")
```
