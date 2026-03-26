import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_card_wallet/core/utils/card_utils.dart';
import 'package:my_card_wallet/features/cards/data/datasources/card_ocr_parser.dart';
import 'package:my_card_wallet/features/cards/domain/entities/card_entity.dart';
import 'package:my_card_wallet/features/cards/presentation/providers/card_providers.dart' as card_providers show encryptionServiceProvider;
import 'package:my_card_wallet/features/cards/presentation/providers/card_providers.dart';
import 'package:my_card_wallet/features/cards/presentation/screens/card_scan_screen.dart';
import 'package:my_card_wallet/features/cards/presentation/widgets/card_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  final String? editCardId;
  const AddCardScreen({super.key, this.editCardId});

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  CardNetwork _detectedNetwork = CardNetwork.unknown;
  CardTag _selectedTag = CardTag.personal;
  bool _isSaving = false;
  bool _cvvObscured = true;

  @override
  void initState() {
    super.initState();
    _numberCtrl.addListener(_onNumberChanged);
    
    // Load card if editing
    if (widget.editCardId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCard());
    }
  }

  Future<void> _loadCard() async {
    final repo = ref.read(cardRepositoryProvider);
    final card = await repo.getCardById(widget.editCardId!);
    if (card == null || !mounted) return;

    final number = await repo.revealCardNumber(card.id);
    final cvv = await repo.revealCVV(card.id);

    setState(() {
      _numberCtrl.text = CardUtils.formatCardNumber(number);
      _nameCtrl.text = card.holderName;
      _expiryCtrl.text = '${card.expiryMonth}/${card.expiryYear}';
      _cvvCtrl.text = cvv;
      _bankCtrl.text = card.bankName ?? '';
      _notesCtrl.text = card.notes ?? '';
      _selectedTag = card.tag;
      _detectedNetwork = card.network;
    });
  }

  @override
  void dispose() {
    _numberCtrl.removeListener(_onNumberChanged);
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _bankCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onNumberChanged() {
    final raw = _numberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final network = CardUtils.detectNetwork(raw);
    if (network != _detectedNetwork) {
      setState(() => _detectedNetwork = network);
    }
  }

  Future<void> _scanCard() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isDenied || status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission is required to scan cards.'),
          action: status.isPermanentlyDenied
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<ScannedCardData?>(
      MaterialPageRoute(builder: (_) => const CardScanScreen()),
    );

    if (!mounted || result == null) return;

    // Pre-fill form fields with scanned data
    if (result.cardNumber != null) {
      _numberCtrl.text = CardUtils.formatCardNumber(result.cardNumber!);
      setState(() => _detectedNetwork = result.network);
    }
    if (result.holderName != null) {
      _nameCtrl.text = result.holderName!;
    }
    if (result.expiryMonth != null && result.expiryYear != null) {
      _expiryCtrl.text = '${result.expiryMonth}/${result.expiryYear}';
    }

    // Show what was filled
    final filled = [
      if (result.cardNumber != null) 'card number',
      if (result.holderName != null) 'name',
      if (result.expiryMonth != null) 'expiry',
    ];

    if (filled.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Filled: ${filled.join(', ')}. Please verify and add CVV.'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final encSvc = ref.read(card_providers.encryptionServiceProvider);
      final id = widget.editCardId ?? const Uuid().v4();
      final rawNumber =
          _numberCtrl.text.replaceAll(RegExp(r'\D'), '');
      final rawCVV = _cvvCtrl.text.trim();

      // Parse expiry "MM/YY"
      final expParts = _expiryCtrl.text.split('/');
      final month = expParts[0].trim();
      final year = expParts.length > 1 ? expParts[1].trim() : '';

      final encNumber = await encSvc.encrypt(rawNumber, id);
      final encCVV = await encSvc.encrypt(rawCVV, id);

      final card = CardEntity(
        id: id,
        holderName: _nameCtrl.text.trim(),
        encryptedNumber: encNumber,
        encryptedCVV: encCVV,
        expiryMonth: month,
        expiryYear: year,
        lastFour: CardUtils.getLastFour(rawNumber),
        network: _detectedNetwork,
        tag: _selectedTag,
        bankName: _bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        addedAt: DateTime.now(),
      );

      if (widget.editCardId != null) {
        await ref.read(cardsProvider.notifier).updateCard(card);
      } else {
        await ref.read(cardsProvider.notifier).addCard(card);
      }
      
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save card: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editCardId == null ? 'Add Card' : 'Edit Card'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live card preview
              Center(
                child: CardWidget(
                  card: _buildPreviewCard(),
                  isInteractive: false,
                ),
              ).animate().fadeIn().slideY(begin: -0.2),
              const SizedBox(height: 16),

              // Scan card button
              OutlinedButton.icon(
                onPressed: _scanCard,
                icon: const Icon(Icons.document_scanner_rounded),
                label: const Text('Scan card with camera'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'or fill in manually below',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Card Number
              _SectionLabel('Card Details'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CardNumberFormatter(),
                ],
                maxLength: 19,
                decoration: _inputDecoration(
                  label: 'Card Number',
                  hint: '0000 0000 0000 0000',
                  prefixIcon: Icons.credit_card_rounded,
                  suffix: _detectedNetwork != CardNetwork.unknown
                      ? Text(
                          CardUtils.networkLabel(_detectedNetwork),
                          style: TextStyle(
                            color: CardUtils.networkColor(_detectedNetwork),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                validator: (v) {
                  final raw = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (raw.isEmpty) return 'Card number is required';
                  if (!CardUtils.isValidCardNumber(raw)) {
                    return 'Invalid card number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(
                  label: 'Card Holder Name',
                  hint: 'JOHN DOE',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ExpiryFormatter(),
                      ],
                      maxLength: 5,
                      decoration: _inputDecoration(
                        label: 'Expiry',
                        hint: 'MM/YY',
                        prefixIcon: Icons.calendar_today_rounded,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final parts = v.split('/');
                        if (parts.length != 2) return 'Invalid';
                        if (!CardUtils.isValidExpiry(
                            parts[0].trim(), parts[1].trim())) {
                          return 'Card expired';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: _cvvObscured,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      maxLength: _detectedNetwork == CardNetwork.amex ? 4 : 3,
                      decoration: _inputDecoration(
                        label: 'CVV',
                        hint: _detectedNetwork == CardNetwork.amex
                            ? '0000'
                            : '000',
                        prefixIcon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(_cvvObscured
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded),
                          iconSize: 18,
                          onPressed: () =>
                              setState(() => _cvvObscured = !_cvvObscured),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!CardUtils.isValidCVV(v, _detectedNetwork)) {
                          return 'Invalid CVV';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bankCtrl,
                decoration: _inputDecoration(
                  label: 'Bank Name (optional)',
                  hint: 'e.g. HDFC, Chase, Barclays',
                  prefixIcon: Icons.account_balance_rounded,
                ),
              ),
              const SizedBox(height: 24),

              // Tag
              _SectionLabel('Category'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: CardTag.values.map((tag) {
                  final isSelected = _selectedTag == tag;
                  return ChoiceChip(
                    label: Text(_tagLabel(tag)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedTag = tag),
                    avatar: Icon(_tagIcon(tag), size: 16),
                    selectedColor: theme.colorScheme.primaryContainer,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Notes
              _SectionLabel('Notes (optional)'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: _inputDecoration(
                  label: 'Notes',
                  hint: 'e.g. Primary travel card, limit £5000',
                  prefixIcon: Icons.notes_rounded,
                ),
              ),
              const SizedBox(height: 40),

              // CVV notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18,
                        color: theme.colorScheme.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All card data is encrypted with AES-256 and stored only on this device. Your CVV is encrypted and revealed only after biometric authentication.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon),
        suffix: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        counterText: '',
      );

  CardEntity _buildPreviewCard() {
    final raw = _numberCtrl.text.replaceAll(RegExp(r'\D'), '');
    final expParts = _expiryCtrl.text.split('/');
    return CardEntity(
      id: 'preview',
      holderName: _nameCtrl.text.trim().isEmpty
          ? 'CARD HOLDER'
          : _nameCtrl.text.trim().toUpperCase(),
      encryptedNumber: raw.isEmpty ? '' : raw,
      encryptedCVV: '',
      expiryMonth:
          expParts.isNotEmpty && expParts[0].isNotEmpty ? expParts[0] : 'MM',
      expiryYear: expParts.length > 1 && expParts[1].isNotEmpty
          ? expParts[1]
          : 'YY',
      lastFour: raw.length >= 4 ? CardUtils.getLastFour(raw) : '????',
      network: _detectedNetwork,
      tag: _selectedTag,
      bankName: _bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim(),
      addedAt: DateTime.now(),
    );
  }

  String _tagLabel(CardTag tag) => switch (tag) {
        CardTag.personal => 'Personal',
        CardTag.business => 'Business',
        CardTag.travel => 'Travel',
        CardTag.shopping => 'Shopping',
        CardTag.other => 'Other',
      };

  IconData _tagIcon(CardTag tag) => switch (tag) {
        CardTag.personal => Icons.person_rounded,
        CardTag.business => Icons.business_rounded,
        CardTag.travel => Icons.flight_rounded,
        CardTag.shopping => Icons.shopping_bag_rounded,
        CardTag.other => Icons.label_rounded,
      };
}

// Input Formatters
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue newVal) {
    final text = newVal.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return newVal.copyWith(
      text: formatted,
      selection:
          TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue newVal) {
    var text = newVal.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 4) text = text.substring(0, 4);
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return newVal.copyWith(
      text: formatted,
      selection:
          TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      );
}
