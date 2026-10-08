---
name: nouvelle-feature
description: Développe une fonctionnalité Comptoir en imposant le cycle plan validé, tests en échec, implémentation minimale, vérifications, relecture et résumé.
argument-hint: "[description de la fonctionnalité]"
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git branch *) Bash(git diff *)
---

# Nouvelle fonctionnalité : $ARGUMENTS

## Contexte

- Branche courante : !`git branch --show-current`
- État du dépôt :

!`git status --short`

## Déroulé

### 1. Explorer et planifier, sans rien modifier

- Lis le code concerné et `docs/architecture.md` si la fonctionnalité touche aux commandes ou à la facturation.
- Ne crée, ne modifie et ne supprime aucun fichier à cette étape.
- Propose un plan : fichiers touchés (API et/ou front), tests à écrire, risques et points fragiles.
- **ARRÊTE-TOI ICI.** Attends que l'utilisateur réponde exactement « OK plan » avant de passer à l'étape 2.

### 2. Écrire les tests et montrer qu'ils échouent

- API : tests Pest dans `api/tests/` ; front : Vitest dans `web/lib/**/*.test.ts`.
- Lance uniquement les nouveaux tests (`vendor/bin/pest --filter="…"` ou `npx vitest run <fichier>`) et montre la sortie en échec.

### 3. Implémenter le minimum

- Écris le code strictement nécessaire pour faire passer les tests, sans refactorisation annexe.
- PHP : `declare(strict_types=1)` dans les fichiers créés ou modifiés, types stricts, montants en centimes entiers.
- TypeScript strict ; appels API via `web/lib/api.ts`.

### 4. Vérifier

Dans `api/` :
- `php artisan test`
- `./vendor/bin/pint --test`

Dans `web/`, si le front est touché :
- `npm run lint`
- `npm run test`

Montre les sorties. Si une vérification échoue, corrige puis relance avant de continuer.

### 5. Faire relire par le subagent `reviewer`

- Délègue la relecture du diff (`git diff`) au subagent `reviewer`.
- Corrige les points bloquants qu'il remonte, puis relance les vérifications de l'étape 4.
- Liste les remarques non bloquantes sans les traiter.

### 6. Résumer et proposer un commit

- Résume les changements : fichiers modifiés, tests ajoutés, résultats des vérifications, remarques non traitées.
- Propose un message de commit (Conventional Commits, en français).
- **Ne fais ni `git commit` ni `git push`.**
