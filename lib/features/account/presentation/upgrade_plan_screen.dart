import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../domain/account_models.dart';
import 'account_widgets.dart';

/// Upgrade Plan -- pick a plan, pay by QR/UPI/bank transfer outside the app,
/// then submit the transfer reference for admin approval. Same flow as
/// passvault-client's UpgradePlanModal (services/vaultPlanUpgrade.js).
class UpgradePlanScreen extends ConsumerStatefulWidget {
  const UpgradePlanScreen({super.key});

  @override
  ConsumerState<UpgradePlanScreen> createState() => _UpgradePlanScreenState();
}

class _UpgradePlanScreenState extends ConsumerState<UpgradePlanScreen> {
  final _transferCode = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  ClientPackage? _current;
  UpgradeRequest? _request;
  List<Plan> _plans = [];
  Plan? _selected;
  PaymentMethod? _paymentMethod;
  String? _paymentError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _transferCode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = ref.read(accountRepositoryProvider);
      final plans = ref.read(planRepositoryProvider);
      final results = await Future.wait([account.fetchPackage(), plans.fetchMyRequest(), plans.fetchPlans()]);
      if (!mounted) return;
      setState(() {
        _current = results[0] as ClientPackage?;
        _request = results[1] as UpgradeRequest?;
        _plans = results[2] as List<Plan>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(Plan plan) async {
    setState(() {
      _selected = plan;
      _paymentError = null;
    });
    if (_paymentMethod != null) return;
    try {
      final method = await ref.read(planRepositoryProvider).fetchPaymentMethod();
      if (mounted) setState(() => _paymentMethod = method);
    } catch (e) {
      if (mounted) setState(() => _paymentError = ApiClient.toApiException(e).message);
    }
  }

  Future<void> _submit() async {
    final plan = _selected;
    final code = _transferCode.text.trim();
    if (plan == null || code.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(planRepositoryProvider).submitUpgrade(packageId: plan.id, transferCode: code);
      _transferCode.clear();
      _selected = null;
      ref.invalidate(clientPackageProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent -- we\'ll upgrade your plan once the payment is verified.')),
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _request?.isPending == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade plan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ErrorText(_error)),
                  if (_current != null)
                    SectionCard(
                      title: 'Current plan',
                      children: [
                        Text(_current!.name, style: Theme.of(context).textTheme.titleLarge),
                        if (_current!.expiryDate != null)
                          Text(_current!.isExpired
                              ? 'Expired'
                              : 'Valid for ${_current!.daysRemaining ?? 0} more day${_current!.daysRemaining == 1 ? '' : 's'}'),
                      ],
                    ),
                  if (_request != null) _RequestBanner(request: _request!),
                  if (!pending) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text('Choose a plan', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    ..._plans.where((p) => p.id != _current?.packageId).map(
                          (plan) => _PlanTile(plan: plan, selected: _selected?.id == plan.id, onTap: () => _select(plan)),
                        ),
                    if (_plans.where((p) => p.id != _current?.packageId).isEmpty)
                      const Padding(padding: EdgeInsets.all(16), child: Text('No other plans are available right now.')),
                    if (_selected != null) _paymentSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _paymentSection() {
    final method = _paymentMethod;
    final plan = _selected!;
    return SectionCard(
      title: 'Pay for ${plan.name}',
      subtitle: 'Amount: ${formatPrice(plan.price, plan.currency, plan.intervalType, plan.intervalCount)}',
      children: [
        if (_paymentError != null) ErrorText(_paymentError),
        if (method == null && _paymentError == null) const Center(child: CircularProgressIndicator()),
        if (method != null) ...[
          if (method.qrImageUrl != null) ...[
            Center(
              child: Image.network(
                method.qrImageUrl!,
                height: 220,
                errorBuilder: (_, _, _) => const Text('QR code could not be loaded.'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (method.upiId != null) _CopyRow(label: 'UPI ID', value: method.upiId!),
          if (method.bankName != null) _CopyRow(label: 'Bank', value: method.bankName!),
          if (method.accountHolderName != null) _CopyRow(label: 'Account holder', value: method.accountHolderName!),
          if (method.accountNumber != null) _CopyRow(label: 'Account number', value: method.accountNumber!),
          if (method.ifscCode != null) _CopyRow(label: 'IFSC', value: method.ifscCode!),
          if (method.branch != null) _CopyRow(label: 'Branch', value: method.branch!),
          if ((method.instructions ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            HtmlWidget(method.instructions!),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _transferCode,
            decoration: const InputDecoration(
              labelText: 'Transaction / reference ID',
              helperText: 'The UPI or bank transaction ID from your payment',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting || _transferCode.text.trim().isEmpty ? null : _submit,
            child: _submitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit for approval'),
          ),
        ],
      ],
    );
  }
}

class _RequestBanner extends StatelessWidget {
  const _RequestBanner({required this.request});
  final UpgradeRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (Color bg, IconData icon, String text) = switch (request.status) {
      'PENDING' => (
          colors.secondaryContainer,
          Icons.hourglass_top,
          'Your request to upgrade to ${request.requestedPackageName ?? 'a new plan'} is waiting for approval.',
        ),
      'REJECTED' => (
          colors.errorContainer,
          Icons.cancel_outlined,
          'Your last upgrade request was rejected${request.rejectionReason != null ? ': ${request.rejectionReason}' : '.'} '
              'You can submit a new one.',
        ),
      _ => (
          colors.primaryContainer,
          Icons.check_circle_outline,
          'Your upgrade to ${request.requestedPackageName ?? 'the new plan'} was approved.',
        ),
    };
    return Card(
      color: bg,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(leading: Icon(icon), title: Text(text)),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.selected, required this.onTap});
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final limits = [
      if (plan.maxAccounts != null) '${plan.maxAccounts} accounts',
      if (plan.maxNotes != null) '${plan.maxNotes} notes',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
        title: Text(plan.name),
        subtitle: Text([
          formatPrice(plan.price, plan.currency, plan.intervalType, plan.intervalCount),
          if (limits.isNotEmpty) limits,
          if ((plan.description ?? '').isNotEmpty) plan.description!,
        ].join('\n')),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      trailing: IconButton(
        tooltip: 'Copy',
        icon: const Icon(Icons.copy, size: 18),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied')));
        },
      ),
    );
  }
}
