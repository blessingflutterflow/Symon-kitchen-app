import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/theme.dart';
import '../data/menu_item_model.dart';

/// Lets a restaurant owner add a new dish or edit an existing one — name,
/// description, category, price (or size variants), photo and availability.
class MenuItemFormScreen extends StatefulWidget {
  const MenuItemFormScreen({super.key, required this.restaurantId, this.existing});

  final String restaurantId;

  /// When editing an existing dish, its current data.
  final MenuItemModel? existing;

  @override
  State<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends State<MenuItemFormScreen> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  late final _priceCtrl = TextEditingController(
    text: widget.existing != null && !widget.existing!.hasVariants
        ? _stripTrailingZeros(widget.existing!.price)
        : '',
  );

  late String _category = widget.existing?.category ?? kMenuItemCategories.first;
  late bool _isAvailable = widget.existing?.isAvailable ?? true;

  late bool _hasVariants = widget.existing?.hasVariants ?? false;
  late final List<_VariantEntry> _variants = widget.existing != null && widget.existing!.hasVariants
      ? widget.existing!.variants
          .map((v) => _VariantEntry(
                label: TextEditingController(text: v.label),
                price: TextEditingController(text: _stripTrailingZeros(v.price)),
              ))
          .toList()
      : [_VariantEntry.empty()];

  // Free "choose N sides" selection
  late bool _offerSides = (widget.existing?.sidesAllowed ?? 0) > 0;
  late final TextEditingController _sidesAllowedCtrl = TextEditingController(
    text: (widget.existing != null && widget.existing!.sidesAllowed > 0)
        ? widget.existing!.sidesAllowed.toString()
        : '2',
  );
  late final List<TextEditingController> _sideOptions =
      (widget.existing?.sideOptions.isNotEmpty ?? false)
          ? widget.existing!.sideOptions.map((s) => TextEditingController(text: s)).toList()
          : [TextEditingController()];

  // Priced additional extras
  late final List<_ExtraEntry> _extras =
      (widget.existing?.extras.isNotEmpty ?? false)
          ? widget.existing!.extras
              .map((e) => _ExtraEntry(
                    name: TextEditingController(text: e.name),
                    price: TextEditingController(text: _stripTrailingZeros(e.price)),
                  ))
              .toList()
          : [];

  Uint8List? _pickedImageBytes;
  String? _existingImageUrl;

  bool _saving = false;
  String? _error;

  static String _stripTrailingZeros(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    _existingImageUrl = widget.existing?.imageUrl;
  }

  bool get _isEditing => widget.existing != null;

  bool get _valid {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_hasVariants) {
      return _variants.any((v) => v.label.text.trim().isNotEmpty && v.price.text.trim().isNotEmpty);
    }
    return _priceCtrl.text.trim().isNotEmpty;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImageBytes = bytes;
      _existingImageUrl = null;
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              title: Text('Choose from gallery', style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14)),
              onTap: () { Navigator.of(context).pop(); _pickImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.gold),
              title: Text('Take a photo', style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14)),
              onTap: () { Navigator.of(context).pop(); _pickImage(ImageSource.camera); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_valid || _saving) {
      setState(() => _error = 'Please fill in the dish name and price.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String? imageUrl = _existingImageUrl;
      if (_pickedImageBytes != null) {
        imageUrl = await uploadMenuItemImage(_pickedImageBytes!, widget.restaurantId) ?? _existingImageUrl;
      }

      final variants = _hasVariants
          ? _variants
              .where((v) => v.label.text.trim().isNotEmpty && v.price.text.trim().isNotEmpty)
              .map((v) => MenuItemVariant(
                    label: v.label.text.trim(),
                    price: double.tryParse(v.price.text.trim()) ?? 0,
                  ))
              .toList()
          : <MenuItemVariant>[];

      final sideOptions = _offerSides
          ? _sideOptions.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
          : <String>[];
      final sidesAllowed = sideOptions.isEmpty
          ? 0
          : (int.tryParse(_sidesAllowedCtrl.text.trim()) ?? 1).clamp(1, sideOptions.length);

      final extras = _extras
          .where((e) => e.name.text.trim().isNotEmpty && e.price.text.trim().isNotEmpty)
          .map((e) => MenuItemExtra(
                name: e.name.text.trim(),
                price: double.tryParse(e.price.text.trim()) ?? 0,
              ))
          .toList();

      final now = DateTime.now();
      final item = MenuItemModel(
        id: widget.existing?.id ?? '',
        restaurantId: widget.restaurantId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        category: _category,
        price: variants.isNotEmpty ? 0 : (double.tryParse(_priceCtrl.text.trim()) ?? 0),
        isAvailable: _isAvailable,
        imageUrl: imageUrl,
        variants: variants,
        sideOptions: sideOptions,
        sidesAllowed: sidesAllowed,
        extras: extras,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await MenuItemService.updateItem(item.id, item);
      } else {
        await MenuItemService.addItem(item);
      }

      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save this dish. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    for (final v in _variants) {
      v.label.dispose();
      v.price.dispose();
    }
    _sidesAllowedCtrl.dispose();
    for (final c in _sideOptions) {
      c.dispose();
    }
    for (final e in _extras) {
      e.name.dispose();
      e.price.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          _isEditing ? 'Edit Dish' : 'Add Dish',
          style: GoogleFonts.inter(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoPicker(),
              const SizedBox(height: 24),
              _Field(label: 'Dish name', controller: _nameCtrl, hint: 'e.g. Hardbody Chicken'),
              const SizedBox(height: 16),
              _Field(label: 'Description', controller: _descCtrl, hint: 'e.g. Quarter chicken with chips & salad', maxLines: 3),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 20),
              _buildVariantsToggle(),
              const SizedBox(height: 16),
              if (!_hasVariants)
                _Field(
                  label: 'Price (R)',
                  controller: _priceCtrl,
                  hint: 'e.g. 70.50',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                )
              else
                _buildVariantRows(),
              const SizedBox(height: 20),
              _buildSidesSection(),
              const SizedBox(height: 20),
              _buildExtrasSection(),
              const SizedBox(height: 20),
              _buildAvailabilityToggle(),
              const SizedBox(height: 28),
              if (_error != null) ...[
                Text(_error!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.background),
                        )
                      : Text(
                          _isEditing ? 'Save Changes' : 'Add Dish',
                          style: GoogleFonts.inter(color: AppColors.background, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: _pickedImageBytes != null
            ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            : _existingImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: _existingImageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorWidget: (_, url, error) {
                      debugPrint('[image] dish form preview failed to load "$url": $error');
                      return Container(
                        color: AppColors.surfaceLight,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined, color: AppColors.creamMuted, size: 28),
                      );
                    },
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_outlined, color: AppColors.gold, size: 28),
                      const SizedBox(height: 10),
                      Text('Add a photo of this dish', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.creamMuted),
              style: GoogleFonts.inter(color: AppColors.cream, fontSize: 15),
              items: kMenuItemCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVariantsToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Multiple sizes / options', style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('e.g. Quarter / Half / Full, or Small Plate / Large Plate',
                    style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _hasVariants,
            onChanged: (v) => setState(() {
              _hasVariants = v;
              if (v && _variants.isEmpty) _variants.add(_VariantEntry.empty());
            }),
            activeThumbColor: AppColors.background,
            activeTrackColor: AppColors.gold,
            inactiveThumbColor: AppColors.creamMuted,
            inactiveTrackColor: AppColors.surfaceLight,
          ),
        ],
      ),
    );
  }

  Widget _buildVariantRows() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sizes / options', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ..._variants.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VariantRow(
                entry: e.value,
                onRemove: _variants.length > 1 ? () => setState(() => _variants.removeAt(e.key)) : null,
              ),
            )),
        GestureDetector(
          onTap: () => setState(() => _variants.add(_VariantEntry.empty())),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: 6),
                Text('Add another size / option', style: GoogleFonts.inter(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Free side choices', style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('e.g. served with a choice of any 2 sides (no extra charge)',
                        style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 11.5, height: 1.4)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _offerSides,
                onChanged: (v) => setState(() {
                  _offerSides = v;
                  if (v && _sideOptions.isEmpty) _sideOptions.add(TextEditingController());
                }),
                activeThumbColor: AppColors.background,
                activeTrackColor: AppColors.gold,
                inactiveThumbColor: AppColors.creamMuted,
                inactiveTrackColor: AppColors.surfaceLight,
              ),
            ],
          ),
          if (_offerSides) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Customer picks', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 56,
                  child: _PlainField(
                    hint: '2',
                    controller: _sidesAllowedCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 10),
                Text('free side(s)', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Side options', style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._sideOptions.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: _PlainField(hint: 'e.g. Chakalaka', controller: e.value)),
                      if (_sideOptions.length > 1) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _sideOptions.removeAt(e.key)),
                          child: const Icon(Icons.close_rounded, color: AppColors.creamMuted, size: 20),
                        ),
                      ],
                    ],
                  ),
                )),
            GestureDetector(
              onTap: () => setState(() => _sideOptions.add(TextEditingController())),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: AppColors.gold, size: 18),
                    const SizedBox(width: 6),
                    Text('Add side option', style: GoogleFonts.inter(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExtrasSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Additional extras (with prices)', style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Optional paid add-ons, e.g. Beans +R30, Atchar +R25',
              style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 11.5, height: 1.4)),
          const SizedBox(height: 12),
          ..._extras.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _PlainField(hint: 'Extra (e.g. Beans)', controller: e.value.name),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _PlainField(
                        hint: 'Price (R)',
                        controller: e.value.price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _extras.removeAt(e.key)),
                      child: const Icon(Icons.close_rounded, color: AppColors.creamMuted, size: 20),
                    ),
                  ],
                ),
              )),
          GestureDetector(
            onTap: () => setState(() => _extras.add(_ExtraEntry.empty())),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: AppColors.gold, size: 18),
                  const SizedBox(width: 6),
                  Text('Add extra', style: GoogleFonts.inter(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Available to order', style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Turn off when this dish is sold out or off the menu today',
                    style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isAvailable,
            onChanged: (v) => setState(() => _isAvailable = v),
            activeThumbColor: AppColors.background,
            activeTrackColor: AppColors.gold,
            inactiveThumbColor: AppColors.creamMuted,
            inactiveTrackColor: AppColors.surfaceLight,
          ),
        ],
      ),
    );
  }
}

class _VariantEntry {
  final TextEditingController label;
  final TextEditingController price;
  _VariantEntry({required this.label, required this.price});
  factory _VariantEntry.empty() => _VariantEntry(label: TextEditingController(), price: TextEditingController());
}

class _ExtraEntry {
  final TextEditingController name;
  final TextEditingController price;
  _ExtraEntry({required this.name, required this.price});
  factory _ExtraEntry.empty() => _ExtraEntry(name: TextEditingController(), price: TextEditingController());
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.entry, this.onRemove});

  final _VariantEntry entry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _PlainField(hint: 'Label (e.g. Quarter)', controller: entry.label),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _PlainField(
            hint: 'Price (R)',
            controller: entry.price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, color: AppColors.creamMuted, size: 20),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: AppColors.cream, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.creamMuted),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold)),
          ),
        ),
      ],
    );
  }
}

class _PlainField extends StatelessWidget {
  const _PlainField({required this.hint, required this.controller, this.keyboardType, this.inputFormatters});

  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(color: AppColors.cream, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.creamMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold)),
      ),
    );
  }
}
