#!/usr/bin/env bash
# Builds dist/release/Sink.zip: a Sink/ folder holding exactly the files the TOC
# lists, taken from the committed tree. The release workflow runs this on every
# tag; locally, run  scripts/package.sh [REF]  (REF defaults to HEAD).
set -euo pipefail
cd "$(dirname "$0")/.."

ADDON="Sink"
TOC="${ADDON}_Camelot.toc"
REF="${1:-HEAD}"
OUT="dist/release/${ADDON}.zip"

# The TOC itself plus every file it loads (non-empty lines that are not comments).
files=("$TOC")
while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"          # tolerate CRLF
    line="${line//\\//}"          # TOC paths may use backslashes
    line="${line%%[[:space:]]*}"  # drop trailing [load conditions]
    [[ -z "$line" || "$line" == \#* ]] && continue
    files+=("$line")
done < "$TOC"

for f in "${files[@]}"; do
    if ! git cat-file -e "$REF:$f" 2>/dev/null; then
        echo "error: $f is listed in $TOC but is not committed at $REF" >&2
        exit 1
    fi
done

if [ "$REF" = "HEAD" ] && [ -n "$(git status --porcelain -- "${files[@]}")" ]; then
    echo "warning: uncommitted changes to addon files are not included; git archive packs HEAD" >&2
fi

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
git archive --format=zip --prefix="${ADDON}/" --output="$OUT" "$REF" -- "${files[@]}"

echo "built $OUT"
git archive --format=tar --prefix="${ADDON}/" "$REF" -- "${files[@]}" | tar -tf - | sed 's/^/  /'
