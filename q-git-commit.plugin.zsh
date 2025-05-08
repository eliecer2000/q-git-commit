# Oh My Zsh plugin: q-git-commit
# Enhances Git commit workflow with Amazon Q integration, with set -u safety.

# Global variables for configuration (initialized to avoid set -u issues)
ticket_code=""
confirm_commit=""
confirm_push=""
unverified_commit=""
language=""
qcommit_config_file=""

# Load or initialize configuration for the plugin.
_qcommit_ensure_config() {
  # Verify we are inside a Git repository
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [[ -z "$repo_root" ]]; then
    echo "Not a Git repository. Aborting."
    return 1
  fi
  qcommit_config_file="$repo_root/.qcommitrc.yml"
  # Load existing config if present
  if [[ -f "$qcommit_config_file" ]]; then
    ticket_code=$(grep '^ticket_code:' "$qcommit_config_file" | sed -E 's/^ticket_code:[[:space:]]*"?([^"]*)"?/\1/')
    confirm_commit=$(grep '^confirm_commit:' "$qcommit_config_file" | grep -q true && echo "yes" || echo "no")
    confirm_push=$(grep '^confirm_push:' "$qcommit_config_file" | grep -q true && echo "yes" || echo "no")
    unverified_commit=$(grep '^unverified_commit:' "$qcommit_config_file" | grep -q true && echo "yes" || echo "no")
    language=$(grep '^language:' "$qcommit_config_file" | sed 's/^language:[[:space:]]*"\?\(.*\)"\?/\1/')
  fi
  # If config is missing or incomplete (except ticket_code which may be empty by intent), prompt for all values
  if [[ ! -f "$qcommit_config_file" || -z "$confirm_commit" || -z "$confirm_push" || -z "$unverified_commit" || -z "$language" ]]; then
    echo "Configuring q-git-commit plugin settings..."
    local input input_lower
    # 1. Ticket code (can be empty if no ticket)
    printf "Ticket code (e.g. JIRA-123) [%s]: " "$ticket_code"
    read input
    if [[ -n "$input" ]]; then
      ticket_code="$input"
    fi
    # 2. Confirm commit message before committing?
    printf "Confirm commit message before committing? (yes/no) [%s]: " "$confirm_commit"
    read input
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    if [[ "$input_lower" = yes || "$input_lower" = y ]]; then
      confirm_commit="yes"
    elif [[ "$input_lower" = no || "$input_lower" = n ]]; then
      confirm_commit="no"
    elif [[ -n "$input" ]]; then
      confirm_commit="$input_lower"
    fi
    [[ -z "$confirm_commit" ]] && confirm_commit="yes" # Default to yes
    # 3. Auto-push after commit?
    printf "Auto-push to remote after commit? (yes/no) [%s]: " "$confirm_push"
    read input
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    if [[ "$input_lower" = yes || "$input_lower" = y ]]; then
      confirm_push="yes"
    elif [[ "$input_lower" = no || "$input_lower" = n ]]; then
      confirm_push="no"
    elif [[ -n "$input" ]]; then
      confirm_push="$input_lower"
    fi
    [[ -z "$confirm_push" ]] && confirm_push="no" # Default to no
    # 4. Allow commit without ticket code?
    printf "Allow commits without a ticket code (unverified commits)? (yes/no) [%s]: " "$unverified_commit"
    read input
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    if [[ "$input_lower" = yes || "$input_lower" = y ]]; then
      unverified_commit="yes"
    elif [[ "$input_lower" = no || "$input_lower" = n ]]; then
      unverified_commit="no"
    elif [[ -n "$input" ]]; then
      unverified_commit="$input_lower"
    fi
    [[ -z "$unverified_commit" ]] && unverified_commit="yes" # Default to yes
    # 5. Preferred language for commit message
    printf "Preferred commit message language (en/es/fr/...)? [%s]: " "$language"
    read input
    input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    if [[ -n "$input_lower" ]]; then
      language="$input_lower"
    fi
    [[ -z "$language" ]] && language="en"
    # Ensure consistency: if no ticket code given but unverified not allowed, adjust setting
    if [[ -z "$ticket_code" && "$unverified_commit" = "no" ]]; then
      echo "No ticket code provided, but unverified commits are disallowed. Enabling unverified commits."
      unverified_commit="yes"
    fi
    # Save configuration to .qcommitrc.yml
    {
      echo "ticket_code: \"$ticket_code\""
      echo "confirm_commit: $([[ \"$confirm_commit\" == \"yes\" ]] && echo true || echo false)"
      echo "confirm_push: $([[ \"$confirm_push\" == \"yes\" ]] && echo true || echo false)"
      echo "unverified_commit: $([[ \"$unverified_commit\" == \"yes\" ]] && echo true || echo false)"
      echo "language: \"$language\""
    } >"$qcommit_config_file"
    # Add .qcommitrc.yml to .gitignore if not already ignored
    local gitignore="$repo_root/.gitignore"
    [[ ! -e "$gitignore" ]] && touch "$gitignore"
    if ! grep -qF ".qcommitrc.yml" "$gitignore"; then
      echo ".qcommitrc.yml" >>"$gitignore"
    fi
    echo "Saved configuration to $qcommit_config_file"
  fi
  return 0
}

# Confirm or update the ticket code for the current commit.
_qcommit_confirm_ticket_code() {
  local input new_code
  if [[ -z "$ticket_code" ]]; then
    # No ticket code set
    if [[ "$unverified_commit" = "no" ]]; then
      echo "No ticket code is set, and unverified commits are not allowed. Aborting."
      return 1
    fi
    # Prompt user if they want to set one
    printf "Current ticket code is empty. Set one? [Y/n]: "
    read input
    local input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    if [[ "$input_lower" = y || "$input_lower" = yes || -z "$input" ]]; then
      printf "Enter new ticket code (or leave empty for none): "
      read new_code
      if [[ -n "$new_code" ]]; then
        ticket_code="$new_code"
      else
        ticket_code=""
      fi
    fi
    if [[ -n "$new_code" ]]; then
      # Escape any / or & in the code for sed
      local esc_code
      esc_code=$(echo "$ticket_code" | sed -e 's/[&/]/\\&/g')
      sed -i '' -e "s/^ticket_code:.*/ticket_code: \"$esc_code\"/" "$qcommit_config_file"
    fi
    if [[ -z "$ticket_code" ]]; then
      echo "Note: No ticket code will be included in the commit message."
    fi
  else
    # There is a ticket_code set
    printf "Current ticket code is '%s'. Use this? [Y/n to change]: " "${ticket_code//\"/}"
    read input
    local input_lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    if [[ "$input_lower" = n || "$input_lower" = no ]]; then
      printf "Enter new ticket code (or leave empty for none): "
      read new_code
      if [[ -n "$new_code" ]]; then
        ticket_code="$new_code"
      else
        ticket_code=""
      fi
    elif [[ -n "$input" && "$input_lower" != y && "$input_lower" != yes ]]; then
      # If the user entered a non-empty string that's not an explicit yes/no, treat it as a new code
      ticket_code="$input"
    fi
    # Update the config file if the ticket code changed
    if [[ -n "$new_code" || (-n "$input" && "$input_lower" != y && "$input_lower" != yes) ]]; then
      # Escape any / or & in the code for sed
      local esc_code
      esc_code=$(echo "$ticket_code" | sed -e 's/[&/]/\\&/g')
      sed -i '' -e "s/^ticket_code:.*/ticket_code: \"$esc_code\"/" "$qcommit_config_file"
    fi
  fi
  # Final check: if ticket code ended up empty while unverified disallowed, abort
  if [[ -z "$ticket_code" && "$unverified_commit" = "no" ]]; then
    echo "No ticket code provided but unverified commits are disallowed. Aborting."
    return 1
  fi
  return 0
}

# Use Amazon Q CLI to generate a commit message based on repo state and preferences.
_qcommit_generate_message() {
  # Build the prompt for Amazon Q
  local prompt="Generate a git commit message following the Conventional Commits concise format "
  if [[ "$language" != "en" ]]; then
    case "$language" in
    en | english) ;; # English is default, no need to specify
    es | spanish) prompt="$prompt in Spanish" ;;
    fr | french) prompt="$prompt in French" ;;
    pt | portuguese) prompt="$prompt in Portuguese" ;;
    de | german) prompt="$prompt in German" ;;
    it | italian) prompt="$prompt in Italian" ;;
    *) prompt="$prompt in $language" ;;
    esac
  fi
  prompt="$prompt for all changes"
  if [[ -n "$ticket_code" ]]; then
    prompt="$prompt. in case a ticket code exists the ticket code $ticket_code should be included as part of the conventional commit example commit feat($ticket_code)"

  fi
  # Call Amazon Q Developer CLI with the git context
  local q_output q_exit
  # Get detailed information about changes
  GIT_STATUS=$(git status)

  # Get a summary of modified files
  MODIFIED_FILES=$(git diff --name-status)
  STAGED_FILES=$(git diff --name-status --staged)

  # Get list of untracked files
  UNTRACKED=$(git ls-files --others --exclude-standard | xargs -I{} echo "New file: {}")

  # Get current branch
  CURRENT_BRANCH=$(git branch --show-current)

  # Create a temporary file with the request to avoid formatting issues
  TEMP_REQUEST_FILE=$(mktemp)
  echo "$prompt .
  Current branch: $CURRENT_BRANCH
  Repository status:
  $GIT_STATUS
  Modified files (unstaged):
  $MODIFIED_FILES
  Files staged for commit:
  $STAGED_FILES
  Untracked files:
  $UNTRACKED
  IMPORTANT: Reply ONLY with the commit message, without additional explanations or introductory text, you must enclose the message with the following format <<<message>>>, example <<<feat: new docs>>>" >"$TEMP_REQUEST_FILE"

  q_output=$(q chat --no-interactive --trust-all-tools <"$TEMP_REQUEST_FILE")
  q_exit=$?
  if [[ $q_exit -ne 0 ]]; then
    echo "ERROR: Amazon Q CLI failed to generate a message." >&2
    return 1
  fi

  # Remove the temporary file
  rm "$TEMP_REQUEST_FILE"
  echo "$q_output" >/tmp/q_commit_full_response.txt
  CLEAN_MSG=$(echo "$q_output" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g")
  if echo "$CLEAN_MSG" | grep -q "^feat:\|^fix:\|^docs:\|^style:\|^refactor:\|^perf:\|^test:\|^build:\|^ci:\|^chore:\|^revert:"; then
    q_output=$(echo "$CLEAN_MSG" | grep -A 50 "^feat:\|^fix:\|^docs:\|^style:\|^refactor:\|^perf:\|^test:\|^build:\|^ci:\|^chore:\|^revert:")
  else
    if echo "$CLEAN_MSG" | grep -q "El mensaje de commit adecuado sería:"; then
      q_output=$(echo "$CLEAN_MSG" | sed -n '/El mensaje de commit adecuado sería:/,/^$/p' | tail -n +2)
    elif echo "$CLEAN_MSG" | grep -q "El mensaje de commit sería:"; then
      q_output=$(echo "$CLEAN_MSG" | sed -n '/El mensaje de commit sería:/,/^$/p' | tail -n +2)
    else
      q_output="$CLEAN_MSG"
    fi
  fi

  if [ -z "$q_output" ]; then
    echo "⚠️ Could not extract a commit message. Using the full Amazon Q response."
    q_output="$CLEAN_MSG"
  fi

  temp_msg=${q_output#*<<<}
  commit_msg=${temp_msg%%">>>"*}
  # Trim leading/trailing whitespace from output
  commit_msg="${commit_msg#"${commit_msg%%[![:space:]]*}"}"
  commit_msg="${commit_msg%"${commit_msg##*[![:space:]]}"}"
  if [[ -z "$commit_msg" ]]; then
    return 1
  fi
  echo "$commit_msg"
  return 0
}

# Confirm and perform the git commit (and push if enabled) using the generated message.
_qcommit_perform_commit() {
  echo "Committing changes..."
  local commit_msg="$1"
  # If confirm_commit is "no", commit directly without prompt
  if [[ "$confirm_commit" = "no" ]]; then
    # Ensure ticket code is included if required
    if [[ -n "$ticket_code" && "$unverified_commit" = "no" && "$commit_msg" != *"$ticket_code"* ]]; then
      echo "Commit message is missing ticket code '$ticket_code', which is required. Aborting commit."
      return 1
    fi
    # Commit using a temp file to preserve formatting
    local tmpfile="$(mktemp)"
    printf "%s\n" "$commit_msg" >"$tmpfile"
    git commit -F "$tmpfile"
    local commit_status=$?
    rm -f "$tmpfile"
    if [[ $commit_status -ne 0 ]]; then
      echo "git commit failed. Aborting."
      return 1
    fi
    if [[ "$confirm_push" = "yes" ]]; then
      echo "Pushing changes..."
      git push
    fi
    return 0
  fi
  # If confirm_commit is "yes", prompt the user to confirm or edit the message
  echo "Generated commit message:"
  echo "---------------------------------------"
  echo "$commit_msg"
  echo "---------------------------------------"
  echo "Use this commit message? [Y/n] (Yes, No)"
  local input
  read input
  local input_lower="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
  # TODO: Uncomment this block to allow editing the commit message
  # if [[ "$input_lower" = e || "$input_lower" = edit ]]; then
  #   # Open the commit message in an editor for editing
  #   local editor="${VISUAL:-${EDITOR:-vi}}"
  #   local tmpfile="$(mktemp)"
  #   printf "%s\n" "$commit_msg" >"$tmpfile"
  #   $editor "$tmpfile"
  #   if [[ ! -s "$tmpfile" ]]; then
  #     echo "Commit message is empty. Aborting."
  #     rm -f "$tmpfile"
  #     return 1
  #   fi
  #   git commit -F "$tmpfile"
  #   local commit_status=$?
  #   rm -f "$tmpfile"
  #   if [[ $commit_status -ne 0 ]]; then
  #     echo "git commit failed. Aborting."
  #     return 1
  #   fi
  if [[ "$input_lower" = n || "$input_lower" = no ]]; then
    echo "Commit aborted by user."
    return 1
  else
    git add -A
    if [[ "$unverified_commit" = "yes" ]]; then
      git commit -m "$commit_msg" --no-verify
    else
      git commit -m "$commit_msg"
    fi
    local commit_status=$?
    rm -f "$tmpfile"
    if [[ $commit_status -ne 0 ]]; then
      echo "git commit failed. Aborting."
      return 1
    fi
  fi
  if [[ "$confirm_push" = "yes" ]]; then
    echo "Pushing changes..."
    git push
  fi
  return 0
}

# Main command function for q-git-commit
qcommit() {
  _qcommit_ensure_config || return $?
  # Ensure there are staged changes to commit
  if git diff-index --quiet HEAD -- && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "No changes to commit (no staged, no unstaged, no untracked files)."
    return 1
  fi
  echo "Existing changes to project."
  _qcommit_confirm_ticket_code || return $?
  # Generate commit message via Amazon Q
  echo "🔍 Generate commit message via Amazon Q"
  local commit_msg
  if ! commit_msg="$(_qcommit_generate_message)"; then
    echo "Failed to generate commit message via Amazon Q."
  fi
  # Use the generated message to commit (and push if configured)
  _qcommit_perform_commit "$commit_msg"
  return $?
}
