# search_my_lectures
A Bash tool for searching lecture slide PDFs for a term and nearby context, then reporting the matching file and page.

## Prerequisites

- `poppler`

## Supported OSs

- macOS

## Usage

```bash
./search_my_lectures.sh [options] <filename-regex> <search-term>
```

## Options

- `-m`, `--markdown`: export matches to `search_results.md`
- `--dir PATH`: search PDFs under a specific directory
- `--recursive`: include PDFs in subdirectories
- `--case-sensitive`: match the term with case sensitivity
- `--ignore-case`: match the term without case sensitivity
- `--whole-word`: match the term as a whole word
- `--phrase`: match the term as a literal phrase
- `-h`, `--help`: show usage

## Examples

```bash
./search_my_lectures.sh 'lecture.*pdf' 'Bayes theorem'
./search_my_lectures.sh --dir ~/Courses --recursive -m 'week[0-9]+.*pdf' 'gradient descent'
./search_my_lectures.sh --whole-word --case-sensitive 'slides.*pdf' 'entropy'
```
