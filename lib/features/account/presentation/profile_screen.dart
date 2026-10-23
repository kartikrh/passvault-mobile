import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/client.dart';
import 'account_widgets.dart';

/// Name, username (settable once), mobile number and address -- the mobile
/// counterpart of passvault-client's ProfileForm/ContactInfoForm.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  Client? _client;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _mobile, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final client = await ref.read(accountRepositoryProvider).fetchFullProfile();
      if (!mounted) return;
      setState(() {
        _client = client;
        _name.text = client.name ?? '';
        _username.text = client.username ?? '';
        _mobile.text = client.mobileNo ?? '';
        _address.text = client.address ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final client = _client!;
    final usernameLocked = (client.username ?? '').isNotEmpty;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ref.read(accountRepositoryProvider).updateProfile(
            name: _name.text.trim(),
            username: usernameLocked ? null : _username.text.trim(),
            mobileNo: _mobile.text.trim(),
            address: _address.text.trim(),
          );
      await ref.read(sessionControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      setState(() => _client = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      setState(() => _error = ApiClient.toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final usernameLocked = (client?.username ?? '').isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : client == null
              ? Padding(padding: const EdgeInsets.all(24), child: ErrorText(_error ?? 'Could not load your profile.'))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        initialValue: client.email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _username,
                        enabled: !usernameLocked,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          helperText: usernameLocked ? 'A username can\'t be changed once set.' : 'Can only be set once.',
                        ),
                        validator: (v) => usernameLocked ? null : validateUsername(v),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _mobile,
                        decoration: const InputDecoration(labelText: 'Mobile number'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(labelText: 'Address'),
                        maxLines: 3,
                        maxLength: 500,
                      ),
                      const SizedBox(height: 8),
                      ErrorText(_error),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// Same rule as PassVaultapi's validateUsername: 3-30 chars, letters,
/// digits, "_" and ".".
String? validateUsername(String? value) {
  final v = value?.trim() ?? '';
  if (v.length < 3 || v.length > 30) return '3 to 30 characters';
  if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(v)) return 'Letters, numbers, "_" and "." only';
  return null;
}

/// PassVaultapi's MIN_PASSWORD_LENGTH.
String? validateAccountPassword(String? value) =>
    (value == null || value.length < 8) ? 'At least 8 characters' : null;
