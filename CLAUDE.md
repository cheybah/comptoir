# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Contexte : je suis développeur dans une équipe Laravel / PHP 8.3 et Next.js / TypeScript.
Les données que je te confie pendant cette formation sont fictives.

Règles de réponse :
- Réponds en français.
- Réponses concises : d'abord la réponse, ensuite la justification.
- Quand tu calcules à partir d'un fichier, exécute du code et montre le calcul ;
  ne donne jamais un chiffre estimé de tête.
- Quand tu t'appuies sur une page web ou un document, cite la source.
- Si une information n'est pas vérifiable, dis-le explicitement au lieu de la supposer.
- Pour le code : PHP avec declare(strict_types=1) et types stricts, TypeScript strict.
- Pour les schémas : Mermaid, dans un bloc de code mermaid.

## Projet

Comptoir : e-commerce B2B de démonstration, deux applications dans un même dépôt.
- `api/` : API REST Laravel 12 (PHP 8.3), PostgreSQL 16, Sanctum 4, tests Pest 3.
- `web/` : Next.js 16 (App Router) + React 19, TypeScript, tests Vitest et Playwright.

Installation complète : `README.md`. Architecture détaillée, modèle de données et points
fragiles connus : `docs/architecture.md` (à lire avant de toucher aux commandes ou à la facturation).

## Commandes

Base de données : `docker compose up -d` (crée `comptoir`, `comptoir_test`, `comptoir_e2e` ;
rôle `comptoir`/`comptoir`, port `COMPTOIR_DB_PORT`, 5432 par défaut).

Dans `api/` :
- `php artisan serve` — API sur http://127.0.0.1:8000
- `php artisan test` — tous les tests (les tests Feature utilisent la base `comptoir_test` via `phpunit.xml`, avec `RefreshDatabase`)
- `vendor/bin/pest --testsuite=Unit` — tests unitaires sans base
- `vendor/bin/pest tests/Feature/OrderTest.php` ou `vendor/bin/pest --filter="nom du test"` — un seul test
- `./vendor/bin/pint --test` (vérifier) / `./vendor/bin/pint` (corriger) — formatage, preset `laravel`
- `php artisan invoices:export {id}` — écrit `storage/app/invoices/facture-{id}.pdf`
- `php artisan migrate:fresh --seed` — **destructif**, ne pas lancer sans demande explicite

Dans `web/` :
- `npm run dev` — front sur http://localhost:3000
- `npm run test` — Vitest (`lib/**/*.test.ts`) ; un fichier : `npx vitest run lib/money.test.ts`
- `npm run lint`, `npm run typecheck`, `npm run format:check`
- `npx playwright test` — E2E (`e2e/`), démarre l'API et le front si non lancés ; un test : `npx playwright test e2e/catalogue.spec.ts`

CI (`.github/workflows/lint.yml`) : uniquement Pint, ESLint et `tsc --noEmit`. Les tests
Pest, Vitest et Playwright ne tournent pas en CI : les lancer localement.

## Architecture

- **Montants en centimes entiers** partout (`price_cents`, `total_cents`, `unit_price_cents`) ;
  affichage côté front via `formatPrice` (`web/lib/money.ts`). Exception héritée :
  `LegacyInvoiceCalculator` calcule en euros `float` (voir `docs/architecture.md` §4).
- **API** : contrôleur fin → `FormRequest` (validation) → modèle ou service → `JsonResource`
  (réponses `{"data": ...}`). La logique multi-tables vit dans `app/Services/`
  (`OrderService::place()` : client invité, verrou de stock, lignes, total, en transaction).
  Les erreurs sont rendues en JSON pour `api/*` (`bootstrap/app.php`).
- **Auth** : le modèle authentifiable est `Customer` (pas de `User`), jetons Sanctum ;
  seul `/api/me` est protégé. Un client sans mot de passe est un client invité.
- **Front** : les appels API passent par `web/lib/api.ts` (`ApiResult<T>` pour les POST) ;
  côté serveur `API_URL` est prioritaire sur `NEXT_PUBLIC_API_URL`. Types partagés dans
  `web/types/api.ts`. Le panier est uniquement en `localStorage` (`web/lib/cart.ts`) ;
  le total est recalculé par l'API. `/catalogue` fait exception et appelle `fetch` directement.
- Style front : Prettier (guillemets simples, `printWidth` 100), indentation 2 espaces ;
  PHP indenté à 4 espaces (`.editorconfig`). Le code PHP existant n'a pas encore
  `declare(strict_types=1)` : l'ajouter dans les fichiers modifiés ou créés.
- Ne lis jamais les .env
