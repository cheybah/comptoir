#!/usr/bin/env bash
# Hook PostToolUse (Edit|Write|MultiEdit) : formate le fichier qui vient d'être modifié.
# Entrée : JSON sur stdin ({"tool_input": {"file_path": "..."}}).
# - $CLAUDE_PROJECT_DIR/api/**/*.php (hors *.blade.php) : Pint (preset laravel), lancé depuis api/.
# - $CLAUDE_PROJECT_DIR/web/**/*.{ts,tsx,js,jsx,mjs,cjs,json,css,scss,md,mdx} : Prettier, lancé depuis web/.
# - Ignorés : fichier absent, vendor/, node_modules/, .next/, storage/, tout autre fichier.
# Sortie : 0 = rien à faire ou formatage réussi,
#          1 = jq ou formateur absent (erreur non bloquante, message sur stderr),
#          2 = le formateur a échoué (message sur stderr renvoyé à Claude).
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "format-after-edit : jq est introuvable, formatage ignoré." >&2
    exit 1
fi

file="$(jq -r '.tool_input.file_path // empty')"
[[ -z "$file" ]] && exit 0

# Normalise les séparateurs Windows.
file="${file//\\//}"
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
project_dir="${project_dir//\\//}"
project_dir="${project_dir%/}"

# Chemin relatif → relatif au projet.
[[ "$file" != /* && "$file" != [A-Za-z]:/* ]] && file="$project_dir/$file"

[[ -f "$file" ]] || exit 0

case "$file" in
    */vendor/*|*/node_modules/*|*/.next/*|*/storage/*) exit 0 ;;
    *.blade.php) exit 0 ;;
esac

run_formatter() {
    local dir="$1" bin="$2" name="$3"
    shift 3
    if [[ ! -x "$dir/$bin" ]]; then
        echo "format-after-edit : $name introuvable ($dir/$bin), formatage de $file ignoré." >&2
        exit 1
    fi
    local output
    if ! output="$(cd "$dir" && "$bin" "$@" "$file" 2>&1)"; then
        echo "format-after-edit : $name a échoué sur $file :" >&2
        echo "$output" >&2
        exit 2
    fi
}

case "$file" in
    "$project_dir"/api/*.php)
        run_formatter "$project_dir/api" vendor/bin/pint Pint
        ;;
    "$project_dir"/web/*.ts|"$project_dir"/web/*.tsx|"$project_dir"/web/*.js|"$project_dir"/web/*.jsx|\
    "$project_dir"/web/*.mjs|"$project_dir"/web/*.cjs|"$project_dir"/web/*.json|"$project_dir"/web/*.css|\
    "$project_dir"/web/*.scss|"$project_dir"/web/*.md|"$project_dir"/web/*.mdx)
        run_formatter "$project_dir/web" node_modules/.bin/prettier Prettier --write
        ;;
esac

exit 0
