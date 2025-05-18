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
    echo "  -T, --tail NUM          Show last NUM lines (default: 0)"
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
    echo "  zipinfo archive.zip | hgrep -H 2 -T 10 filename"
  }

  # Parse arguments
  local headers=1
  local tail=0
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
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo -e "${RED}Error: --headers option requires a numeric argument${RESET}" >&2
          echo "Type 'hgrep --help' for usage" >&2
          return 1
        fi
        headers="$2"
        shift 2
        ;;
      -T|--tail)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo -e "${RED}Error: --tail option requires a numeric argument${RESET}" >&2
          echo "Type 'hgrep --help' for usage" >&2
          return 1
        fi
        tail="$2"
        shift 2
        ;;
      -f|--file)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo -e "${RED}Error: --file option requires a filename argument${RESET}" >&2
          echo "Type 'hgrep --help' for usage" >&2
          return 1
        fi
        file="$2"
        shift 2
        ;;
      -s|--search|-m|--multi)
        if [[ -z "$2" || "$2" =~ ^- ]]; then
          echo -e "${RED}Error: --search/--multi option requires a pattern argument${RESET}" >&2
          echo "Type 'hgrep --help' for usage" >&2
          return 1
        fi
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
  local awk_cmd="awk -v red=\"${RED}\" -v reset=\"${RESET}\" -v tail_lines=${tail} '"
  
  # Initialize variables in BEGIN block
  awk_cmd+="BEGIN { "
  if [[ $ignore_case == true ]]; then
    awk_cmd+="IGNORECASE=1; "
  fi
  if [[ $count_lines == true ]]; then
    awk_cmd+="counter=1; "
  fi
  awk_cmd+="pending_count = 0; "
  awk_cmd+="} "
  
  # Always print header lines
  awk_cmd+="FNR <= $headers { print; next } "
  
  # Store all lines for tail functionality
  if [[ $tail -gt 0 ]]; then
    awk_cmd+="{ lines[FNR] = \$0; } "
  fi
  
  # Process pattern matches
  if [[ $invert == true ]]; then
    awk_cmd+="!/$pattern_str/ { processed[FNR] = 1; "
  else
    awk_cmd+="/$pattern_str/ { processed[FNR] = 1; "
    if [[ "$COLOR_ENABLED" == "true" && "$highlight" == "true" ]]; then
      awk_cmd+="line = \$0; gsub(/$pattern_str/, red\"&\"reset, line); "
    else
      awk_cmd+="line = \$0; "
    fi
  fi
  
  # Format and print matched lines
  if [[ $show_line_numbers == true ]]; then
    if [[ $invert == true || "$COLOR_ENABLED" != "true" || "$highlight" != "true" ]]; then
      awk_cmd+="printf \"${BLUE}%s:${RESET} %s\\n\", FNR, \$0; "
    else
      awk_cmd+="printf \"${BLUE}%s:${RESET} %s\\n\", FNR, line; "
    fi
  elif [[ $count_lines == true ]]; then
    if [[ $invert == true || "$COLOR_ENABLED" != "true" || "$highlight" != "true" ]]; then
      awk_cmd+="printf \"${YELLOW}%s:${RESET} %s\\n\", counter++, \$0; "
    else
      awk_cmd+="printf \"${YELLOW}%s:${RESET} %s\\n\", counter++, line; "
    fi
  else
    if [[ $invert == true || "$COLOR_ENABLED" != "true" || "$highlight" != "true" ]]; then
      awk_cmd+="print \$0; "
    else
      awk_cmd+="print line; "
    fi
  fi
  awk_cmd+="} "
  
  # Add END block with tail functionality
  if [[ $tail -gt 0 ]]; then
    awk_cmd+="END { "
    awk_cmd+="  if (tail_lines > 0) { "
    # Sort the tail lines by their original line numbers
    awk_cmd+="    for (i = 1; i <= NR; i++) { if (i > $headers && !processed[i]) pending[pending_count++] = i; } "
    awk_cmd+="    if (pending_count > 0) { "
    # Use only the last tail_lines entries if we have more
    awk_cmd+="      start_idx = (pending_count <= tail_lines) ? 0 : pending_count - tail_lines; "
    awk_cmd+="      for (i = start_idx; i < pending_count; i++) { "
    awk_cmd+="        line_num = pending[i]; "
    
    # Format tail lines consistently
    if [[ $show_line_numbers == true ]]; then
      awk_cmd+="        printf \"${BLUE}%s:${RESET} %s\\n\", line_num, lines[line_num]; "
    elif [[ $count_lines == true ]]; then
      awk_cmd+="        printf \"${YELLOW}%s:${RESET} %s\\n\", counter++, lines[line_num]; "
    else
      awk_cmd+="        print lines[line_num]; "
    fi
    
    awk_cmd+="      } "
    awk_cmd+="    } "
    awk_cmd+="  } "
    awk_cmd+="} "
  fi
  
  # Close the awk command
  awk_cmd+="'"
  
  # Execute the command
  eval "$input_cmd | $awk_cmd"
}

# For sourcing in .bashrc: export the function
export -f hgrep
