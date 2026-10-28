import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'widgets/window_app_bar.dart';

/// Licenses of all packages in the app, grouped by package. Replaces
/// Flutter's license page so the app bars act as title bar like everywhere
/// else (see [WindowAppBar]).
class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  late final Future<Map<String, List<LicenseEntry>>> _licenses = _load();

  static Future<Map<String, List<LicenseEntry>>> _load() async {
    final byPackage = SplayTreeMap<String, List<LicenseEntry>>(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        (byPackage[package] ??= []).add(entry);
      }
    }
    return byPackage;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: WindowAppBar(
        appBar: AppBar(title: Text(l10n.openSourceLicenses)),
      ),
      body: FutureBuilder(
        future: _licenses,
        builder: (context, snapshot) {
          final licenses = snapshot.data;
          if (licenses == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _Centered(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final MapEntry(key: package, value: entries)
                    in licenses.entries)
                  ListTile(
                    title: Text(package),
                    subtitle: Text(l10n.licenseCount(entries.length)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _LicenseDetailPage(
                          package: package,
                          entries: entries,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LicenseDetailPage extends StatelessWidget {
  const _LicenseDetailPage({required this.package, required this.entries});

  final String package;
  final List<LicenseEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: WindowAppBar(appBar: AppBar(title: Text(package))),
      body: _Centered(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (i, entry) in entries.indexed) ...[
              if (i > 0) const Divider(height: 32),
              for (final paragraph in entry.paragraphs)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: 8,
                    left: paragraph.indent == LicenseParagraph.centeredIndent
                        ? 0
                        : paragraph.indent * 16.0,
                  ),
                  child: SelectableText(
                    paragraph.text,
                    textAlign:
                        paragraph.indent == LicenseParagraph.centeredIndent
                        ? TextAlign.center
                        : TextAlign.start,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Keeps long lines readable on wide windows.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: child,
    ),
  );
}
