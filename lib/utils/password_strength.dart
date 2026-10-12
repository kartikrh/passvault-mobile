// Mirrors passvault-client's src/utils/passwordStrength.js exactly --
// dependency-free length + character-class check. Advisory/UX only;
// PassVaultapi only ever enforces an 8-char minimum server-side.
enum PasswordStrength { tooShort, weak, medium, strong }

const _classPatterns = [r'[a-z]', r'[A-Z]', r'[0-9]', r'[^a-zA-Z0-9]'];

String passwordStrengthLabel(PasswordStrength strength) => switch (strength) {
      PasswordStrength.tooShort => 'Too short',
      PasswordStrength.weak => 'Weak',
      PasswordStrength.medium => 'Medium',
      PasswordStrength.strong => 'Strong',
    };

PasswordStrength getPasswordStrength(String password) {
  if (password.length < 8) return PasswordStrength.tooShort;

  final classCount = _classPatterns.where((pattern) => RegExp(pattern).hasMatch(password)).length;
  final isLong = password.length >= 12;

  if (classCount >= 3 && isLong) return PasswordStrength.strong;
  if (classCount >= 3 || (classCount >= 2 && isLong)) return PasswordStrength.medium;
  return PasswordStrength.weak;
}
