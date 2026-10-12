import 'package:flutter/material.dart';

import '../domain/account.dart';
import 'password_generator_sheet.dart';
import 'password_strength_meter.dart';
import 'tags_editor.dart';

/// Add/edit form for an Account -- fields match passvault-client's
/// AddAccountForm.js exactly (title, username, password, url,
/// securityQuestions, tags). Pass [initial] to edit; omit to add.
/// Pops with the resulting [Account] (keeping [initial]'s id), or null if
/// cancelled.
class AccountFormScreen extends StatefulWidget {
  const AccountFormScreen({super.key, this.initial});

  final Account? initial;

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.initial?.title ?? '');
  late final _usernameController = TextEditingController(text: widget.initial?.username ?? '');
  late final _passwordController = TextEditingController(text: widget.initial?.password ?? '');
  late final _urlController = TextEditingController(text: widget.initial?.url ?? '');
  late List<SecurityQuestion> _securityQuestions = List.of(widget.initial?.securityQuestions ?? []);
  late List<String> _tags = List.of(widget.initial?.tags ?? []);
  bool _obscurePassword = true;

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _generatePassword() async {
    final generated = await showPasswordGeneratorSheet(context);
    if (generated != null) {
      setState(() => _passwordController.text = generated);
    }
  }

  void _addSecurityQuestion() {
    setState(() => _securityQuestions = [..._securityQuestions, const SecurityQuestion(question: '', answer: '')]);
  }

  void _removeSecurityQuestion(int index) {
    setState(() => _securityQuestions = [..._securityQuestions]..removeAt(index));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    // Mirrors AddAccountForm.js: drop any security-question row where
    // either field is empty rather than blocking submit on it.
    final questions = _securityQuestions.where((q) => q.question.trim().isNotEmpty && q.answer.trim().isNotEmpty).toList();
    Navigator.of(context).pop(
      Account(
        id: widget.initial?.id,
        title: _titleController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        url: _urlController.text.trim(),
        securityQuestions: questions,
        tags: _tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit account' : 'Add account'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.casino_outlined),
                      tooltip: 'Generate',
                      onPressed: _generatePassword,
                    ),
                    IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ],
                ),
              ),
              obscureText: _obscurePassword,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              onChanged: (_) => setState(() {}),
            ),
            PasswordStrengthMeter(password: _passwordController.text),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Security questions', style: Theme.of(context).textTheme.titleSmall),
                IconButton(icon: const Icon(Icons.add), onPressed: _addSecurityQuestion),
              ],
            ),
            for (var i = 0; i < _securityQuestions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          TextFormField(
                            initialValue: _securityQuestions[i].question,
                            decoration: const InputDecoration(labelText: 'Question'),
                            onChanged: (v) => setState(() {
                              _securityQuestions[i] = SecurityQuestion(question: v, answer: _securityQuestions[i].answer);
                            }),
                          ),
                          TextFormField(
                            initialValue: _securityQuestions[i].answer,
                            decoration: const InputDecoration(labelText: 'Answer'),
                            onChanged: (v) => setState(() {
                              _securityQuestions[i] = SecurityQuestion(question: _securityQuestions[i].question, answer: v);
                            }),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _removeSecurityQuestion(i)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TagsEditor(tags: _tags, onChanged: (t) => setState(() => _tags = t)),
          ],
        ),
      ),
    );
  }
}
