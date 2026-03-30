#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my_flutter_app" "$@"
create_project_dir

# Flutter uses underscores in project names
FLUTTER_NAME="${PROJECT_NAME//-/_}"

# --- pubspec.yaml ---
write_file "pubspec.yaml" "name: ${FLUTTER_NAME}
description: A Flutter application with Material 3 and Riverpod.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.6.0 <4.0.0'
  flutter: '>=3.27.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.0
  riverpod_annotation: ^2.6.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  riverpod_generator: ^2.6.0
  build_runner: ^2.4.0
  custom_lint:

flutter:
  uses-material-design: true"

# --- analysis_options.yaml ---
write_file "analysis_options.yaml" 'include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    prefer_single_quotes: true
    sort_child_properties_last: true
    use_build_context_synchronously: true

analyzer:
  errors:
    invalid_annotation_target: ignore
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"'

# --- lib/main.dart ---
write_file "lib/main.dart" "import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}"

# --- lib/app.dart ---
write_file "lib/app.dart" "import 'package:flutter/material.dart';
import 'features/home/presentation/home_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${FLUTTER_NAME}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}"

# --- lib/core/constants/app_constants.dart ---
write_file "lib/core/constants/app_constants.dart" "class AppConstants {
  AppConstants._();

  static const String appName = '${FLUTTER_NAME}';
  static const String appVersion = '1.0.0';
}"

# --- lib/core/theme/app_theme.dart ---
write_file "lib/core/theme/app_theme.dart" "import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      colorSchemeSeed: Colors.blue,
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorSchemeSeed: Colors.blue,
      useMaterial3: true,
      brightness: Brightness.dark,
    );
  }
}"

# --- lib/core/utils/extensions.dart ---
write_file "lib/core/utils/extensions.dart" "import 'package:flutter/material.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
}"

# --- lib/features/home/data/counter_repository.dart ---
write_file "lib/features/home/data/counter_repository.dart" "class CounterRepository {
  int _count = 0;

  int get count => _count;

  int increment() {
    _count++;
    return _count;
  }

  int decrement() {
    if (_count > 0) _count--;
    return _count;
  }

  void reset() {
    _count = 0;
  }
}"

# --- lib/features/home/providers/counter_provider.dart ---
write_file "lib/features/home/providers/counter_provider.dart" "import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/counter_repository.dart';

final counterRepositoryProvider = Provider<CounterRepository>((ref) {
  return CounterRepository();
});

final counterProvider = StateNotifierProvider<CounterNotifier, int>((ref) {
  final repository = ref.watch(counterRepositoryProvider);
  return CounterNotifier(repository);
});

class CounterNotifier extends StateNotifier<int> {
  final CounterRepository _repository;

  CounterNotifier(this._repository) : super(0);

  void increment() {
    state = _repository.increment();
  }

  void decrement() {
    state = _repository.decrement();
  }

  void reset() {
    _repository.reset();
    state = 0;
  }
}"

# --- lib/features/home/presentation/home_screen.dart ---
write_file "lib/features/home/presentation/home_screen.dart" "import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/counter_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '\$count',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => ref.read(counterProvider.notifier).decrement(),
                  icon: const Icon(Icons.remove),
                  label: const Text('Decrease'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => ref.read(counterProvider.notifier).increment(),
                  icon: const Icon(Icons.add),
                  label: const Text('Increase'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(counterProvider.notifier).reset(),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}"

# --- test/widget_test.dart ---
write_file "test/widget_test.dart" "import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:${FLUTTER_NAME}/app.dart';

void main() {
  testWidgets('Counter increments', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.text('Increase'));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });
}"

init_git
write_gitignore "*.iml" ".dart_tool/" ".packages" "build/" ".flutter-plugins" ".flutter-plugins-dependencies" ".metadata" "*.lock"
write_editorconfig

finish "flutter pub get" "flutter run"
