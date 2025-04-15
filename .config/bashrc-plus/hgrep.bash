#!/bin/bash

# grep, but with headers! Leverage the power of awk!
hgrep() {
  # Version information
  local VERSION="1.0"

  # Set up colors - do this early so we have colors for error messages
  local COLOR_ENABLED=true
  [[ ! -t 1 ]] && COLOR_ENABLED=false  # Disable colors if not terminal

  local RED='' GREEN='' YELLOW='' BLUE='' RESET=''
  if [[ "$COLOR_ENABLED" == "true" ]]; then
    RED='\033[91m'
    GREEN='\033[92m'
    YELLOW='\033[93m'
    BLUE='\033[96m'
    RESET='\033[0m'
  fi

  # Show help
  show_help() {
    echo "Usage: hgrep [OPTIONS] [FILE] PATTERN"
    echo "       command | hgrep [OPTIONS] PATTERN"
    echo "Search for PATTERN in FILE or stdin"
    echo
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --version           Show version information"
    echo "  -i, --ignore-case       Ignore case distinctions"
    echo "  -l, --lines             Show line numbers"
    echo "  -H, --headers NUM       Process NUM header lines (default: 1)"
    echo "  -f, --file FILE         Search in FILE"
    echo "  -s, --search PATTERN    Search for PATTERN"
    echo "  -m, --multi PATTERN     Add another pattern (can be used multiple times)"
    echo "  -c, --count-lines       Show count instead of line number"
    echo "  -n, --invert-match      Show lines that don't match"
    echo "  -N, --no-highlight      Don't highlight matched patterns"
    echo "  -a, --all               Process all lines (no filtering)"
    echo
    echo "Examples:"
    echo "  lsblk | hgrep sda"
    echo "  hgrep -i -f /etc/hosts localhost"
    echo "  hgrep -H 2 -l -f /etc/hosts -m example.com -m acme.com"
    echo "  flatpak list | hgrep -a"
  }

  # Parse arguments
  local headers=1
  local ignore_case=false
  local show_line_numbers=false
  local count_lines=false
  local invert=false
  local highlight=true
  local all_lines=false
  local file=""
  local patterns=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        return 0
        ;;
      -v|--version)
        echo "hgrep version $VERSION"
        return 0
        ;;
      -i|--ignore-case)
        ignore_case=true
        shift
        ;;
      -l|--lines)
        show_line_numbers=true
        shift
        ;;
      -c|--count-lines)
        count_lines=true
        shift
        ;;
      -n|--invert-match)
        invert=true
        shift
        ;;
      -N|--no-highlight)
        highlight=false
        shift
        ;;
      -a|--all)
        all_lines=true
        shift
        ;;
      -H|--headers)
        headers="$2"
        shift 2
        ;;
      -f|--file)
        file="$2"
        shift 2
        ;;
      -s|--search|-m|--multi)
        patterns+=("$2")
        shift 2
        ;;
      -*)
        echo -e "${RED}Error: Unknown option $1${RESET}" >&2
        echo "Type 'hgrep --help' for usage" >&2
        return 1
        ;;
      *)
        # If no -s/--search was used, treat this as the pattern
        if [[ ${#patterns[@]} -eq 0 ]]; then
          patterns+=("$1")
        else
          echo -e "${RED}Error: Unexpected argument: $1${RESET}" >&2
          echo "Type 'hgrep --help' for usage" >&2
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate args
  [[ $count_lines == true && $show_line_numbers == true ]] && {
    echo -e "${RED}Error: Cannot use both --lines and --count-lines${RESET}" >&2
    return 1
  }

  # Ensure we have a pattern to search or --all is specified
  if [[ ${#patterns[@]} -eq 0 && $all_lines == false ]]; then
    echo -e "${RED}Error: No search pattern provided${RESET}" >&2
    return 1
  fi

  # Prepare input - either from file or stdin
  local input_cmd
  if [[ -n "$file" ]]; then
    [[ ! -e "$file" ]] && {
      echo -e "${RED}Error: File not found: $file${RESET}" >&2
      return 1
    }
    input_cmd="cat '$file'"
  else
    # Check if stdin has data
    if [[ -t 0 ]]; then
      echo -e "${RED}Error: No input provided${RESET}" >&2
      echo "Either specify a file with -f or pipe data to hgrep" >&2
      return 1
    fi
    
    # Simple cat for stdin
    input_cmd="cat"
  fi

  # Build the pattern for awk
  local pattern_str=""
  
  # If all_lines is true, match everything
  if [[ $all_lines == true ]]; then
    pattern_str=".*"
  else
    local pattern_count=${#patterns[@]}
    
    for ((i=0; i<pattern_count; i++)); do
      # Escape pattern for awk to avoid syntax errors
      local escaped_pattern=$(echo "${patterns[$i]}" | sed 's/[\/&]/\\&/g')
      pattern_str+="$escaped_pattern"
      [[ $i -lt $((pattern_count-1)) ]] && pattern_str+="|"
    done
  fi

  # Prepare the awk command
  local awk_cmd="awk -v red=\"${RED}\" -v reset=\"${RESET}\" '"
  
  # Add the header processing
  awk_cmd+="FNR<=$headers {print; next} "
  
  # Add case sensitivity option
  [[ $ignore_case == true ]] && awk_cmd+="BEGIN {IGNORECASE=1} "
  
  # Add counter variable if needed
  [[ $count_lines == true ]] && awk_cmd+="BEGIN {counter=1} "
  
  # Add the pattern matching with highlighting
  if [[ $invert == true ]]; then
    # Don't highlight for inverted matches
    awk_cmd+="!/$pattern_str/ {"
  else
    # For pattern matches, add highlighting before printing
    awk_cmd+="/$pattern_str/ {"
    if [[ "$COLOR_ENABLED" == "true" && "$highlight" == "true" ]]; then
      awk_cmd+="line=\$0; "
      awk_cmd+="gsub(/$pattern_str/, red\"&\"reset, line); " 
    else
      awk_cmd+="line=\$0; "
    fi
  fi
  
  # Handle line display options
  if [[ $show_line_numbers == true ]]; then
    if [[ $invert == true || "$COLOR_ENABLED" != "true" || "$highlight" != "true" ]]; then
      awk_cmd+="printf \"${BLUE}%s:${RESET} %s\\n\", FNR, \$0"
    else
      awk_cmd+="printf \"${BLUE}%s:${RESET} %s\\n\", FNR, line"
    fi
  elif [[ $count_lines == true ]]; then
    if [[ $invert == true || "$COLOR_ENABLED" != "true" || "$highlight" != "true" ]]; then
      awk_cmd+="printf \"${YELLOW}%s:${RESET} %s\\n\", counter++, \$0"
    else
      awk_cmd+="printf \"${YELLOW}%s:${RESET} %s\\n\", counter++, line"
    fi
  else
    if [[ $invert == true || "$COLOR_ENABLED" != "true" || "$highlight" != "true" ]]; then
      awk_cmd+="print \$0"
    else
      awk_cmd+="print line"
    fi
  fi
  
  awk_cmd+="}"
  
  # Close the awk command
  awk_cmd+="'"
  
  # Run the full command
  eval "$input_cmd | $awk_cmd"
}

# Bash completion for hgrep
_hgrep_completion() {
  local cur prev opts used_opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  
  # All available options - removed tty-emulate
  opts="-h --help -H --headers -l --lines -c --count-lines -n --invert-match -i --ignore-case -s --search -m --multi -f --file -v --version -N --no-highlight -a --all"
  
  # Check if help or version is already specified
  for ((i=1; i < COMP_CWORD; i++)); do
    if [[ ${COMP_WORDS[i]} == "-h" || ${COMP_WORDS[i]} == "--help" || 
          ${COMP_WORDS[i]} == "-v" || ${COMP_WORDS[i]} == "--version" ]]; then
      # Don't suggest any options if help or version is specified
      return 0
    fi
  done
  
  # Handle specific option completions
  case "$prev" in
    -f|--file)
      # Complete with files
      COMPREPLY=( $(compgen -f -- "${cur}") )
      return 0
      ;;
    -H|--headers)
      # Complete with numbers 0-9
      COMPREPLY=( $(compgen -W "0 1 2 3 4 5" -- "${cur}") )
      return 0
      ;;
    -s|--search|-m|--multi)
      # No specific completion for search patterns
      return 0
      ;;
  esac
  
  # Check for special exclusions
  local has_search=false
  local has_multisearch=false
  local has_other_options=false
  
  # Build a list of options to exclude
  local exclude_opts=()
  
  for ((i=1; i < COMP_CWORD; i++)); do
    if [[ ${COMP_WORDS[i]} == -* ]]; then
      # Track special conditions
      case ${COMP_WORDS[i]} in
        -s|--search)
          has_search=true
          has_other_options=true
          ;;
        -m|--multi)
          has_multisearch=true
          has_other_options=true
          ;;
        -h|--help|-v|--version)
          # Already checked at the beginning
          ;;
        *)
          has_other_options=true
          ;;
      esac
      
      # For options that don't take arguments or whose args we've already passed
      case ${COMP_WORDS[i]} in
        -h|--help)
          exclude_opts+=("-h" "--help")
          ;;
        -v|--version)
          exclude_opts+=("-v" "--version")
          ;;
        -l|--lines)
          exclude_opts+=("-l" "--lines")
          ;;
        -c|--count-lines)
          exclude_opts+=("-c" "--count-lines")
          ;;
        -n|--invert-match)
          exclude_opts+=("-n" "--invert-match")
          ;;
        -i|--ignore-case)
          exclude_opts+=("-i" "--ignore-case")
          ;;
        -s|--search)
          exclude_opts+=("-s" "--search")
          # If search is specified, exclude multi too
          exclude_opts+=("-m" "--multi")
          i=$((i+1))  # Skip the argument
          ;;
        -f|--file)
          exclude_opts+=("-f" "--file")
          i=$((i+1))  # Skip the argument
          ;;
        -H|--headers)
          exclude_opts+=("-H" "--headers")
          i=$((i+1))  # Skip the argument
          ;;
        -m|--multi)
          # Add search to exclusion if multi is specified
          exclude_opts+=("-s" "--search")
          i=$((i+1))  # Skip the argument
          ;;
      esac
    fi
  done
  
  # Always exclude --help and --version if any other options are present
  if [[ "$has_other_options" == "true" ]]; then
    # Check if they're already excluded
    local help_excluded=false
    local version_excluded=false
    
    for ex_opt in "${exclude_opts[@]}"; do
      [[ "$ex_opt" == "-h" || "$ex_opt" == "--help" ]] && help_excluded=true
      [[ "$ex_opt" == "-v" || "$ex_opt" == "--version" ]] && version_excluded=true
    done
    
    # Add them if they weren't already excluded
    [[ "$help_excluded" == "false" ]] && exclude_opts+=("-h" "--help")
    [[ "$version_excluded" == "false" ]] && exclude_opts+=("-v" "--version")
  fi
  
  # Create available options by filtering out excluded ones
  local available_opts=()
  for opt in $opts; do
    local exclude=false
    for ex_opt in "${exclude_opts[@]}"; do
      if [[ "$opt" == "$ex_opt" ]]; then
        exclude=true
        break
      fi
    done
    
    if [[ "$exclude" == "false" ]]; then
      available_opts+=("$opt")
    fi
  done
  
  # Generate completions based on available options
  if [[ ${cur} == -* ]]; then
    COMPREPLY=( $(compgen -W "${available_opts[*]}" -- ${cur}) )
  else
    COMPREPLY=( $(compgen -f -- "${cur}") $(compgen -W "${available_opts[*]}" -- ${cur}) )
  fi
}

# Register the completion function
complete -F _hgrep_completion hgrep
