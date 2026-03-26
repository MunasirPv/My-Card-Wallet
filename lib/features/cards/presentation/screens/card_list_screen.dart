import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_card_wallet/features/cards/domain/entities/card_entity.dart';
import 'package:my_card_wallet/features/cards/presentation/providers/card_providers.dart';
import 'package:my_card_wallet/features/cards/presentation/widgets/card_widget.dart';
import 'package:shimmer/shimmer.dart';

class CardListScreen extends ConsumerWidget {
  const CardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cardsAsync = ref.watch(filteredCardsProvider);
    final query = ref.watch(searchQueryProvider);
    final selectedTag = ref.watch(selectedTagProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            expandedHeight: 0,
            title: const Text(
              'My Cards',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: () => _showSearch(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),

          // ── Search bar (when active) ──────────────────────────────────────
          if (query.isNotEmpty || selectedTag != null)
            SliverToBoxAdapter(
              child: _SearchChipsRow(
                query: query,
                selectedTag: selectedTag,
                onClear: () {
                  ref.read(searchQueryProvider.notifier).state = '';
                  ref.read(selectedTagProvider.notifier).state = null;
                },
              ),
            ),

          // ── Tag filter chips ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _TagFilterRow(selectedTag: selectedTag),
          ),

          // ── Cards ─────────────────────────────────────────────────────────
          cardsAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => const _CardShimmer(),
                childCount: 3,
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
            data: (cards) {
              if (cards.isEmpty) {
                return const SliverFillRemaining(
                  child: _EmptyState(),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final card = cards[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Dismissible(
                          key: Key(card.id),
                          direction: DismissDirection.horizontal,
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: Colors.blue.shade400,
                            child: const Icon(Icons.edit_rounded, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade400,
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // Edit
                              context.push('/cards/edit/${card.id}');
                              return false;
                            } else {
                              // Delete
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete card?'),
                                  content: Text(
                                    'Remove ${card.holderName}\'s card ending in the last 4 digits? This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              return confirm;
                            }
                          },
                          onDismissed: (direction) async {
                            if (direction == DismissDirection.endToStart) {
                              await ref.read(cardsProvider.notifier).deleteCard(card.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Card deleted')),
                                );
                              }
                            }
                          },
                          child: GestureDetector(
                            onLongPress: () =>
                                _showCardOptions(context, ref, card),
                            child: CardWidget(card: card)
                                .animate(delay: (i * 80).ms)
                                .fadeIn()
                                .slideY(begin: 0.2),
                          ),
                        ),
                      );
                    },
                    childCount: cards.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cards/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Card'),
      ).animate().scale(delay: 300.ms),
    );
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(
      context: context,
      delegate: _CardSearchDelegate(ref),
    );
  }

  void _showCardOptions(
      BuildContext context, WidgetRef ref, CardEntity card) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CardOptionsSheet(card: card),
    );
  }
}

class _TagFilterRow extends ConsumerWidget {
  final CardTag? selectedTag;
  const _TagFilterRow({required this.selectedTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _TagChip(
            label: 'All',
            isSelected: selectedTag == null,
            onTap: () =>
                ref.read(selectedTagProvider.notifier).state = null,
          ),
          ...CardTag.values.map((tag) => _TagChip(
                label: _tagLabel(tag),
                isSelected: selectedTag == tag,
                onTap: () =>
                    ref.read(selectedTagProvider.notifier).state = tag,
              )),
        ],
      ),
    );
  }

  String _tagLabel(CardTag tag) => switch (tag) {
        CardTag.personal => 'Personal',
        CardTag.business => 'Business',
        CardTag.travel => 'Travel',
        CardTag.shopping => 'Shopping',
        CardTag.other => 'Other',
      };
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: theme.colorScheme.primaryContainer,
      ),
    );
  }
}

class _SearchChipsRow extends StatelessWidget {
  final String query;
  final CardTag? selectedTag;
  final VoidCallback onClear;

  const _SearchChipsRow(
      {required this.query,
      required this.selectedTag,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (query.isNotEmpty)
            Chip(
              label: Text('Search: "$query"'),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: onClear,
            ),
        ],
      ),
    );
  }
}

class _CardShimmer extends StatelessWidget {
  const _CardShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          width: double.infinity,
          height: 210,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off_rounded,
              size: 80,
              color: theme.colorScheme.outlineVariant,
            ).animate().fadeIn().scale(begin: const Offset(0.5, 0.5)),
            const SizedBox(height: 24),
            Text(
              'No cards yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            Text(
              'Tap the + button below to add\nyour first card securely.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }
}

class _CardOptionsSheet extends ConsumerWidget {
  final CardEntity card;
  const _CardOptionsSheet({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Edit card'),
            onTap: () {
              Navigator.pop(context);
              GoRouter.of(context).push('/cards/edit/${card.id}');
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_rounded,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              'Delete card',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete card?'),
                  content: Text(
                    'Remove ${card.holderName}\'s card ending in the last 4 digits? This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(cardsProvider.notifier).deleteCard(card.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card deleted')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CardSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;
  _CardSearchDelegate(this.ref);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => close(context, ''),
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) {
    ref.read(searchQueryProvider.notifier).state = query;
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) =>
      const Center(child: Text('Type to search cards...'));
}
