import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/copy_button.dart';
import '../../../shared/enums/enums.dart';
import '../application/assets_providers.dart';
import '../domain/asset.dart';

/// Shows a single asset. The MVP fully supports text assets (view / copy /
/// favorite / edit / delete); media rendering arrives with media import.
class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({required this.assetId, super.key});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final assetAsync = ref.watch(assetProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: assetAsync.maybeWhen(
          data: (a) => Text(a?.title ?? a?.name ?? strings.appName),
          orElse: () => Text(strings.appName),
        ),
        actions: [
          assetAsync.maybeWhen(
            data: (a) => a == null ? const SizedBox.shrink() : _Actions(asset: a),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: assetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(strings.genericError)),
        data: (asset) {
          if (asset == null) {
            return Center(child: Text(strings.genericError));
          }
          return _AssetBody(asset: asset);
        },
      ),
    );
  }
}

class _AssetBody extends ConsumerWidget {
  const _AssetBody({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          children: [
            if (asset.type == AssetType.text) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    asset.textContent ?? '',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  CopyButton(
                    text: asset.textContent ?? '',
                    label: strings.copyText,
                    filled: true,
                  ),
                  if ((asset.title ?? '').isNotEmpty)
                    CopyButton(
                      text: '${asset.title}\n\n${asset.textContent ?? ''}',
                      label: strings.copyTitleAndText,
                    ),
                ],
              ),
            ] else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(strings.comingSoon,
                      style: theme.textTheme.bodyMedium),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final controller = ref.read(assetsControllerProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: asset.isFavorite
              ? strings.removeFromFavorites
              : strings.addToFavorites,
          icon: Icon(asset.isFavorite ? Icons.star : Icons.star_border),
          onPressed: () => controller.toggleFavorite(asset),
        ),
        if (asset.type == AssetType.text)
          IconButton(
            tooltip: strings.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go(
              '/folder/${asset.folderId}/edit-text/${asset.id}',
            ),
          ),
        IconButton(
          tooltip: strings.delete,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context, ref, strings, controller),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
    AssetsController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteAssetTitle),
        content: Text(strings.deleteAssetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.delete(asset);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(strings.contentDeleted)));
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/folder/${asset.folderId}');
    }
  }
}
