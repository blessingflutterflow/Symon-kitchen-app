import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/theme.dart';
import '../data/menu_item_model.dart';
import '../data/restaurant_model.dart';
import 'menu_item_form_screen.dart';

/// Lets a restaurant owner browse, search, filter, add, edit, toggle and
/// delete the dishes on their menu.
class RestaurantMenuManagementScreen extends ConsumerStatefulWidget {
  const RestaurantMenuManagementScreen({super.key, required this.restaurant});

  final RestaurantModel restaurant;

  @override
  ConsumerState<RestaurantMenuManagementScreen> createState() => _RestaurantMenuManagementScreenState();
}

class _RestaurantMenuManagementScreenState extends ConsumerState<RestaurantMenuManagementScreen> {
  String _categoryFilter = 'All';
  int _availabilityFilter = 0; // 0=All, 1=Available, 2=Unavailable
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MenuItemModel> _filtered(List<MenuItemModel> all) {
    var list = all;
    if (_categoryFilter != 'All') list = list.where((i) => i.category == _categoryFilter).toList();
    if (_availabilityFilter == 1) list = list.where((i) => i.isAvailable).toList();
    if (_availabilityFilter == 2) list = list.where((i) => !i.isAvailable).toList();
    if (_query.isNotEmpty) {
      list = list.where((i) => i.name.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    return list;
  }

  Future<void> _confirmDelete(MenuItemModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${item.name}?', style: GoogleFonts.inter(color: AppColors.cream, fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text('This cannot be undone.', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.creamMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) await MenuItemService.deleteItem(item.id);
  }

  void _openForm({MenuItemModel? existing}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MenuItemFormScreen(restaurantId: widget.restaurant.id, existing: existing),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(myMenuItemsProvider(widget.restaurant.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.cream, size: 20),
          ),
        ),
        title: Text('My Menu', style: GoogleFonts.inter(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          GestureDetector(
            onTap: () => _openForm(),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: AppColors.background),
                  const SizedBox(width: 4),
                  Text('Add', style: GoogleFonts.inter(color: AppColors.background, fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: menuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (_, _) => Center(
          child: Text('Could not load your menu.', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13)),
        ),
        data: (items) {
          final filtered = _filtered(items);
          final categories = ['All', ...{for (final i in items) i.category}];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 18, color: AppColors.creamMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search your dishes…',
                            hintStyle: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 14),
                            border: InputBorder.none,
                            isCollapsed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: categories.map((c) {
                      final selected = _categoryFilter == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _categoryFilter = c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.gold : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? AppColors.gold : AppColors.divider),
                            ),
                            child: Text(c,
                                style: GoogleFonts.inter(
                                  color: selected ? AppColors.background : AppColors.creamMuted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: ['All', 'Available', 'Hidden'].asMap().entries.map((e) {
                      final selected = _availabilityFilter == e.key;
                      final count = e.key == 0
                          ? items.length
                          : e.key == 1
                              ? items.where((i) => i.isAvailable).length
                              : items.where((i) => !i.isAvailable).length;
                      return Padding(
                        padding: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _availabilityFilter = e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.surfaceLight : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: selected ? AppColors.creamMuted : AppColors.divider),
                            ),
                            child: Text('${e.value} ($count)',
                                style: GoogleFonts.inter(
                                  color: selected ? AppColors.cream : AppColors.creamMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? _EmptyMenu(onAdd: () => _openForm())
                    : (filtered.isEmpty
                        ? Center(
                            child: Text('No dishes match your search.',
                                style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _MenuItemTile(
                              item: filtered[i],
                              onEdit: () => _openForm(existing: filtered[i]),
                              onDelete: () => _confirmDelete(filtered[i]),
                              onToggle: () => MenuItemService.toggleAvailability(filtered[i].id, filtered[i].isAvailable),
                            ),
                          )),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.gold, size: 32),
            ),
            const SizedBox(height: 20),
            Text('No dishes yet', style: GoogleFonts.inter(color: AppColors.cream, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Add your first dish so customers can start ordering — '
              'use real photos and prices from your menu.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(14)),
                child: Text('Add Your First Dish',
                    style: GoogleFonts.inter(color: AppColors.background, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({required this.item, required this.onEdit, required this.onDelete, required this.onToggle});

  final MenuItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 60,
                height: 60,
                child: item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppColors.surfaceLight),
                        errorWidget: (_, url, error) {
                          debugPrint('[image] dish "${item.name}" failed to load "$url": $error');
                          return Container(
                            color: AppColors.surfaceLight,
                            alignment: Alignment.center,
                            child: const Icon(Icons.fastfood_rounded, color: AppColors.creamMuted, size: 22),
                          );
                        },
                      )
                    : Container(
                        color: AppColors.surfaceLight,
                        alignment: Alignment.center,
                        child: const Icon(Icons.fastfood_rounded, color: AppColors.creamMuted, size: 22),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14.5, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(
                    item.hasVariants
                        ? item.variants.map((v) => '${v.label} R${v.price.toStringAsFixed(2)}').join('  ·  ')
                        : 'R ${item.price.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(color: AppColors.goldLight, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Badge(text: item.category),
                      if (item.hasVariants) ...[
                        const SizedBox(width: 6),
                        _Badge(text: '${item.variants.length} options'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: Icon(
                    item.isAvailable ? Icons.toggle_on_rounded : Icons.toggle_off_outlined,
                    size: 30,
                    color: item.isAvailable ? AppColors.gold : AppColors.creamMuted,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.creamMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
