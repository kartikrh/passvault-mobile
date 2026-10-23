import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../domain/account_models.dart';
import 'account_widgets.dart';

/// Recent account activity (sign-ins, vault changes, password views) with
/// IP and location -- passvault-client's /activity page, paged as you scroll.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  static const _pageSize = 25;
  final _items = <ActivityItem>[];
  final _scroll = ScrollController();
  int _page = 0;
  int _totalPages = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    Future.microtask(_refresh);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _items.clear();
    _page = 0;
    _totalPages = 1;
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _totalPages) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(accountRepositoryProvider).fetchActivity(page: _page + 1, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _items.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            if (i == _items.length) {
              if (_error != null) return Padding(padding: const EdgeInsets.all(16), child: ErrorText(_error));
              if (_loading) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              if (_items.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No activity yet.')));
              return const SizedBox(height: 24);
            }
            return _ActivityTile(item: _items[i]);
          },
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final date = item.createdDate;
    final when = '${localizations.formatMediumDate(date)}, '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
    final details = item.details;
    final hasLocation = item.latitude != null && item.longitude != null;
    return ListTile(
      leading: Icon(_iconFor(item.activityType)),
      title: Text(details == null || details.isEmpty ? item.label : '${item.label} · $details'),
      subtitle: Text([when, if (item.ipAddress != null) 'IP ${item.ipAddress}'].join('\n')),
      isThreeLine: item.ipAddress != null,
      trailing: hasLocation
          ? IconButton(
              tooltip: 'Show location',
              icon: const Icon(Icons.place_outlined),
              onPressed: () => launchUrl(
                Uri.parse('https://www.google.com/maps?q=${item.latitude},${item.longitude}'),
                mode: LaunchMode.externalApplication,
              ),
            )
          : null,
    );
  }

  IconData _iconFor(int type) {
    if (type == ActivityType.accountPasswordViewed) return Icons.visibility_outlined;
    if (type == ActivityType.pageViewed) return Icons.article_outlined;
    if (ActivityType.entryTypes.contains(type)) return Icons.key_outlined;
    if (type >= 180 && type < 190) return Icons.warning_amber_outlined; // failed login / locked
    if (type == 102) return Icons.login;
    return Icons.history;
  }
}
