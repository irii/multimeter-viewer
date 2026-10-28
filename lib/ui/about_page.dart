import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../about/app_info.dart';
import '../l10n/l10n.dart';
import '../router.dart';
import 'widgets/window_app_bar.dart';

/// Developer, license, credits and legal notices.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.linkCouldNotOpen(url);
    if (!await launchUrl(Uri.parse(url))) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    const title = AppInfo.name;
    final repository = AppInfo.repository.replaceFirst('https://', '');

    return Scaffold(
      appBar: WindowAppBar(appBar: AppBar(title: Text(l10n.about))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Image.asset(
                'assets/icon/app_icon.png',
                width: 96,
                height: 96,
                semanticLabel: title,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                '${l10n.version} ${AppInfo.version}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.aboutDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(l10n.developer),
                      subtitle: const Text(AppInfo.developer),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: Text(l10n.sourceCode),
                      subtitle: Text(repository),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _open(context, AppInfo.repository),
                    ),
                    ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: Text(l10n.license),
                      subtitle: const Text(
                        '${AppInfo.license} · ${AppInfo.copyright}',
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _open(
                        context,
                        '${AppInfo.repository}/blob/main/LICENSE',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(l10n.openSourceLicenses),
                      subtitle: Text(l10n.openSourceLicensesHint),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(Routes.licenses),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final notice in [l10n.disclaimer, l10n.trademarkNotice]) ...[
                Text(
                  notice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
