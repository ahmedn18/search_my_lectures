#!/bin/bash

if [ -z "$2" ]; then
  echo "Usage: $0 <regex_pattern> <word>"
  exit 1
fi

FILE_REGEX=$1
SEARCH_WORD=$2

# Use -E for macOS Extended Regex
find -E . -maxdepth 1 -regex ".*/$FILE_REGEX" | sort -V | while read -r FILE_PATH; do

  # Get page count
  NUM_PAGES=$(pdfinfo "$FILE_PATH" 2>/dev/null | grep Pages | awk '{print $2}')

  if [[ -z "$NUM_PAGES" ]]; then
    continue
  fi

  for ((page = 1; page <= $NUM_PAGES; page++)); do

    # Extract page, filter exclusions, then find keyword
    MATCH_DATA=$(pdftotext -layout -f "$page" -l "$page" "$FILE_PATH" - 2>/dev/null |
      grep -i -B 4 -A 4 "$SEARCH_WORD" |
      grep -vE "CSE|Dr\." |
      grep -i --color=always "$SEARCH_WORD")
    if [[ -n "$MATCH_DATA" ]]; then
      printf "\n\033[1;32m[MATCH FOUND]\033[0m\n"
      printf "File: \033[1;34m%s\033[0m\n" "$FILE_PATH"
      printf "Page: \033[1;33m%s\033[0m\n" "$page"
      echo "----------------------------------------------"
      echo "$MATCH_DATA"
      printf "----------------------------------------------\n\n"
    fi
  done
done
