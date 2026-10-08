---
name: conventions-laravel
description: Conventions de code de l'API Laravel 12 / PHP 8.3 de Comptoir. À utiliser pour écrire, modifier ou relire du code PHP dans api/ (contrôleurs, FormRequest, services, resources, migrations, tests Pest).
when_to_use: Avant de créer ou modifier un contrôleur, une requête, un service, une resource, une migration ou un test dans api/, et lors d'une revue de code PHP.
---

# Conventions de l'API Laravel (api/)

## Architecture : Contrôleur mince → FormRequest → Service → Resource

- **Contrôleur** : pas de logique métier, pas de validation inline. Il reçoit la `FormRequest`,
  appelle un modèle ou un service, renvoie une `JsonResource`.
- **FormRequest** : toute la validation (`rules(): array`) et l'autorisation (`authorize(): bool`).
  Le contrôleur n'utilise que `$request->validated()`.
- **Service** (`app/Services/`) : toute logique qui touche plusieurs tables ou fait plus qu'un CRUD
  (ex. `OrderService::place()`). Injecté par le conteneur dans la méthode du contrôleur.
- **Resource** : seule forme de sortie (`{"data": ...}`). Relations via `whenLoaded()`, jamais de
  modèle brut ni de `response()->json($model)`.

## PHP

- `declare(strict_types=1);` en tête de chaque fichier créé ou modifié.
- Classes `final` par défaut (contrôleurs, requêtes, services, resources). Exceptions : modèles
  Eloquent et classes conçues pour l'héritage.
- Types partout : paramètres, retours, propriétés (`readonly` pour les dépendances injectées).
- Préférer les DTO / tableaux typés `array{...}` en PHPDoc aux tableaux anonymes non documentés.

## Base de données

- **Eager loading** : toute relation lue dans une Resource ou une boucle est chargée avec `with()`
  (ou `load()` après création). Pas de requête dans une boucle (N+1).
- **Pagination** : les listes utilisent `paginate()` (ou `cursorPaginate()`), jamais `get()` sans limite.
- **Transactions** : toute écriture multi-tables dans `DB::transaction()`, avec `lockForUpdate()`
  sur les lignes dont on lit puis décrémente une valeur (stock).
- **Montants en centimes entiers** (`*_cents`, `int` en PHP, `unsignedBigInteger` en base).
  Jamais de `float`. Seule exception héritée : `LegacyInvoiceCalculator` (ne pas l'imiter).
- **Index sur les FK** : `foreignId('x_id')->index()->constrained()` — PostgreSQL n'indexe pas
  les clés étrangères. Migrations réversibles, jamais modifier une migration fusionnée.

## Codes HTTP

| Cas | Code |
|---|---|
| Lecture OK | 200 |
| Création | 201 (`->response()->setStatusCode(201)`) |
| Suppression sans corps | 204 (`response()->noContent()`) |
| Non authentifié / interdit | 401 / 403 |
| Ressource absente | 404 (route model binding ou `firstOrFail()`) |
| Validation / règle métier | 422 (FormRequest ou `ValidationException`) |

## Tests Pest

- Un test Feature par endpoint dans `api/tests/Feature/`, syntaxe `it('...')` en français.
- Données via factories, assertions sur le JSON (`assertJsonPath`, `assertJsonStructure`) et le code HTTP.
- Couvrir au minimum : cas nominal, validation (422), ressource absente (404), effets en base
  (`assertDatabaseHas`).
- Lancer : `vendor/bin/pest tests/Feature/XxxTest.php`, puis `php artisan test` et `./vendor/bin/pint --test`.

## Ressources

| Fichier | Contenu |
|---|---|
| [exemples.md](exemples.md) | 5 exemples « à éviter / attendu » : contrôleur, service + transaction, N+1, FormRequest, test Pest |
| [gabarits/Controller.stub](gabarits/Controller.stub) | Contrôleur API final (index paginé, show, store 201) |
| [gabarits/StoreRequest.stub](gabarits/StoreRequest.stub) | FormRequest de création |
| [gabarits/Resource.stub](gabarits/Resource.stub) | JsonResource avec relations `whenLoaded()` |
| [gabarits/FeatureTest.stub](gabarits/FeatureTest.stub) | Tests Pest Feature (liste, création, 422, 404) |
| [gabarits/migration.stub](gabarits/migration.stub) | Migration réversible avec FK indexée et montant en centimes |

Marqueurs des gabarits : `{{ Model }}` (Product), `{{ model }}` (product),
`{{ models }}` (products), `{{ table }}` (products).
