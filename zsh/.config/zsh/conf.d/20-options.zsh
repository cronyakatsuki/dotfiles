# 20-options.zsh — Zsh options & settings

# Key timeout in ms (shorter = faster vi mode switching)
export KEYTIMEOUT=15

# ---- History ----
setopt INC_APPEND_HISTORY     # Append to history file immediately
setopt SHARE_HISTORY          # Share history across sessions
setopt HIST_IGNORE_DUPS       # Don't record duplicate entries
setopt HIST_IGNORE_SPACE      # Don't record commands starting with space
setopt HIST_REDUCE_BLANKS     # Trim whitespace
setopt HIST_VERIFY            # Don't execute immediately on history expansion
setopt EXTENDED_HISTORY       # Record timestamp in history

# ---- Navigation ----
setopt AUTO_CD                # Type directory name to cd
setopt AUTO_PUSHD             # cd pushes directory onto stack
setopt PUSHD_IGNORE_DUPS      # Don't push duplicates
setopt PUSHD_MINUS            # Use - for stack navigation

# ---- Completion ----
setopt COMPLETE_IN_WORD       # Complete from both ends of word
setopt ALWAYS_TO_END          # Move cursor to end of completion
setopt PATH_DIRS              # Perform path search even on / in command
setopt GLOB_COMPLETE          # Insert all matches from glob

# ---- Input/Output ----
setopt INTERACTIVE_COMMENTS   # Allow comments in interactive shell
setopt RM_STAR_SILENT         # Don't ask for confirmation on rm *
setopt CLOBBER                # Allow > to truncate files (use >| to avoid)

# ---- Jobs ----
setopt LONG_LIST_JOBS         # List jobs in long format
setopt NOTIFY                 # Report background job status immediately
