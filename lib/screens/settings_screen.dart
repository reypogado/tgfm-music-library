import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pwa_install.dart';
import '../core/settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                for (final mode in ThemeMode.values)
                  ButtonSegment(
                    value: mode,
                    icon: Icon(themeModeIcons[mode]),
                    label: Text(
                      mode == ThemeMode.system
                          ? 'System'
                          : themeModeLabels[mode]!,
                    ),
                  ),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            const _SectionHeader('Install app'),
            const _InstallSection(),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Offers the browser's install dialog when it has one, and otherwise
/// explains how to add the app by hand on the current browser.
class _InstallSection extends StatefulWidget {
  const _InstallSection();

  @override
  State<_InstallSection> createState() => _InstallSectionState();
}

class _InstallSectionState extends State<_InstallSection> {
  late PwaStatus _status = pwaStatus();
  late final VoidCallback _unsubscribe;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    _unsubscribe = subscribePwaStatus(() {
      if (mounted) setState(() => _status = pwaStatus());
    });
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  Future<void> _install() async {
    setState(() => _prompting = true);
    final outcome = await promptPwaInstall();
    if (!mounted) return;
    setState(() {
      _prompting = false;
      _status = pwaStatus();
    });
    if (outcome == PwaInstallOutcome.dismissed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not installed. You can still follow the steps below.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;

    if (!s.supported) {
      return const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Install is not available in this browser.'),
      );
    }

    if (s.standalone) {
      return const ListTile(
        leading: Icon(Icons.check_circle_outline),
        title: Text('Installed'),
        subtitle: Text('You are using the installed app.'),
      );
    }

    if (s.installedHere) {
      return const ListTile(
        leading: Icon(Icons.check_circle_outline),
        title: Text('Installed'),
        subtitle: Text(
          'Open TGFM from your home screen or app list. '
          'You can close this browser tab.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListTile(
          leading: Icon(Icons.install_mobile),
          title: Text('Add TGFM to your device'),
          subtitle: Text(
            'Opens full screen from its own icon and keeps working offline '
            'at rehearsals and services.',
          ),
        ),
        if (s.canPrompt)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: FilledButton.icon(
              onPressed: _prompting ? null : _install,
              icon: const Icon(Icons.download),
              label: const Text('Install app'),
            ),
          ),
        _InstallSteps(platform: s.platform, hasButton: s.canPrompt),
      ],
    );
  }
}

class _InstallSteps extends StatelessWidget {
  const _InstallSteps({required this.platform, required this.hasButton});

  final PwaPlatform platform;
  final bool hasButton;

  (String, List<String>) get _steps => switch (platform) {
    PwaPlatform.ios => (
      'On iPhone or iPad',
      [
        'Open this page in Safari.',
        'Tap the Share button (the square with an arrow pointing up).',
        'Scroll down and tap "Add to Home Screen".',
        'Tap "Add".',
      ],
    ),
    PwaPlatform.android => (
      'On Android',
      [
        'Open this page in Chrome.',
        'Tap the three-dot menu at the top right.',
        'Tap "Install app" or "Add to Home screen".',
        'Tap "Install" to confirm.',
      ],
    ),
    PwaPlatform.macSafari => (
      'In Safari on Mac',
      ['Choose File > Add to Dock (macOS Sonoma or later).', 'Click "Add".'],
    ),
    PwaPlatform.firefoxDesktop => (
      'In Firefox',
      [
        'Firefox on a computer cannot install web apps.',
        'Open this page in Chrome or Edge, then click the install icon '
            'at the right end of the address bar.',
      ],
    ),
    PwaPlatform.desktop => (
      'In Chrome or Edge',
      [
        'Click the install icon at the right end of the address bar.',
        'Or open the browser menu and choose "Install TGFM Music '
            'Library" (Chrome: under "Cast, save, and share"; '
            'Edge: under "Apps").',
        'Click "Install".',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (heading, steps) = _steps;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasButton ? 'Or install by hand: $heading' : heading,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${i + 1}.', style: theme.textTheme.bodyMedium),
                  ),
                  Expanded(
                    child: Text(step, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
