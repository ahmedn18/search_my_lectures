#!/bin/bash

# --- 1. SETUP ---
EXPORT_MD=false
OUTPUT_FILE="$(pwd)/search_results.md"
ARGS=()
MATCH_COUNT=0

# --- 2. PARSE ARGUMENTS ---
for arg in "$@"; do
  [[ "$arg" == "-m" ]] && EXPORT_MD=true || ARGS+=("$arg")
done

FILE_REGEX="${ARGS[0]}"
SEARCH_WORD="${ARGS[1]}"

# --- 3. INITIALIZE OUTPUT FILE ---
if [ "$EXPORT_MD" = true ]; then
  {
    printf "# Search Results: \"%s\"\n\n" "$SEARCH_WORD"
    printf "**Pattern:** \`%s\`  \n" "$FILE_REGEX"
    printf "**Generated:** %s\n\n" "$(date '+%Y-%m-%d %H:%M')"
    printf "---\n\n"
  } >"$OUTPUT_FILE"

  if [ ! -f "$OUTPUT_FILE" ]; then
    echo "ERROR: Could not create $OUTPUT_FILE. Check folder permissions."
    exit 1
  else
    echo "Initialized: $OUTPUT_FILE"
  fi
fi

# --- 4. THE SEARCH ---
while read -r FILE_PATH; do
  FILENAME=$(basename "$FILE_PATH")
  echo "Scanning: $FILENAME"
  NUM_PAGES=$(pdfinfo "$FILE_PATH" 2>/dev/null | grep Pages | awk '{print $2}')
  [[ -z "$NUM_PAGES" ]] && continue

  for ((page = 1; page <= NUM_PAGES; page++)); do
    RAW_TEXT=$(pdftotext -layout -f "$page" -l "$page" "$FILE_PATH" - 2>/dev/null |
      grep -i -B 5 -A 10 "$SEARCH_WORD" |
      grep -vE "CSE|Dr\.")

    if [[ -n "$RAW_TEXT" ]]; then
      ((MATCH_COUNT++))

      # Terminal Output
      printf "\n\033[1;32m[MATCH]\033[0m %s (Page %s)\n" "$FILENAME" "$page"
      echo "$RAW_TEXT" | grep -i --color=always "$SEARCH_WORD"

      # Markdown Output (sanitize for LaTeX compatibility)
      if [ "$EXPORT_MD" = true ]; then
        # Keep only ASCII printable chars + tab/newline, then highlight search term
        CLEAN_TEXT=$(printf '%s' "$RAW_TEXT" | tr -cd '\t\n -~' | sed -E "s/($SEARCH_WORD)/**\1**/gi")
        {
          printf "## %s (Page %s)\n\n" "$FILENAME" "$page"
          printf "**Matched text:**\n\n"
          printf '%s\n\n' "$CLEAN_TEXT"
          printf "---\n\n"
        } >>"$OUTPUT_FILE"
      fi
    fi
  done
done < <(find -E . -maxdepth 1 -regex ".*/$FILE_REGEX" | sort -V)

# --- 5. SUMMARY ---
if [ "$EXPORT_MD" = true ]; then
  printf "\n> **Total matches found:** %s\n" "$MATCH_COUNT" >>"$OUTPUT_FILE"
  echo "Saved $MATCH_COUNT matches to $OUTPUT_FILE"
fi
