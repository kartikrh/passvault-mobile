import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../domain/account_models.dart';
import 'account_widgets.dart';

/// Help & legal: the CMS pages managed in the panel (terms, privacy, FAQ ...),
/// same source as passvault-client's [...slug] pages. Reachable signed out too.
class PagesScreen extends ConsumerWidget {
  const PagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = ref.watch(cmsPagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & legal')),
      body: pages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: ErrorText(ApiClient.toApiException(e).message)),
        data: (all) {
          // Same filter as passvault-client's SiteNav: real content pages only
          // (not the home page or the login page's CMS entry).
          final list = all.where((p) => !p.isDefault && p.linkUrl != 'login' && (p.alias ?? '').isNotEmpty).toList();
          if (list.isEmpty) return const Center(child: Text('Nothing here yet.'));
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final page = list[i];
              final external = page.isLink && (page.linkUrl ?? '').startsWith('http');
              return ListTile(
                title: Text(page.title),
                trailing: Icon(external ? Icons.open_in_new : Icons.chevron_right),
                onTap: () {
                  if (external) {
                    launchUrl(Uri.parse(page.linkUrl!), mode: LaunchMode.externalApplication);
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CmsPageScreen(page: page)));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class CmsPageScreen extends StatelessWidget {
  const CmsPageScreen({super.key, required this.page});
  final CmsPage page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(page.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HtmlWidget(
          page.content ?? '',
          // Links inside page content open in the browser, never inside the app.
          onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      ),
    );
  }
}
