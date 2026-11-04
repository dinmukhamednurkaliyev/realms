import 'package:test/test.dart';

import '../../scripts/toml.dart';

void main() {
  group('TOML subset', () {
    test(
      'parses sections, comments, both string forms and multiline arrays',
      () {
        final configuration = parseToml('''
# Tool configuration
[assets] # source files
 directory = "assets = # source" # delimiters inside strings are literal
 exclude = [
   "localization/**", # ignored subtree
   'notes.txt',
 ]
[localization]
locales = ["en", "ru"]
fallback = 'en'
''');
        expect(configuration, {
          'assets': {
            'directory': 'assets = # source',
            'exclude': ['localization/**', 'notes.txt'],
          },
          'localization': {
            'locales': ['en', 'ru'],
            'fallback': 'en',
          },
        });
      },
    );

    test('supports TOML escapes without interpreting literal strings', () {
      final configuration = parseToml(r'''
[strings]
basic = "\b\t\n\f\r\"\\\u0041\U0001F332"
literal = '\u0041\n'
''');
      expect(configuration['strings']!['basic'], '\b\t\n\f\r"\\A🌲');
      expect(configuration['strings']!['literal'], r'\u0041\n');
    });

    test('supports CRLF, tabs, an empty array and no final newline', () {
      expect(parseToml('[section]\r\n\tkey\t=\t[]'), {
        'section': {'key': <String>[]},
      });
    });

    test('reports file, line and column for syntax errors', () {
      expect(
        () => parseToml('[assets]\ndirectory = 123\n', filename: 'tool.toml'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'location',
            startsWith('tool.toml:2:13:'),
          ),
        ),
      );
    });

    for (final source in [
      '[assets]\nkey = "one"\nkey = "two"',
      '[assets]\n[assets]',
    ]) {
      test('rejects duplicate keys or sections: $source', () {
        expect(
          () => parseToml(source),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'diagnostic',
              contains('Duplicate'),
            ),
          ),
        );
      });
    }

    for (final entry in <String, String>{
      'integer': 'key = 2',
      'boolean': 'key = true',
      'date': 'key = 2026-11-01',
      'inline table': 'key = { nested = "value" }',
      'nested array': 'key = [["en"]]',
      'mixed array': 'key = ["en", 2]',
      'missing comma': 'key = ["en" "ru"]',
      'extra comma': 'key = ["en",, "ru"]',
      'missing bracket': 'key = ["en"',
      'missing value': 'key =',
      'missing equals': 'key "value"',
      'trailing input': 'key = "value" extra',
      'two assignments': 'key = "a" other = "b"',
      'dotted key': 'a.b = "value"',
      'quoted key': '"key" = "value"',
      'multiline basic string': 'key = """value"""',
      'multiline literal string': "key = '''value'''",
      'unclosed string': 'key = "value',
      'newline in string': 'key = "first\nsecond"',
      'bare carriage return': 'key = "value"\r',
      'control character': 'key = "\u0000"',
      'control in comment': '# invalid\u0000',
      'unknown escape': r'key = "\q"',
      'JSON slash escape': r'key = "\/"',
      'short Unicode escape': r'key = "\u123"',
      'invalid Unicode escape': r'key = "\uZZZZ"',
      'Unicode surrogate': r'key = "\uD800"',
      'Unicode out of range': r'key = "\U00110000"',
    }.entries) {
      test('rejects ${entry.key}', () {
        expect(
          () => parseToml('[section]\n${entry.value}'),
          throwsFormatException,
        );
      });
    }

    for (final source in [
      'key = "root value"',
      '[assets.subgroup]',
      '[[assets]]',
      '["assets"]',
      '[assets',
      '[assets] junk',
    ]) {
      test('rejects unsupported section syntax: $source', () {
        expect(() => parseToml(source), throwsFormatException);
      });
    }
  });
}
