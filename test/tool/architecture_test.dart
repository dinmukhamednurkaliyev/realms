import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'accepts module APIs, direct internal imports, and shared strings',
    () async {
      final result = await _checkArchitecture({});

      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('Architecture checks passed'));
    },
  );

  test('does not mistake runtime casts for import aliases', () async {
    final result = await _checkArchitecture({
      'lib/game/engine/board.dart':
          'class GameBoard {}\n'
          'GameBoard requireBoard(Object value) => value as GameBoard;\n',
    });

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  test('handles strings in conditional import expressions', () async {
    final result = await _checkArchitecture({
      'lib/game/engine/state.dart':
          "import 'board.dart' if (dart.library.io == 'true') 'board.dart';\n",
    });

    expect(result.exitCode, 0, reason: '${result.stderr}');
  });

  const rejectedDependencies = [
    (
      name: 'import aliases',
      path: 'lib/main.dart',
      source: "import 'package:realms/app/app.dart' as app;\n",
      message: 'unprefixed imports',
    ),
    (
      name: 'a barrel outside the module entry point',
      path: 'lib/game/extra.dart',
      source: "export 'engine/board.dart' show GameBoard;\n",
      message: 'Only module entry points may export',
    ),
    (
      name: 'internal imports of the owning module entry point',
      path: 'lib/game/engine/state.dart',
      source: "import 'engine.dart';\n",
      message: 'must not import their own module entry point',
    ),
    (
      name: 'package imports within one module',
      path: 'lib/game/engine/state.dart',
      source: "import 'package:realms/game/engine/board.dart';\n",
      message: 'Use relative imports',
    ),
    (
      name: 'Home depending on engine internals',
      path: 'lib/home/home.dart',
      source: "import '../game/engine/board.dart';\n",
      message: 'Forbidden dependency',
    ),
    (
      name: 'engine depending on a concrete mode',
      path: 'lib/game/engine/state.dart',
      source: "import 'package:realms/game/modes/modes.dart';\n",
      message: 'Forbidden dependency',
    ),
    (
      name: 'modes depending on presentation',
      path: 'lib/game/modes/campaign.dart',
      source: "import 'package:realms/game/game.dart';\n",
      message: 'Forbidden dependency',
    ),
    (
      name: 'Flutter package imports in the engine',
      path: 'lib/game/engine/state.dart',
      source: "import 'package:flutter/widgets.dart';\n",
      message: 'may only import Dart and game internals',
    ),
    (
      name: 'Flutter SDK imports in the engine',
      path: 'lib/game/engine/state.dart',
      source: "import 'dart:ui_web';\n",
      message: 'must not depend on Flutter',
    ),
    (
      name: 'forbidden conditional dependencies',
      path: 'lib/game/engine/state.dart',
      source:
          "import 'board.dart' if (dart.library.io == 'true') "
          "'package:realms/game/game.dart';\n",
      message: 'Forbidden dependency',
    ),
    (
      name: 'missing imports',
      path: 'lib/game/engine/state.dart',
      source: "import 'missing.dart';\n",
      message: 'Missing dependency',
    ),
    (
      name: 'dependency cycles',
      path: 'lib/game/engine/board.dart',
      source: "import 'state.dart';\n",
      message: 'Dependency cycle',
    ),
    (
      name: 'nonselective exports',
      path: 'lib/game/engine/engine.dart',
      source: "export 'board.dart';\n",
      message: 'explicit show list',
    ),
    (
      name: 'duplicate exported symbols',
      path: 'lib/game/engine/engine.dart',
      source:
          "export 'board.dart' show GameBoard;\n"
          "export 'state.dart' show GameBoard;\n",
      message: 'Duplicate public export',
    ),
    (
      name: 'top-level consumers bypassing a module API',
      path: 'lib/main.dart',
      source: "import 'package:realms/game/engine/board.dart';\n",
      message:
          'Consume game/engine through '
          'package:realms/game/engine/engine.dart',
    ),
    (
      name: 'a global barrel',
      path: 'lib/realms.dart',
      source: "export 'app/app.dart' show RealmsApp;\n",
      message: 'not a global realms.dart barrel',
    ),
    (
      name: 'Game importing Engine implementation files',
      path: 'lib/game/screens/play.dart',
      source: "import 'package:realms/game/engine/state.dart';\n",
      message: 'Consume game/engine through',
    ),
    (
      name: 'relative imports across module boundaries',
      path: 'lib/game/screens/play.dart',
      source: "import '../engine/engine.dart';\n",
      message: 'Consume game/engine through',
    ),
    (
      name: 'Game re-exporting the Engine API',
      path: 'lib/game/game.dart',
      source: "export 'engine/engine.dart' show GameBoard;\n",
      message: 'Only declarations owned by this module may be exported',
    ),
    (
      name: 'App bypassing the Appearance API',
      path: 'lib/app/app.dart',
      source: "import 'package:realms/app/appearance/theme.dart';\n",
      message: 'Consume app/appearance through',
    ),
    (
      name: 'Appearance depending on App composition',
      path: 'lib/app/appearance/theme.dart',
      source: "import 'package:realms/app/app.dart';\n",
      message: 'Forbidden dependency: app',
    ),
    (
      name: 'Home importing a generated locale implementation',
      path: 'lib/home/home.dart',
      source:
          "import 'package:realms/app/localization/localization_en.dart';\n",
      message: 'Consume app/localization through',
    ),
    (
      name: 'tests importing implementation from another module',
      path: 'test/game/modes/campaign_test.dart',
      source: "import 'package:realms/game/engine/state.dart';\n",
      message: 'Tests access other modules through their public entry points',
    ),
  ];

  for (final testCase in rejectedDependencies) {
    test('rejects ${testCase.name}', () async {
      final result = await _checkArchitecture({testCase.path: testCase.source});

      expect(result.exitCode, 1);
      expect(result.stderr, contains(testCase.message));
    });
  }

  test('rejects overlapping public names across module APIs', () async {
    final result = await _checkArchitecture({
      'lib/game/game.dart': "export 'screens/play.dart' show GameBoard;\n",
      'lib/game/screens/play.dart': 'class GameBoard {}\n',
    });

    expect(result.exitCode, 1);
    expect(
      result.stderr,
      contains('GameBoard already belongs to the public API'),
    );
  });
}

Future<ProcessResult> _checkArchitecture(Map<String, String> overrides) {
  final checker = File('tool/check_architecture.dart').absolute.path;
  final fixture = Directory.systemTemp.createTempSync('realms-architecture-');
  addTearDown(() => fixture.deleteSync(recursive: true));

  final sources = {
    'pubspec.yaml': 'name: realms\n',
    'lib/main.dart': "import 'package:realms/app/app.dart';\n",
    'lib/app/app.dart':
        "import 'package:realms/app/appearance/appearance.dart';\n"
        "import 'package:realms/app/localization/localization.dart';\n"
        "import 'package:realms/home/home.dart';\n"
        "import 'package:realms/game/game.dart';\n",
    'lib/app/appearance/appearance.dart':
        "export 'theme.dart' show lightTheme;\n",
    'lib/app/appearance/theme.dart': 'const lightTheme = 0;\n',
    'lib/app/localization/localization.dart': 'class Strings {}\n',
    'lib/app/localization/localization_en.dart': 'class StringsEn {}\n',
    'lib/home/home.dart':
        "import 'package:realms/app/localization/localization.dart';\n",
    'lib/game/game.dart': "export 'screens/play.dart' show PlayScreen;\n",
    'lib/game/engine/engine.dart':
        "export 'board.dart' show GameBoard;\n"
        "export 'state.dart' show GameState;\n",
    'lib/game/engine/board.dart': 'class GameBoard {}\n',
    'lib/game/engine/state.dart': "import 'board.dart';\n",
    'lib/game/modes/modes.dart': "export 'campaign.dart' show CampaignLevel;\n",
    'lib/game/modes/campaign.dart':
        "import 'package:realms/game/engine/engine.dart';\n",
    'lib/game/screens/play.dart':
        "import 'package:realms/game/engine/engine.dart';\n"
        "import 'package:realms/app/localization/localization.dart';\n",
    'test/game/engine/board_test.dart':
        "import 'package:test/test.dart';\n"
        "import 'package:realms/game/engine/engine.dart';\n"
        "import 'package:realms/game/engine/state.dart';\n",
    ...overrides,
  };
  for (final MapEntry(key: path, value: contents) in sources.entries) {
    File.fromUri(fixture.uri.resolve(path))
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);
  }

  return Process.run('dart', [checker], workingDirectory: fixture.path);
}
