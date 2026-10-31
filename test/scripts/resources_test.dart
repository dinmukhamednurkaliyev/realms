import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../scripts/resources.dart';

void main() {
  late Directory project;
  final resourceOptions = File('scripts/resources.json').readAsStringSync();

  void write(String path, String contents) {
    File.fromUri(project.uri.resolve(path))
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);
  }

  void register(List<String> assets) {
    write(
      'pubspec.yaml',
      jsonEncode({
        'name': 'resource_fixture',
        'environment': {'sdk': '^3.13.7'},
        'flutter': {'assets': assets},
      }),
    );
  }

  void catalog(String locale, Map<String, Object?> messages) {
    write('assets/localization/$locale.json', jsonEncode(messages));
  }

  setUp(() {
    project = Directory.systemTemp.createTempSync('realms-resource-test-');
    register([]);
    write('scripts/resources.json', resourceOptions);
    catalog('en', {'startGame': 'Start game'});
    catalog('ru', {'startGame': 'Начать игру'});
  });

  tearDown(() => project.deleteSync(recursive: true));

  Matcher failsWith(String text) => throwsA(
    isA<FormatException>().having(
      (error) => error.message,
      'diagnostic',
      contains(text),
    ),
  );

  group('Resource configuration', () {
    void configure(
      String? section,
      void Function(Map<String, Object?>) change,
    ) {
      final configuration = jsonDecode(resourceOptions) as Map<String, Object?>;
      change(
        section == null
            ? configuration
            : configuration[section]! as Map<String, Object?>,
      );
      write('scripts/resources.json', jsonEncode(configuration));
    }

    test('rejects missing or malformed configuration', () {
      File.fromUri(project.uri.resolve('scripts/resources.json')).deleteSync();
      expect(
        () => generateAssetSources(project),
        failsWith('JSON file is missing'),
      );
      write('scripts/resources.json', '{invalid');
      expect(() => generateAssetSources(project), throwsFormatException);
    });

    test('rejects unknown settings', () {
      configure(
        null,
        (configuration) => configuration['plugins'] = <Object?>[],
      );
      expect(
        () => generateAssetSources(project),
        failsWith('unsupported fields'),
      );
    });

    test('rejects missing sources and paths outside the project', () {
      configure(
        'assets',
        (configuration) => configuration['directory'] = 'missing',
      );
      expect(
        () => generateAssetSources(project),
        failsWith('directory is missing'),
      );
      configure(
        'assets',
        (configuration) => configuration['directory'] = '../assets',
      );
      expect(
        () => generateAssetSources(project),
        failsWith('relative project path'),
      );
    });

    test('rejects generated suffixes and conflicting output paths', () {
      configure(
        'assets',
        (configuration) =>
            configuration['output'] = 'lib/app/assets/catalog.g.dart',
      );
      expect(
        () => generateAssetSources(project),
        failsWith('descriptive .dart'),
      );
      configure(
        'assets',
        (configuration) =>
            configuration['output'] = configuration['entryPoint'],
      );
      expect(() => generateAssetSources(project), failsWith('paths conflict'));
    });

    test('rejects duplicate locales and an unsupported fallback', () {
      configure(
        'localization',
        (configuration) => configuration['locales'] = ['en', 'en'],
      );
      expect(
        () => generateAssetSources(project),
        failsWith('Locales must be unique'),
      );
      configure(
        'localization',
        (configuration) => configuration['fallback'] = 'fr',
      );
      expect(
        () => generateAssetSources(project),
        failsWith('include the fallback'),
      );
    });

    test('rejects invalid locale identifiers', () {
      configure(
        'localization',
        (configuration) => configuration['locales'] = ['../en'],
      );
      expect(
        () => generateAssetSources(project),
        failsWith('locale identifiers'),
      );
    });

    test('rejects an output parent that is a symlink', () async {
      Directory.fromUri(project.uri.resolve('lib/')).createSync();
      Link.fromUri(project.uri.resolve('lib/app'))
          .createSync(project.parent.path);
      await expectLater(
        generateResourceSources(project),
        failsWith('symlinks'),
      );
    }, skip: Platform.isWindows);

    test('respects configured locations and fallback ordering', () async {
      configure('localization', (configuration) {
        configuration['fallback'] = 'ru';
        configuration['entryPoint'] = 'lib/languages/languages.dart';
        configuration['output'] = 'lib/languages/messages.dart';
      });
      final sources = await generateResourceSources(project);
      expect(sources.keys, contains('lib/languages/languages.dart'));
      final source = sources['lib/languages/messages.dart']!;
      expect(
        source.indexOf("languageCode: 'ru'"),
        lessThan(source.indexOf("languageCode: 'en'")),
      );
    });

    test('validates real pubspec block lists, quoting and comments', () {
      write('assets/icons/restart.png', 'image');
      write('pubspec.yaml', '''
name: fixture
flutter:
  uses-material-design: true
  assets:
    - 'assets/icons/' # registered directory
''');
      expect(generateAssetSources(project), hasLength(2));
      write('pubspec.yaml', '''
name: fixture
flutter:
  assets:
    - path: assets/icons/
      flavors: [demo]
''');
      expect(() => generateAssetSources(project), throwsFormatException);
    });

    test('does not bundle compile-time localization sources', () {
      register(['assets/localization/']);
      expect(
        () => generateAssetSources(project),
        failsWith('must not be bundled'),
      );
    });
  });

  group('Asset catalogs', () {
    test('emits no placeholder module when there are no bundled assets', () {
      expect(generateAssetSources(project), isEmpty);
      expect(
        Directory.fromUri(project.uri.resolve('lib/app/assets/')).existsSync(),
        isFalse,
      );
    });

    test(
      'generates nested named groups and usable Flutter asset keys',
      () async {
        register(['assets/icons/', 'assets/levels/first/']);
        write('assets/icons/restart-button.svg', '<svg/>');
        write('assets/levels/first/board_data.json', '{"tiles": 4}');
        final sources = generateAssetSources(project);
        for (final entry in sources.entries) {
          write(entry.key, entry.value);
        }
        write(
          'probe.dart',
          "import 'dart:io';\n"
              "import 'lib/app/assets/assets.dart';\n"
              '''
void main() {
  if (assets.icons.restartButton != 'assets/icons/restart-button.svg') {
    throw StateError('Wrong icon key');
  }
  print(File(assets.levels.first.boardData).readAsStringSync());
}
''',
        );
        final result = await Process.run('dart', [
          'probe.dart',
        ], workingDirectory: project.path);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect('${result.stdout}'.trim(), '{"tiles": 4}');
        expect(sources, hasLength(2));
      },
    );

    test('normalizes snake case, kebab case, Pascal case and capitals', () {
      register(['assets/Icons/']);
      write('assets/Icons/RESTART.png', 'image');
      write('assets/Icons/next_level.svg', 'image');
      write('assets/Icons/play-button.png', 'image');
      final source = generateAssetSources(
        project,
      )['lib/app/assets/catalog.dart']!;
      expect(source, contains('get icons'));
      expect(source, contains('get restart'));
      expect(source, contains('get nextLevel'));
      expect(source, contains('get playButton'));
      expect(source, contains('assets/Icons/RESTART.png'));
    });

    test('rejects parent-only registration for nested assets', () {
      register(['assets/']);
      write('assets/icons/restart.png', 'image');
      expect(
        () => generateAssetSources(project),
        failsWith('Unregistered asset'),
      );
    });

    test('accepts individual asset registrations', () {
      register(['assets/icons/restart.png']);
      write('assets/icons/restart.png', 'image');
      expect(generateAssetSources(project), hasLength(2));
    });

    test('rejects missing registered files and unapproved roots', () {
      register(['assets/missing.png']);
      expect(() => generateAssetSources(project), failsWith('does not exist'));
      register(['web/favicon.png']);
      expect(() => generateAssetSources(project), failsWith('Only assets/'));
      register(['assets/../secret.json']);
      expect(
        () => generateAssetSources(project),
        failsWith('relative project path'),
      );
    });

    test('requires newly discovered files to be registered too', () {
      register(['assets/icons/restart.png']);
      write('assets/icons/restart.png', 'image');
      write('assets/data/board.json', '{}');
      expect(
        () => generateAssetSources(project),
        failsWith('assets/data/board.json'),
      );
    });

    test('rejects duplicate registrations', () {
      register(['assets/', 'assets/']);
      write('assets/icon.png', 'image');
      expect(
        () => generateAssetSources(project),
        failsWith('Duplicate Flutter asset entry'),
      );
    });

    for (final filenames in [
      ['restart.png', 'restart.svg'],
      ['restart.png', 'RESTART.png'],
      ['next-level.png', 'next_level.png'],
      ['nextLevel.png', 'nextlevel.png'],
      ['icons.png', 'icons/restart.png'],
    ]) {
      test('rejects colliding paths $filenames', () {
        register(['assets/', 'assets/icons/']);
        Directory.fromUri(project.uri.resolve('assets/icons/'))
            .createSync(recursive: true);
        for (final filename in filenames) {
          write('assets/$filename', 'image');
        }
        expect(() => generateAssetSources(project), failsWith('collision'));
      });
    }

    test('rejects ambiguous generated group type names', () {
      register(['assets/a-b/c/', 'assets/a/b-c/']);
      write('assets/a-b/c/tile.png', 'image');
      write('assets/a/b-c/tile.png', 'image');
      expect(
        () => generateAssetSources(project),
        failsWith('Asset type collision'),
      );
    });

    for (final filename in [
      '1tile.png',
      'two words.png',
      'тайл.png',
      'class.png',
      'runtimeType.png',
      "icon.png'",
      'icon.',
    ]) {
      test('rejects invalid or reserved name $filename', () {
        register(['assets/']);
        write('assets/$filename', 'image');
        expect(() => generateAssetSources(project), throwsFormatException);
      });
    }

    test('resolution variants share one base accessor', () {
      register(['assets/icons/']);
      write('assets/icons/restart.png', 'base');
      write('assets/icons/2.0x/restart.png', 'larger');
      final source = generateAssetSources(
        project,
      )['lib/app/assets/catalog.dart']!;
      expect('get restart'.allMatches(source), hasLength(1));
      expect(source, isNot(contains('2.0x')));
    });

    test('requires a base image for resolution variants', () {
      register(['assets/icons/']);
      write('assets/icons/2.0x/restart.png', 'larger');
      expect(() => generateAssetSources(project), failsWith('no base image'));
    });

    test(
      'rejects symlinks without reading their targets',
      () {
        register(['assets/']);
        Directory.fromUri(project.uri.resolve('assets/'))
            .createSync(recursive: true);
        Link.fromUri(project.uri.resolve('assets/outside'))
            .createSync(project.parent.path);
        expect(() => generateAssetSources(project), failsWith('symlinks'));
      },
      skip: Platform.isWindows
          ? 'Windows requires privileges to create symlinks.'
          : false,
    );

    test('discovery order does not affect output', () {
      register(['assets/']);
      write('assets/zebra.json', '{}');
      write('assets/alpha.json', '{}');
      final first = generateAssetSources(project);
      File.fromUri(project.uri.resolve('assets/zebra.json')).deleteSync();
      write('assets/zebra.json', '{}');
      expect(generateAssetSources(project), first);
    });
  });

  group('Localization validation', () {
    test('preserves existing catalogs and translations', () {
      final catalogs = validateLocalizationCatalogs(project);
      expect(catalogs['ru']!['startGame'], 'Начать игру');
      expect(catalogs, hasLength(2));
    });

    test('rejects missing and extra message keys', () {
      catalog('ru', {'unexpected': 'Лишнее'});
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('translation keys differ'),
      );
    });

    test('rejects unconfigured catalog filenames', () {
      catalog('fr', {'startGame': 'Start'});
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('filenames must match'),
      );
    });

    test('rejects duplicate JSON keys including escaped names', () {
      write(
        'assets/localization/en.json',
        r'{"startGame":"First","start\u0047ame":"Second"}',
      );
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('duplicate JSON key'),
      );
    });

    test('rejects invalid JSON and non-string messages', () {
      write('assets/localization/en.json', '{invalid');
      expect(
        () => validateLocalizationCatalogs(project),
        throwsFormatException,
      );
      catalog('en', {
        'startGame': {'message': 1},
      });
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('ICU message string'),
      );
    });

    for (final key in ['class', 'localeName', 'supportedLocales', '1message']) {
      test('rejects invalid or conflicting message name $key', () {
        catalog('en', {key: 'message'});
        expect(
          () => validateLocalizationCatalogs(project),
          throwsFormatException,
        );
      });
    }

    test('rejects message names differing only by case', () {
      catalog('en', {'startGame': 'Start', 'startgame': 'Start'});
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('identifier collision'),
      );
    });

    test('rejects undeclared parameter types', () {
      catalog('en', {'score': '{points}'});
      catalog('ru', {'score': '{points}'});
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('declare metadata'),
      );
    });

    test('rejects placeholder names inconsistent across locales', () {
      catalog('en', {
        'score': _message('{points}', {'points': 'int'}),
      });
      catalog('ru', {'score': '{count}'});
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('placeholder names'),
      );
    });

    test('rejects incompatible parameter types', () {
      catalog('en', {
        'score': _message('{points}', {'points': 'int'}),
      });
      catalog('ru', {
        'score': _message('{points}', {'points': 'String'}),
      });
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('consistent explicit parameter type'),
      );
    });

    test('rejects unused placeholder metadata', () {
      catalog('en', {
        'score': _message('Score', {'points': 'int'}),
      });
      catalog('ru', {'score': 'Счёт'});
      expect(() => validateLocalizationCatalogs(project), failsWith('exactly'));
    });

    test('rejects metadata without a message', () {
      catalog('en', {
        'score': {
          'placeholders': {
            'points': {'type': 'int'},
          },
        },
      });
      expect(
        () => validateLocalizationCatalogs(project),
        throwsFormatException,
      );
    });

    test('finds arguments inside nested plural and select branches', () {
      const message =
          '{count, plural, one{{name} moves} '
          'other{{kind, select, a{{name} wins} other{{name} loses}}}}';
      catalog('en', {
        'turn': _message(message, {
          'count': 'int',
          'name': 'String',
          'kind': 'String',
        }),
      });
      catalog('ru', {'turn': message});
      expect(validateLocalizationCatalogs(project), hasLength(2));
    });

    test('respects ICU quoted braces and apostrophes', () {
      const message = "'{literal}' {name}''";
      catalog('en', {
        'greeting': _message(message, {'name': 'String'}),
      });
      catalog('ru', {'greeting': message});
      expect(validateLocalizationCatalogs(project), hasLength(2));
    });

    test('rejects malformed message argument boundaries', () {
      catalog('en', {'score': '{points'});
      catalog('ru', {'score': '{points'});
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('malformed ICU'),
      );
    });

    test('rejects group type collisions', () {
      catalog('en', {
        'aB': {
          'c': {'text': 'one'},
        },
        'a': {
          'bC': {'text': 'two'},
        },
      });
      expect(
        () => validateLocalizationCatalogs(project),
        failsWith('group type collision'),
      );
    });
  });

  group('Resource compilation', () {
    for (final filename in ['gen_localizations.stamp', 'outputs.json']) {
      test('detects legacy generated-file ownership in $filename', () async {
        final outputs = [
          File.fromUri(
            project.uri.resolve('lib/app/localization/localization.dart'),
          ).path,
        ];
        final metadata = jsonEncode(
          filename.endsWith('.stamp') ? {'outputs': outputs} : outputs,
        );
        final path = '.dart_tool/flutter_build/old/$filename';
        write(path, metadata);
        write(
          'lib/app/localization/localization.dart',
          '// Handwritten fixture\n',
        );

        await expectLater(
          generateResourceSources(project),
          failsWith('Legacy Flutter build metadata'),
        );
        expect(
          File.fromUri(project.uri.resolve(path)).readAsStringSync(),
          metadata,
        );
        expect(
          File.fromUri(
            project.uri.resolve('lib/app/localization/localization.dart'),
          ).readAsStringSync(),
          '// Handwritten fixture\n',
        );
      });
    }

    test(
      'rejects competing automatic Flutter localization generation',
      () async {
        write('l10n.yaml', 'arb-dir: obsolete');
        await expectLater(
          generateResourceSources(project),
          failsWith('root l10n.yaml'),
        );
      },
    );

    test(
      'generates deterministic typed accessors with intl plural rules',
      () async {
        catalog('en', {
          'startGame': 'Start game',
          'game': {
            'greeting': _message("'{literal}' {name}''", {'name': 'String'}),
          },
          'selection': _message('{kind, select, a{Won} other{Lost}}', {
            'kind': 'String',
          }),
          'exact': _message(
            '{count, plural, =0{None} one{# move} other{# moves}}',
            {'count': 'int'},
          ),
          'score': {
            'message': '{points}',
            'placeholders': {
              'points': {'type': 'int', 'format': 'decimalPattern'},
            },
          },
          'remaining': _message(
            '{count, plural, one{1 move} other{{count} moves}}',
            {'count': 'int'},
          ),
        });
        catalog('ru', {
          'startGame': 'Начать игру',
          'game': {'greeting': "'{literal}' {name}''"},
          'selection': '{kind, select, a{Победа} other{Поражение}}',
          'exact':
              '{count, plural, =0{Нет} one{# ход} few{# хода} '
              'many{# ходов} other{# хода}}',
          'score': '{points}',
          'remaining':
              '{count, plural, one{{count} ход} few{{count} хода} '
              'many{{count} ходов} other{{count} хода}}',
        });
        final sources = await generateResourceSources(project);
        expect(await generateResourceSources(project), sources);
        expect(
          sources['lib/app/localization/messages.dart'],
          contains('String get startGame'),
        );
        expect(
          sources['lib/app/localization/messages.dart'],
          contains('score({required int points})'),
        );
        for (final entry in sources.entries) {
          write(entry.key, entry.value);
        }
        write(
          'generated_runtime_test.dart',
          "import 'package:flutter/widgets.dart';\n"
              "import 'package:flutter_test/flutter_test.dart';\n"
              "import 'lib/app/localization/messages.dart';\n"
              r'''
void main() {
  test('named parameters, Russian plurals and formatting', () async {
    final english = await AppLocalization.delegate.load(const Locale('en'));
    final russian = await AppLocalization.delegate.load(const Locale('ru'));
    expect(english.startGame, 'Start game');
    expect(russian.startGame, 'Начать игру');
    expect(english.score(points: 1250), '1,250');
    expect(russian.score(points: 1250), '1\u00a0250');
    expect(english.remaining(count: 1), '1 move');
    expect(english.remaining(count: 2), '2 moves');
    expect(russian.remaining(count: 1), '1 ход');
    expect(russian.remaining(count: 2), '2 хода');
    expect(russian.remaining(count: 5), '5 ходов');
    expect(russian.remaining(count: 21), '21 ход');
    expect(english.game.greeting(name: 'Player'), "{literal} Player'");
    expect(russian.selection(kind: 'a'), 'Победа');
    expect(english.selection(kind: 'unknown'), 'Lost');
    expect(english.exact(count: 0), 'None');
    expect(russian.exact(count: 5), '5 ходов');
    final fallback = AppLocalization.forLocale(const Locale('fr'));
    expect(fallback.startGame, 'Start game');
  });
}
''',
        );
        final result = await Process.run('flutter', [
          'test',
          '--no-pub',
          '--reporter',
          'expanded',
          '${project.path}/generated_runtime_test.dart',
        ]);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('check reports stale output without overwriting it', () async {
      await updateResources(project, check: false);
      await updateResources(project, check: true);
      final output = File.fromUri(
        project.uri.resolve('lib/app/localization/messages.dart'),
      );
      final original = output.readAsStringSync();
      output.writeAsStringSync('$original\n// Stale fixture\n');
      await expectLater(
        updateResources(project, check: true),
        failsWith('stale'),
      );
      expect(output.readAsStringSync(), '$original\n// Stale fixture\n');
      await updateResources(project, check: false);
      expect(output.readAsStringSync(), original);
    });

    test(
      'catalog changes fail freshness checks even without key changes',
      () async {
        await updateResources(project, check: false);
        catalog('ru', {'startGame': 'Начать'});
        await expectLater(
          updateResources(project, check: true),
          failsWith('stale'),
        );
      },
    );

    test('refuses to overwrite handwritten files in managed paths', () async {
      write('lib/app/localization/messages.dart', '// Handwritten fixture\n');
      await expectLater(
        updateResources(project, check: false),
        failsWith('handwritten'),
      );
      expect(
        File.fromUri(project.uri.resolve('lib/app/localization/messages.dart'))
            .readAsStringSync(),
        '// Handwritten fixture\n',
      );
    });

    test(
      'checks asset freshness and removes only obsolete generated outputs',
      () async {
        register(['assets/icons/']);
        write('assets/icons/restart.png', 'image');
        await updateResources(project, check: false);
        await updateResources(project, check: true);
        register([]);
        Directory.fromUri(project.uri.resolve('assets/icons/'))
            .deleteSync(recursive: true);
        write('lib/app/assets/notes.dart', '// Handwritten fixture\n');
        await expectLater(
          updateResources(project, check: true),
          failsWith('stale'),
        );
        await updateResources(project, check: false);
        expect(
          File.fromUri(project.uri.resolve('lib/app/assets/catalog.dart'))
              .existsSync(),
          isFalse,
        );
        expect(
          File.fromUri(project.uri.resolve('lib/app/assets/assets.dart'))
              .existsSync(),
          isFalse,
        );
        expect(
          File.fromUri(project.uri.resolve('lib/app/assets/notes.dart'))
              .readAsStringSync(),
          '// Handwritten fixture\n',
        );
      },
    );

    test('rejects unsupported ICU plural syntax', () async {
      catalog('en', {
        'remaining': _message('{count, plural, invalid{message}}', {
          'count': 'int',
        }),
      });
      catalog('ru', {'remaining': '{count, plural, invalid{message}}'});
      await expectLater(
        generateResourceSources(project),
        failsWith('unsupported plural selector'),
      );
    });
  });
}

Map<String, Object?> _message(String message, Map<String, String> types) => {
  'message': message,
  'placeholders': {
    for (final entry in types.entries) entry.key: {'type': entry.value},
  },
};
