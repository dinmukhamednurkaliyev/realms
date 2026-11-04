/// Parses the tool's deliberately limited TOML subset, not the full standard.
///
/// Supports bare section/key names, single-line basic/literal strings, string
/// arrays (including multiline arrays and trailing commas), comments and CRLF.
/// Basic strings support TOML's escapes, including Unicode scalar escapes.
/// Dotted/quoted keys, multiline strings, tables in arrays and non-string values
/// are rejected. Syntax errors include [filename], line and column.
Map<String, Map<String, Object>> parseToml(
  String source, {
  String filename = 'configuration.toml',
}) => _TomlParser(source.replaceAll('\r\n', '\n'), filename).parse();

final class _TomlParser {
  new(this.source, this.filename);

  final String source;
  final String filename;
  int offset = 0;
  int line = 1;
  int column = 1;

  bool get _atEnd => offset == source.length;
  String get _character => _atEnd ? '' : source[offset];

  Never _fail(String message) =>
      throw FormatException('$filename:$line:$column: $message');

  String _advance() {
    final character = source[offset++];
    if (character == '\n') {
      line++;
      column = 1;
    } else {
      column++;
    }
    return character;
  }

  void _expect(String character) {
    if (_character != character) _fail('Expected "$character".');
    _advance();
  }

  void _skipSpace({required bool newlines}) {
    while (!_atEnd) {
      if (_character == ' ' ||
          _character == '\t' ||
          (newlines && _character == '\n')) {
        _advance();
      } else if (_character == '#') {
        while (!_atEnd && _character != '\n') {
          final code = _character.codeUnitAt(0);
          if ((code < 32 && code != 9) || code == 127) {
            _fail('Control characters are not allowed in comments.');
          }
          _advance();
        }
      } else {
        return;
      }
    }
  }

  String _name() {
    final start = offset;
    while (!_atEnd && RegExp(r'^[A-Za-z0-9_-]$').hasMatch(_character)) {
      _advance();
    }
    if (offset == start) {
      _fail(
        'Use a bare section or key name; quoted/dotted names are unsupported.',
      );
    }
    return source.substring(start, offset);
  }

  Map<String, Map<String, Object>> parse() {
    final sections = <String, Map<String, Object>>{};
    Map<String, Object>? section;
    while (true) {
      _skipSpace(newlines: true);
      if (_atEnd) return sections;
      if (_character == '[') {
        _advance();
        _skipSpace(newlines: false);
        final name = _name();
        _skipSpace(newlines: false);
        _expect(']');
        if (sections.containsKey(name)) _fail('Duplicate section [$name].');
        section = sections[name] = <String, Object>{};
      } else {
        if (section == null) _fail('Define a [section] before its settings.');
        final key = _name();
        if (section.containsKey(key)) _fail('Duplicate key "$key".');
        _skipSpace(newlines: false);
        _expect('=');
        _skipSpace(newlines: false);
        section[key] = _character == '[' ? _array() : _string();
      }
      _skipSpace(newlines: false);
      if (!_atEnd && _character != '\n') {
        _fail(
          'Unexpected trailing input; '
          'only strings and string arrays are supported.',
        );
      }
    }
  }

  List<String> _array() {
    _expect('[');
    final values = <String>[];
    _skipSpace(newlines: true);
    while (_character != ']') {
      values.add(_string());
      _skipSpace(newlines: true);
      if (_character == ']') break;
      _expect(',');
      _skipSpace(newlines: true);
    }
    _expect(']');
    return values;
  }

  String _string() {
    final quote = _character;
    if (quote != '"' && quote != "'") {
      _fail('Expected a quoted string; other value types are unsupported.');
    }
    if (source.startsWith(quote * 3, offset)) {
      _fail('Multiline strings are unsupported.');
    }
    _advance();
    final value = StringBuffer();
    while (!_atEnd) {
      final character = _character;
      final code = character.codeUnitAt(0);
      if ((code < 32 && code != 9) || code == 127) {
        _fail('Unescaped control character or newline in string.');
      }
      _advance();
      if (character == quote) return value.toString();
      if (quote == '"' && character == r'\') {
        if (_atEnd) _fail('Unfinished string escape.');
        final escape = _advance();
        const escapes = {
          'b': '\b',
          't': '\t',
          'n': '\n',
          'f': '\f',
          'r': '\r',
          '"': '"',
          r'\': r'\',
        };
        if (escapes.containsKey(escape)) {
          value.write(escapes[escape]);
        } else if (escape == 'u' || escape == 'U') {
          final digits = escape == 'u' ? 4 : 8;
          final start = offset;
          for (var index = 0; index < digits; index++) {
            if (_atEnd || !RegExp(r'^[0-9A-Fa-f]$').hasMatch(_character)) {
              _fail('A Unicode escape requires $digits hexadecimal digits.');
            }
            _advance();
          }
          final scalar = int.parse(source.substring(start, offset), radix: 16);
          if (scalar > 0x10FFFF || (scalar >= 0xD800 && scalar <= 0xDFFF)) {
            _fail('Unicode escapes must identify a Unicode scalar value.');
          }
          value.writeCharCode(scalar);
        } else {
          _fail('Unsupported string escape: \\$escape.');
        }
      } else {
        value.write(character);
      }
    }
    _fail('Unterminated string.');
  }
}
