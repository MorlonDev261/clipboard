# Comptabilité, tâches et menu

[← Documentation développeur](../README.md)

Trois écrans accessibles depuis l'onglet « Menu » (`/menu`). Toutes les données vivent dans le
workspace (`<workspace>/.clipboard/`), jamais dans le stockage de l'application.

| Fonction | Domaine | Stockage | Écrans |
| --- | --- | --- | --- |
| Menu | — | — | [menu_screen.dart](../../../lib/features/menu/presentation/menu_screen.dart) |
| Comptabilité | [ledger_entry.dart](../../../lib/features/accounting/domain/ledger_entry.dart) | [accounting_store.dart](../../../lib/features/accounting/data/accounting_store.dart) → `accounting.json` | [accounting_screen.dart](../../../lib/features/accounting/presentation/accounting_screen.dart) |
| Tâches | [task_doc.dart](../../../lib/features/tasks/domain/task_doc.dart) | [task_store.dart](../../../lib/features/tasks/data/task_store.dart) → `tasks/<id>.json` | [tasks_screen.dart](../../../lib/features/tasks/presentation/tasks_screen.dart), [task_editor_screen.dart](../../../lib/features/tasks/presentation/task_editor_screen.dart) |

## Format

`accounting.json`:

```json
{ "version": 1, "entries": [
  { "id": "…", "date": "2026-10-04T00:00:00.000", "amount": 10000,
    "account": "mvola", "type": "sale", "direction": "credit", "note": "…" } ] }
```

- `account`: `orangeMoney | mvola | airtelMoney | cash`; `type`: `purchase | sale | expense`;
  `direction`: `credit | debit`. Le montant est toujours positif ; le solde = crédits − débits.
- Valeurs inconnues → repli (cash / expense / debit) ; entrées invalides ignorées à la lecture.

`tasks/<id>.json`: `{ id, title, createdAt, updatedAt, blocks: [ { id, type: "text" | "checklist", text, items?: [ { id, text, done } ] } ] }`.
Pour un bloc `checklist`, `text` est le titre.

## Écritures

Les deux stores passent par `AsyncMutex` et `writeStringAtomic` (voir
[atomic_file.dart](../../../lib/core/services/atomic_file.dart)), comme `MetadataStore`. Le nom de
fichier d'une tâche est assaini (`[A-Za-z0-9_-]`). L'éditeur de tâche enregistre avec un debounce de
500 ms et vide les changements en attente à la fermeture.

Le dossier `.clipboard` est masqué dans la bibliothèque (fichiers commençant par `.`).

## Tests

[test/accounting_tasks_store_test.dart](../../../test/accounting_tasks_store_test.dart).
