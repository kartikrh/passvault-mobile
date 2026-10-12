import 'vault_entry.dart';

class SecurityQuestion {
  final String question;
  final String answer;
  const SecurityQuestion({required this.question, required this.answer});

  factory SecurityQuestion.fromJson(Map<String, dynamic> json) =>
      SecurityQuestion(question: json['question'] as String, answer: json['answer'] as String);

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};
}

/// Account fields, matching passvault-client's AddAccountForm.js exactly:
/// { title, username, password, url, securityQuestions, tags }.
class Account {
  final String? id; // null for a not-yet-saved account
  final String title;
  final String username;
  final String password;
  final String url;
  final List<SecurityQuestion> securityQuestions;
  final List<String> tags;

  const Account({
    this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url = '',
    this.securityQuestions = const [],
    this.tags = const [],
  });

  factory Account.fromEntry(VaultEntry entry) {
    final questions = (entry.fields['securityQuestions'] as List<dynamic>? ?? [])
        .map((q) => SecurityQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
    final tags = (entry.fields['tags'] as List<dynamic>? ?? []).cast<String>();
    return Account(
      id: entry.id,
      title: entry.fields['title'] as String? ?? '',
      username: entry.fields['username'] as String? ?? '',
      password: entry.fields['password'] as String? ?? '',
      url: entry.fields['url'] as String? ?? '',
      securityQuestions: questions,
      tags: tags,
    );
  }

  VaultEntry toEntry({required String id}) => VaultEntry(
        id: id,
        type: VaultEntryType.account,
        fields: {
          'title': title,
          'username': username,
          'password': password,
          'url': url,
          'securityQuestions': securityQuestions.map((q) => q.toJson()).toList(),
          'tags': tags,
        },
      );
}
