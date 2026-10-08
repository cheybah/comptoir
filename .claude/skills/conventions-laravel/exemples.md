# Exemples « à éviter / attendu »

## 1. Contrôleur mince

À éviter : validation inline, logique métier, modèle brut renvoyé.

```php
class ProductController extends Controller
{
    public function store(Request $request)
    {
        $request->validate(['name' => 'required', 'price' => 'required|numeric']);
        $product = Product::create([
            'name' => $request->name,
            'price_cents' => (int) ($request->price * 100),
        ]);

        return response()->json($product);
    }
}
```

Attendu : `FormRequest` + `Resource`, code 201.

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use Illuminate\Http\JsonResponse;

final class ProductController extends Controller
{
    public function store(StoreProductRequest $request): JsonResponse
    {
        $product = Product::create($request->validated());

        return ProductResource::make($product->load('category'))
            ->response()
            ->setStatusCode(201);
    }
}
```

## 2. Service avec transaction

À éviter : écritures multi-tables sans transaction, stock lu sans verrou, total en `float`.

```php
public function place(array $data): Order
{
    $order = Order::create(['customer_id' => $data['customer_id'], 'total' => 0.0]);
    $total = 0.0;
    foreach ($data['lines'] as $line) {
        $product = Product::find($line['product_id']);
        $product->decrement('stock', $line['quantity']);
        $order->lines()->create([...]);
        $total += $product->price_cents / 100 * $line['quantity'];
    }
    $order->update(['total' => $total]);

    return $order;
}
```

Attendu : tout ou rien, verrou pessimiste, centimes entiers.

```php
<?php

declare(strict_types=1);

namespace App\Services;

use App\Models\Order;
use App\Models\Product;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

final class OrderService
{
    /**
     * @param  array{customer_id: int, lines: list<array{product_id: int, quantity: int}>}  $data
     */
    public function place(array $data): Order
    {
        return DB::transaction(function () use ($data): Order {
            $order = Order::create(['customer_id' => $data['customer_id'], 'total_cents' => 0]);
            $totalCents = 0;

            foreach ($data['lines'] as $line) {
                $product = Product::query()->lockForUpdate()->findOrFail($line['product_id']);

                if ($product->stock < $line['quantity']) {
                    throw ValidationException::withMessages(['lines' => "Stock insuffisant : {$product->sku}"]);
                }

                $product->decrement('stock', $line['quantity']);
                $order->lines()->create([
                    'product_id' => $product->id,
                    'quantity' => $line['quantity'],
                    'unit_price_cents' => $product->price_cents,
                ]);
                $totalCents += $product->price_cents * $line['quantity'];
            }

            $order->update(['total_cents' => $totalCents]);

            return $order;
        });
    }
}
```

## 3. N+1

À éviter : une requête par commande pour le client, puis une par ligne pour le produit.

```php
$orders = Order::query()->latest('placed_at')->get();

return OrderResource::collection($orders); // la Resource lit $order->customer et $line->product
```

Attendu : relations chargées en amont et liste paginée.

```php
$orders = Order::query()
    ->with(['customer', 'lines.product'])
    ->latest('placed_at')
    ->paginate(50);

return OrderResource::collection($orders);
```

Dans la Resource, n'exposer une relation que si elle est chargée :
`'customer' => CustomerResource::make($this->whenLoaded('customer'))`.

## 4. FormRequest

À éviter : règles en chaîne, montant décimal, pas de types de retour.

```php
class StoreProductRequest extends FormRequest
{
    public function rules()
    {
        return ['name' => 'required', 'price' => 'numeric', 'category_id' => 'required'];
    }
}
```

Attendu : classe `final`, règles en tableau, centimes entiers, `exists` sur les FK.

```php
<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

final class StoreProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, list<string>>
     */
    public function rules(): array
    {
        return [
            'category_id' => ['required', 'integer', 'exists:categories,id'],
            'sku' => ['required', 'string', 'max:64', 'unique:products,sku'],
            'name' => ['required', 'string', 'max:190'],
            'price_cents' => ['required', 'integer', 'min:0'],
            'stock' => ['required', 'integer', 'min:0'],
        ];
    }
}
```

## 5. Test Pest

À éviter : un seul test « ça marche », sans vérifier le JSON ni la base.

```php
it('works', function () {
    $response = $this->post('/api/products', ['name' => 'Test']);
    expect($response->status())->toBeLessThan(300);
});
```

Attendu : cas nominal, validation, 404 ; assertions sur le JSON et la base.

```php
<?php

declare(strict_types=1);

use App\Models\Category;
use App\Models\Product;

it('crée un produit et renvoie 201', function () {
    $category = Category::factory()->create();

    $this->postJson('/api/products', [
        'category_id' => $category->id,
        'sku' => 'TRN-001',
        'name' => 'Tournevis',
        'price_cents' => 1999,
        'stock' => 10,
    ])
        ->assertCreated()
        ->assertJsonPath('data.price_cents', 1999);

    $this->assertDatabaseHas('products', ['sku' => 'TRN-001', 'price_cents' => 1999]);
});

it('refuse un prix décimal', function () {
    $this->postJson('/api/products', ['price_cents' => 19.99])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['price_cents', 'name', 'sku']);
});

it('renvoie 404 pour un produit inconnu', function () {
    $this->getJson('/api/products/inconnu')->assertNotFound();
});
```
