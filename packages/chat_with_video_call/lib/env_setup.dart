import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reads the Stream credentials from `env/env.json`, which is bundled with the
/// app as an asset. Returns an empty map when the file doesn't exist.
Future<Map<String, String>> loadEnv() async {
  final String json;
  try {
    json = await rootBundle.loadString('env/env.json');
  } on FlutterError {
    return const {};
  }

  final values = jsonDecode(json) as Map<String, dynamic>;
  return {for (final entry in values.entries) entry.key: '${entry.value}'};
}

/// Shown instead of the sample when `env/env.json` doesn't exist or is
/// missing some of the values the sample needs.
class MissingEnvApp extends StatelessWidget {
  const MissingEnvApp({super.key, required this.missingKeys});

  /// The names of the `env/env.json` entries that are missing or empty.
  final List<String> missingKeys;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final code = theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
          );

          return Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.key_off,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add your Stream credentials',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This sample reads its API key and user tokens from '
                      'env/env.json. These values are missing:',
                    ),
                    const SizedBox(height: 8),
                    for (final key in missingKeys)
                      SelectableText('• $key', style: code),
                    const SizedBox(height: 24),
                    Text(
                      '1. Create env/env.json',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'From the repository root, generate it with your API key '
                      'and secret from the Stream Dashboard:',
                    ),
                    const SizedBox(height: 4),
                    SelectableText('scripts/generate_env.sh', style: code),
                    const SizedBox(height: 4),
                    const Text(
                      'Or copy env/env.example.json in this sample to '
                      'env/env.json and fill in the values yourself.',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '2. Run the sample again',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Stop the app and run it again. The file is read when '
                      'the app starts.',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
