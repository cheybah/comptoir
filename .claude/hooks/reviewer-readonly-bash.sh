#!/usr/bin/env bash
# Hook PreToolUse (Bash) du subagent reviewer : n'autorise que des commandes en lecture seule.
# Entrée : JSON sur stdin ({"tool_input": {"command": "..."}}).
# Sortie : code 0 = autorisé, code 2 = bloqué (le message sur stderr est renvoyé à l'agent).
set -euo pipefail

cmd="$(jq -r '.tool_input.command // empty')"

deny() {
    echo "reviewer (lecture seule) : commande refusée — $1. Commande : $cmd" >&2
    exit 2
}

[[ -z "$cmd" ]] && deny "commande vide"

# Pas de redirection vers un fichier, de substitution ni de sous-shell.
# (2>&1 et >/dev/null sont tolérés.)
stripped="${cmd//2>&1/}"
stripped="${stripped//>\/dev\/null/}"
stripped="${stripped//2>\/dev\/null/}"
if [[ "$stripped" == *">"* || "$cmd" == *'$('* || "$cmd" == *'`'* || "$cmd" == *"<("* ]]; then
    deny "redirection ou substitution interdite"
fi

# Découpe sur les opérateurs de chaînage et vérifie chaque segment.
segments="$(printf '%s' "$cmd" | sed -E 's/(\&\&|\|\||;|\|)/\n/g')"

allowed_segment() {
    local s="$1"
    # Retire un éventuel "cd <dossier>" préalable géré comme segment à part.
    case "$s" in
        "cd "*|"cd") return 0 ;;
        "git status"*|"git diff"*|"git log"*|"git show"*|"git blame"*|"git ls-files"*|"git rev-parse"*) return 0 ;;
        "ls"*|"cat "*|"head "*|"tail "*|"wc "*|"grep "*|"rg "*|"find "*|"sort"*|"uniq"*|"cut "*) ;;
        "./vendor/bin/pint --test"*|"vendor/bin/pint --test"*) return 0 ;;
        "vendor/bin/pest"*|"./vendor/bin/pest"*|"php artisan test"*) return 0 ;;
        "php artisan route:list"*) return 0 ;;
        "npm run lint"*|"npm run typecheck"*|"npm run format:check"*|"npm run test"*) return 0 ;;
        "npx vitest run"*|"npx tsc --noEmit"*|"npx eslint "*) ;;
        *) return 1 ;;
    esac
    # Garde-fous sur les commandes génériques.
    [[ "$s" == find* && ( "$s" == *"-delete"* || "$s" == *"-exec"* ) ]] && return 1
    [[ "$s" == npx\ eslint* && "$s" == *"--fix"* ]] && return 1
    return 0
}

while IFS= read -r seg; do
    # Trim
    seg="${seg#"${seg%%[![:space:]]*}"}"
    seg="${seg%"${seg##*[![:space:]]}"}"
    [[ -z "$seg" ]] && continue
    allowed_segment "$seg" || deny "segment non autorisé « $seg »"
    # Jamais de lecture des .env (règle du projet).
    [[ "$seg" =~ (^|[[:space:]/])\.env([[:space:]]|$|\.) && "$seg" != *".env.example"* ]] \
        && deny "lecture des fichiers .env interdite"
done <<< "$segments"

exit 0
