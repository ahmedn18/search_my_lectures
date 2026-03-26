#!/bin/bash

set -u

EXPORT_MD=false
SEARCH_ROOT="."
RECURSIVE=false
CASE_INSENSITIVE=true
MATCH_MODE="regex"
OUTPUT_FILE="$(pwd)/search_results.md"
ARGS=()
MATCH_COUNT=0

usage() {
  cat <<'EOF'
Usage:
  ./search_my_lectures.sh [options] <filename-regex> <search-term>

Options:
  -m, --markdown        Export results to search_results.md
  --dir PATH            Search PDFs under PATH instead of the current directory
  --recursive           Search PDFs in subdirectories too
  --case-sensitive      Match the search term with case sensitivity
  --ignore-case         Match the search term without case sensitivity
  --whole-word          Match the search term as a whole word
  --phrase              Match the search term as a literal phrase
  -h, --help            Show this help message

Examples:
  ./search_my_lectures.sh 'lecture.*pdf' 'Bayes theorem'
  ./search_my_lectures.sh --dir ~/Courses --recursive -m 'week[0-9]+.*pdf' 'gradient descent'
  ./search_my_lectures.sh --whole-word --case-sensitive 'slides.*pdf' 'entropy'
EOF
}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

escape_ere_literal() {
  local text=$1
  text=${text//\\/\\\\}
  text=${text//./\\.}
  text=${text//[/\\[}
  text=${text//]/\\]}
  text=${text//^/\\^}
  text=${text//$/\\$}
  text=${text//*/\\*}
  text=${text//+/\\+}
  text=${text//?/\\?}
  text=${text//(/\\(}
  text=${text//)/\\)}
  text=${text//\{/\\{}
  text=${text//\}/\\}}
  text=${text//|/\\|}
  printf '%s' "$text"
}

build_whole_word_pattern() {
  local literal
  literal=$(escape_ere_literal "$1")
  printf '(^|[^[:alnum:]_])%s([^[:alnum:]_]|$)' "$literal"
}

match_page_text() {
  local page_text=$1
  local grep_mode grep_flags grep_pattern

  case "$MATCH_MODE" in
    regex)
      grep_mode="grep"
      grep_pattern=$SEARCH_WORD
      ;;
    phrase)
      grep_mode="grep -F"
      grep_pattern=$SEARCH_WORD
      ;;
    whole-word)
      grep_mode="grep -E"
      grep_pattern=$(build_whole_word_pattern "$SEARCH_WORD")
      ;;
    *)
      die "Unsupported search mode: $MATCH_MODE"
      ;;
  esac

  grep_flags=(-B 5 -A 10 -- "$grep_pattern")
  if [ "$CASE_INSENSITIVE" = true ]; then
    grep_flags=(-i "${grep_flags[@]}")
  fi

  case "$grep_mode" in
    grep)
      printf '%s\n' "$page_text" | grep "${grep_flags[@]}"
      ;;
    "grep -F")
      printf '%s\n' "$page_text" | grep -F "${grep_flags[@]}"
      ;;
    "grep -E")
      printf '%s\n' "$page_text" | grep -E "${grep_flags[@]}"
      ;;
  esac
}

print_terminal_match() {
  local file_path=$1
  local page=$2
  local raw_text=$3

  printf '\n\033[1;32m[MATCH]\033[0m %s (Page %s)\n' "$file_path" "$page"

  case "$MATCH_MODE" in
    regex)
      if [ "$CASE_INSENSITIVE" = true ]; then
        printf '%s\n' "$raw_text" | grep -i --color=always -- "$SEARCH_WORD"
      else
        printf '%s\n' "$raw_text" | grep --color=always -- "$SEARCH_WORD"
      fi
      ;;
    phrase)
      if [ "$CASE_INSENSITIVE" = true ]; then
        printf '%s\n' "$raw_text" | grep -iF --color=always -- "$SEARCH_WORD"
      else
        printf '%s\n' "$raw_text" | grep -F --color=always -- "$SEARCH_WORD"
      fi
      ;;
    whole-word)
      local word_pattern
      word_pattern=$(build_whole_word_pattern "$SEARCH_WORD")
      if [ "$CASE_INSENSITIVE" = true ]; then
        printf '%s\n' "$raw_text" | grep -iE --color=always -- "$word_pattern"
      else
        printf '%s\n' "$raw_text" | grep -E --color=always -- "$word_pattern"
      fi
      ;;
  esac
}

write_markdown_header() {
  {
    printf '# Search Results: "%s"\n\n' "$SEARCH_WORD"
    printf '**Pattern:** `%s`  \n' "$FILE_REGEX"
    printf '**Search root:** `%s`  \n' "$SEARCH_ROOT"
    printf '**Traversal:** %s  \n' "$([ "$RECURSIVE" = true ] && printf 'recursive' || printf 'top-level')"
    printf '**Search mode:** %s  \n' "$MATCH_MODE"
    printf '**Case sensitivity:** %s  \n' "$([ "$CASE_INSENSITIVE" = true ] && printf 'ignore-case' || printf 'case-sensitive')"
    printf '**Generated:** %s\n\n' "$(date '+%Y-%m-%d %H:%M')"
    printf '---\n\n'
  } >"$OUTPUT_FILE"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--markdown)
      EXPORT_MD=true
      ;;
    --dir)
      shift
      [[ $# -gt 0 ]] || die "--dir requires a path"
      SEARCH_ROOT=$1
      ;;
    --recursive)
      RECURSIVE=true
      ;;
    --case-sensitive)
      CASE_INSENSITIVE=false
      ;;
    --ignore-case)
      CASE_INSENSITIVE=true
      ;;
    --whole-word)
      MATCH_MODE="whole-word"
      ;;
    --phrase)
      MATCH_MODE="phrase"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        ARGS+=("$1")
        shift
      done
      break
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      ARGS+=("$1")
      ;;
  esac
  shift
done

if [ "${#ARGS[@]}" -ne 2 ]; then
  usage >&2
  exit 1
fi

FILE_REGEX=${ARGS[0]}
SEARCH_WORD=${ARGS[1]}

[[ -d "$SEARCH_ROOT" ]] || die "Search root is not a directory: $SEARCH_ROOT"

require_command pdfinfo
require_command pdftotext
require_command grep
require_command find
require_command sort

validate_eregex() {
  local pattern=$1
  local sample=$2

  if printf '%s\n' "$sample" | grep -Eq -- "$pattern" >/dev/null 2>&1; then
    return 0
  fi

  local status=$?
  [[ $status -eq 1 ]] || return "$status"
  return 0
}

if [ "$EXPORT_MD" = true ]; then
  write_markdown_header
  echo "Initialized: $OUTPUT_FILE"
fi

validate_eregex "$FILE_REGEX" "sample.pdf" || die "Invalid filename regex: $FILE_REGEX"
if [ "$MATCH_MODE" = regex ]; then
  validate_eregex "$SEARCH_WORD" "sample text" || die "Invalid search regex: $SEARCH_WORD"
fi

if [ "$RECURSIVE" = true ]; then
  FIND_OUTPUT=$(find "$SEARCH_ROOT" -type f -name '*.pdf' | sort -V)
else
  FIND_OUTPUT=$(find "$SEARCH_ROOT" -maxdepth 1 -type f -name '*.pdf' | sort -V)
fi

while IFS= read -r FILE_PATH; do
  [ -n "$FILE_PATH" ] || continue

  FILENAME=$(basename "$FILE_PATH")
  printf 'Scanning: %s\n' "$FILE_PATH"
  if printf '%s\n' "$FILENAME" | grep -Eq -- "$FILE_REGEX"; then
    :
  else
    status=$?
    [ "$status" -eq 1 ] || die "Invalid filename regex: $FILE_REGEX"
    continue
  fi

  NUM_PAGES=$(pdfinfo "$FILE_PATH" 2>/dev/null | awk '/Pages/ {print $2}')
  [[ -n "$NUM_PAGES" ]] || continue

  for ((page = 1; page <= NUM_PAGES; page++)); do
    PAGE_TEXT=$(pdftotext -layout -f "$page" -l "$page" "$FILE_PATH" - 2>/dev/null)
    [[ -n "$PAGE_TEXT" ]] || continue

    if RAW_TEXT=$(match_page_text "$PAGE_TEXT"); then
      [[ -n "$RAW_TEXT" ]] || continue
    else
      status=$?
      [ "$status" -eq 1 ] || die "Search pattern failed for mode '$MATCH_MODE': $SEARCH_WORD"
      continue
    fi

    ((MATCH_COUNT++))
    print_terminal_match "$FILE_PATH" "$page" "$RAW_TEXT"

    if [ "$EXPORT_MD" = true ]; then
      {
        printf '## %s (Page %s)\n\n' "$FILE_PATH" "$page"
        printf '**Matched text:**\n\n'
        printf '```text\n%s\n```\n\n' "$RAW_TEXT"
        printf '---\n\n'
      } >>"$OUTPUT_FILE"
    fi
  done
done <<<"$FIND_OUTPUT"

if [ "$EXPORT_MD" = true ]; then
  printf '> **Total matches found:** %s\n' "$MATCH_COUNT" >>"$OUTPUT_FILE"
  echo "Saved $MATCH_COUNT matches to $OUTPUT_FILE"
else
  printf '\nTotal matches found: %s\n' "$MATCH_COUNT"
fi
