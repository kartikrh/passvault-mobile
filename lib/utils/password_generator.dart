// No equivalent exists in passvault-client (its PasswordInput.js is a plain
// masked field, no generate action) -- this is new, mobile-only UX. Uses
// Random.secure() (CSPRNG), not the default Random, since this produces
// actual account credentials.
import 'dart:math';

const _lowercase = 'abcdefghijklmnopqrstuvwxyz';
const _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _digits = '0123456789';
const _symbols = r'!@#$%^&*()-_=+[]{}';

class PasswordGeneratorOptions {
  final int length;
  final bool useUppercase;
  final bool useLowercase;
  final bool useDigits;
  final bool useSymbols;

  const PasswordGeneratorOptions({
    this.length = 16,
    this.useUppercase = true,
    this.useLowercase = true,
    this.useDigits = true,
    this.useSymbols = true,
  });

  PasswordGeneratorOptions copyWith({
    int? length,
    bool? useUppercase,
    bool? useLowercase,
    bool? useDigits,
    bool? useSymbols,
  }) =>
      PasswordGeneratorOptions(
        length: length ?? this.length,
        useUppercase: useUppercase ?? this.useUppercase,
        useLowercase: useLowercase ?? this.useLowercase,
        useDigits: useDigits ?? this.useDigits,
        useSymbols: useSymbols ?? this.useSymbols,
      );
}

/// Throws if every character class is disabled.
String generatePassword(PasswordGeneratorOptions options) {
  final pools = <String>[
    if (options.useLowercase) _lowercase,
    if (options.useUppercase) _uppercase,
    if (options.useDigits) _digits,
    if (options.useSymbols) _symbols,
  ];
  if (pools.isEmpty) {
    throw ArgumentError('At least one character set must be enabled.');
  }

  final random = Random.secure();
  final allChars = pools.join();

  // Guarantee at least one character from each selected pool, then fill the
  // rest randomly and shuffle -- avoids the common generator bug where a
  // long password can, by chance, contain zero digits/symbols even with
  // those pools enabled.
  final chars = <String>[
    for (final pool in pools) pool[random.nextInt(pool.length)],
  ];
  while (chars.length < options.length) {
    chars.add(allChars[random.nextInt(allChars.length)]);
  }
  chars.shuffle(random);
  return chars.take(options.length).join();
}
