import 'package:flutter/material.dart';

/// Placeholder brand color -- passvault-client's actual palette comes from
/// White Label config (logo/favicon per domain, see WhitelabelConfig), so
/// there's no single fixed brand to hardcode here yet.
const _seedColor = Color(0xFF2F6FED);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}
