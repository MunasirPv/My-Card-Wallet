import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_card_wallet/core/security/session_manager.dart';
import 'package:my_card_wallet/features/auth/presentation/providers/auth_providers.dart';
import 'package:my_card_wallet/features/auth/presentation/screens/pin_screen.dart';
import 'package:my_card_wallet/features/cards/presentation/providers/card_providers.dart';

final _themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);
final _timeoutProvider = StateProvider<Duration>((_) => const Duration(minutes: 2));

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(_themeModeProvider);
    final timeout = ref.watch(_timeoutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_rounded),
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 16)),
                ButtonSegment(
                    value: ThemeMode.system, icon: Icon(Icons.auto_mode, size: 16)),
                ButtonSegment(
                    value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 16)),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(_themeModeProvider.notifier).state = s.first,
              style: const ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ),

          // ── Security ─────────────────────────────────────────────────────
          _SectionHeader('Security'),
          _BiometricTile(),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Auto-lock after'),
            trailing: DropdownButton<Duration>(
              value: timeout,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                    value: Duration(seconds: 30), child: Text('30 sec')),
                DropdownMenuItem(
                    value: Duration(minutes: 1), child: Text('1 min')),
                DropdownMenuItem(
                    value: Duration(minutes: 2), child: Text('2 min')),
                DropdownMenuItem(
                    value: Duration(minutes: 5), child: Text('5 min')),
              ],
              onChanged: (d) {
                if (d == null) return;
                ref.read(_timeoutProvider.notifier).state = d;
                ref.read(sessionManagerProvider.notifier).setTimeout(d);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pin_rounded),
            title: const Text('Change PIN'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const PinScreen(isSetup: true)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_rounded),
            title: const Text('Lock now'),
            onTap: () {
              ref.read(sessionManagerProvider.notifier).lock();
              ref.read(isAuthenticatedProvider.notifier).state = false;
              context.go('/lock');
            },
          ),

          // ── Data ─────────────────────────────────────────────────────────
          _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.backup_rounded),
            title: const Text('Export encrypted backup'),
            subtitle: const Text('Save a password-protected backup file'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showBackupDialog(context),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_rounded,
                color: theme.colorScheme.error),
            title: Text('Delete all cards',
                style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _confirmDeleteAll(context, ref),
          ),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Card Wallet'),
            subtitle: const Text('v1.0.0 • Secure local storage'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            subtitle: const Text(
                'No data is ever sent to any server. All data is encrypted locally.'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export Backup'),
        content: const Text(
          'A password-protected encrypted backup file will be created. '
          'Keep your backup password safe — it cannot be recovered.\n\n'
          'This feature is coming in the next version.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all cards?'),
        content: const Text(
          'This will permanently delete all stored cards. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(cardsProvider.notifier).deleteAllCards();
    }
  }
}

class _BiometricTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends ConsumerState<_BiometricTile> {
  bool _enabled = true;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final authService = ref.read(authServiceProvider);
    final enabled = await authService.isBiometricEnabled();
    final available = await authService.isBiometricAvailable();
    if (mounted) setState(() {
      _enabled = enabled;
      _available = available;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.fingerprint),
      title: const Text('Biometric authentication'),
      subtitle: _available
          ? null
          : const Text('Not available on this device'),
      trailing: Switch(
        value: _enabled && _available,
        onChanged: _available
            ? (val) async {
                final authService = ref.read(authServiceProvider);
                await authService.setBiometricEnabled(val);
                setState(() => _enabled = val);
              }
            : null,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

