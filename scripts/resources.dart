import 'dart:convert';
import 'dart:io';

const _generatedHeader =
    '// GENERATED CODE - DO NOT MODIFY BY HAND.\n'
    '// Generator: scripts/resources.dart. Manual edits will be overwritten.\n';

final Set<String> _reservedNames = {
  ...'abstract as assert async augment await base break case catch class const '
          'continue covariant default deferred do dynamic else enum export '
          'extension '
          'external factory false final finally for Function get hide if '
          'implements '
          'import in interface is late library mixin native new null of on '
          'operator '
          'part required rethrow return sealed set show static super switch '
          'sync '
          'this throw true try type typedef var void when while with yield'
      .split(' '),
  'hashCode',
  'runtimeType',
  'noSuchMethod',
  'toString',
};

/// Generates resources, or checks freshness without writing to the project.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 ||
      !{'generate', 'check'}.contains(arguments.single)) {
    stderr.writeln('Usage: dart run scripts/resources.dart <generate|check>');
    exitCode = 64;
    return;
  }
  try {
    await updateResources(
      Directory.current,
      check: arguments.single == 'check',
    );
  } on Exception catch (error) {
    stderr.writeln('Resources: $error');
    exitCode = 1;
  }
}

/// Validates all output before replacing only files owned by this generator.
Future<void> updateResources(Directory project, {required bool check}) async {
  final configuration = _ResourceConfiguration.read(project);
  final sources = await generateResourceSources(project);
  final obsolete = <File>[];
  for (final path in {configuration.assetOutput, configuration.messageOutput}) {
    final directory = File.fromUri(project.uri.resolve(path)).parent;
    if (!directory.existsSync()) continue;
    for (final file
        in directory.listSync(followLinks: false).whereType<File>()) {
      if (file.path.endsWith('.dart') &&
          _owns(file.readAsStringSync()) &&
          !sources.containsKey(
            file.uri.path.substring(project.absolute.uri.path.length),
          )) {
        obsolete.add(file);
      }
    }
  }
  final changed = <String>[];
  for (final MapEntry(key: path, value: contents) in sources.entries) {
    final file = File.fromUri(project.uri.resolve(path));
    if (FileSystemEntity.isLinkSync(file.path)) {
      throw FormatException('Generated output must not be a symlink: $path');
    }
    if (!file.existsSync() || file.readAsStringSync() != contents) {
      if (file.existsSync() && !_owns(file.readAsStringSync())) {
        throw FormatException('Refusing to overwrite handwritten file: $path');
      }
      changed.add(path);
    }
  }
  if (check) {
    if (changed.isNotEmpty || obsolete.isNotEmpty) {
      throw FormatException(
        'Generated resources are stale: '
        '${[...changed, ...obsolete.map((file) => file.path)].join(', ')}. '
        'Run mise run resources:generate.',
      );
    }
    stdout.writeln(
      'Resources are valid and current (${sources.length} files).',
    );
    return;
  }
  for (final path in changed) {
    _write(project, path, sources[path]!);
  }
  for (final file in obsolete) {
    file.deleteSync();
  }
  stdout.writeln(
    'Generated resources: ${changed.length} updated, '
    '${obsolete.length} obsolete outputs removed.',
  );
}

/// Uses only the Dart SDK to compile and format deterministic resource sources.
Future<Map<String, String>> generateResourceSources(Directory project) async {
  final configuration = _ResourceConfiguration.read(project);
  if (File.fromUri(project.uri.resolve('l10n.yaml')).existsSync()) {
    throw const FormatException(
      'Remove the obsolete root l10n.yaml; '
      'scripts/resources.json owns localization configuration.',
    );
  }
  _checkLegacyBuildOutputs(project, configuration);
  final sources = {
    ...generateAssetSources(project),
    ..._generateMessageSources(project, configuration),
  };
  final temporary = Directory.systemTemp.createTempSync('realms-resources-');
  try {
    for (final entry in sources.entries) {
      _write(temporary, entry.key, entry.value);
    }
    final result = await Process.run(Platform.isWindows ? 'dart.bat' : 'dart', [
      'format',
      'lib',
    ], workingDirectory: temporary.path);
    if (result.exitCode != 0) {
      throw ProcessException(
        'dart',
        ['format'],
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }
    return {
      for (final path in sources.keys.toList()..sort())
        path: File.fromUri(temporary.uri.resolve(path)).readAsStringSync(),
    };
  } finally {
    temporary.deleteSync(recursive: true);
  }
}

bool _owns(String source) =>
    source.startsWith('// GENERATED CODE - DO NOT MODIFY BY HAND.') &&
    source.split('\n').take(2).join('\n').contains('scripts/resources.dart');

final class _ResourceConfiguration {
  new(
    this.assetDirectory,
    this.assetEntryPoint,
    this.assetOutput,
    this.catalogDirectory,
    this.locales,
    this.fallback,
    this.messageEntryPoint,
    this.messageOutput,
  );

  factory read(Directory project) {
    final input = _readJson(
      File.fromUri(project.uri.resolve('scripts/resources.json')),
    );
    _keys(input, {'assets', 'localization'}, 'resources.json');
    final assets = _map(input['assets'], 'assets configuration');
    final localization = _map(
      input['localization'],
      'localization configuration',
    );
    _keys(assets, {
      'directory',
      'entryPoint',
      'output',
    }, 'assets configuration');
    _keys(localization, {
      'directory',
      'locales',
      'fallback',
      'entryPoint',
      'output',
    }, 'localization configuration');
    String directory(Object? value) {
      final path = _relativePath(value, 'source directory');
      _rejectLinks(project, path);
      if (path.endsWith('/') ||
          path.startsWith('lib/') ||
          path.startsWith('.')) {
        throw FormatException(
          'Source directories must be resource paths '
          'without a trailing slash: $path',
        );
      }
      final folder = Directory.fromUri(project.uri.resolve(path));
      if (!folder.existsSync() || FileSystemEntity.isLinkSync(folder.path)) {
        throw FormatException(
          'Resource directory is missing or a symlink: $path',
        );
      }
      return path;
    }

    String output(Object? value) {
      final path = _relativePath(value, 'generated output');
      _rejectLinks(project, path);
      if (!path.startsWith('lib/') ||
          !path.endsWith('.dart') ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart')) {
        throw FormatException(
          'Use a descriptive .dart output path inside lib/: $path',
        );
      }
      return path;
    }

    final locales = localization['locales'];
    if (locales is! List ||
        locales.isEmpty ||
        locales.any(
          (locale) =>
              locale is! String ||
              !RegExp(
                r'^[a-z]{2,3}(?:_[A-Z][a-z]{3})?(?:_[A-Z]{2}|_[0-9]{3})?$',
              ).hasMatch(locale),
        )) {
      throw const FormatException(
        'locales must be a nonempty list of locale identifiers, '
        'such as en and ru.',
      );
    }
    final supported = locales.cast<String>();
    if (supported.toSet().length != supported.length ||
        !supported.contains(localization['fallback'])) {
      throw const FormatException(
        'Locales must be unique and include the fallback locale.',
      );
    }
    final configuration = _ResourceConfiguration(
      directory(assets['directory']),
      output(assets['entryPoint']),
      output(assets['output']),
      directory(localization['directory']),
      List.unmodifiable(supported),
      localization['fallback']! as String,
      output(localization['entryPoint']),
      output(localization['output']),
    );
    final outputs = {
      configuration.assetEntryPoint,
      configuration.assetOutput,
      configuration.messageEntryPoint,
      configuration.messageOutput,
    };
    if (outputs.length != 4 ||
        configuration.assetDirectory == configuration.catalogDirectory ||
        configuration.assetDirectory.startsWith(
          '${configuration.catalogDirectory}/',
        ) ||
        File(configuration.assetEntryPoint).parent.path !=
            File(configuration.assetOutput).parent.path ||
        File(configuration.messageEntryPoint).parent.path !=
            File(configuration.messageOutput).parent.path ||
        File(configuration.messageOutput).parent.path ==
            File(configuration.assetOutput).parent.path) {
      throw const FormatException(
        'Resource paths conflict: use distinct asset and localization modules, '
        'with each entry point beside its generated implementation.',
      );
    }
    return configuration;
  }

  final String assetDirectory;
  final String assetEntryPoint;
  final String assetOutput;
  final String catalogDirectory;
  final List<String> locales;
  final String fallback;
  final String messageEntryPoint;
  final String messageOutput;
}

// Read only the plain flutter.assets block. Reject complex YAML rather than
// interpreting it incorrectly or rewriting the developer-owned pubspec.
List<Object?> _registeredAssets(File pubspec) {
  final text = pubspec.readAsStringSync();
  if (text.trimLeft().startsWith('{')) {
    final flutter = _map(_readJson(pubspec)['flutter'] ?? {}, 'flutter');
    final assets = flutter['assets'] ?? <Object?>[];
    if (assets is! List) {
      throw const FormatException('flutter.assets must be a list.');
    }
    return assets;
  }
  var inFlutter = false;
  int? assetIndent;
  var foundFlutter = false;
  var foundAssets = false;
  final paths = <Object?>[];
  for (final raw in const LineSplitter().convert(text)) {
    final line = _withoutComment(raw).trimRight();
    if (line.trim().isEmpty) continue;
    final indent = line.length - line.trimLeft().length;
    final content = line.trim();
    if (indent == 0) {
      inFlutter = false;
      assetIndent = null;
      if (content.startsWith('flutter:')) {
        if (foundFlutter || content != 'flutter:') {
          throw const FormatException(
            'Use one plain flutter: mapping in pubspec.yaml.',
          );
        }
        foundFlutter = inFlutter = true;
      }
      continue;
    }
    if (!inFlutter) continue;
    if (content.startsWith('assets:')) {
      if (foundAssets || !{'assets:', 'assets: []'}.contains(content)) {
        throw const FormatException(
          'Use one block list of plain paths for flutter.assets.',
        );
      }
      foundAssets = true;
      assetIndent = content == 'assets:' ? indent : null;
      continue;
    }
    if (assetIndent == null) continue;
    if (indent < assetIndent ||
        (indent == assetIndent && !content.startsWith('- '))) {
      assetIndent = null;
      continue;
    }
    if (!content.startsWith('- ')) {
      throw const FormatException(
        'flutter.assets supports plain paths, '
        'not flavor or transformer mappings.',
      );
    }
    var value = content.substring(2).trim();
    if (value.startsWith('"')) {
      final decoded = jsonDecode(value);
      if (decoded is! String) {
        throw const FormatException('Asset path must be a string.');
      }
      value = decoded;
    } else if (value.startsWith("'") && value.endsWith("'")) {
      value = value.substring(1, value.length - 1).replaceAll("''", "'");
    }
    paths.add(value);
  }
  return paths;
}

String _withoutComment(String line) {
  String? quote;
  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (quote == '"' && character == r'\') {
      index++;
      continue;
    }
    if (quote != null) {
      if (character == quote) quote = null;
    } else if (character == '"' || character == "'") {
      quote = character;
    } else if (character == '#' &&
        (index == 0 || line[index - 1].trim().isEmpty)) {
      return line.substring(0, index);
    }
  }
  return line;
}

// Flutter deletes outputs of retired build targets, even when now handwritten.
void _checkLegacyBuildOutputs(
  Directory project,
  _ResourceConfiguration configuration,
) {
  final cache = Directory.fromUri(
    project.uri.resolve('.dart_tool/flutter_build/'),
  );
  if (!cache.existsSync()) return;
  final localizationPrefix = File.fromUri(
    project.uri.resolve(configuration.messageOutput),
  ).parent.absolute.uri.path;
  for (final file
      in cache
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (name != 'gen_localizations.stamp' && name != 'outputs.json') continue;
    final metadata = jsonDecode(file.readAsStringSync());
    final outputs = metadata is Map<String, Object?>
        ? metadata['outputs']
        : metadata;
    if (outputs is List &&
        outputs.whereType<String>().any(
          (path) => File(path).absolute.uri.path.startsWith(localizationPrefix),
        )) {
      throw const FormatException(
        'Legacy Flutter build metadata still owns localization source files. '
        'Move .dart_tool/flutter_build/ aside and rerun this command before '
        'building; otherwise Flutter may delete the localization entry point.',
      );
    }
  }
}

/// Discovers assets and validates Flutter's non-recursive registrations.
///
/// Snake/kebab names become lowerCamelCase. Resolution variants share their
/// base image key. No catalog is emitted until actual bundled assets exist.
Map<String, String> generateAssetSources(Directory project) {
  final configuration = _ResourceConfiguration.read(project);
  final entries = _registeredAssets(
    File.fromUri(project.uri.resolve('pubspec.yaml')),
  );
  final prefix = '${configuration.assetDirectory}/';
  final catalogPrefix = '${configuration.catalogDirectory}/';
  final registrations = <String>{};
  for (final entry in entries) {
    if (entry is! String) {
      throw const FormatException(
        'flutter.assets requires plain paths. Flavor-specific or transformed '
        'assets need explicit generator support before they can be cataloged.',
      );
    }
    final path = _relativePath(entry, 'flutter.assets entry');
    if (!path.startsWith(prefix)) {
      throw FormatException(
        'Only $prefix is approved for bundled assets: $path',
      );
    }
    if (path.startsWith(catalogPrefix)) {
      throw FormatException(
        'Localization source catalogs must not be bundled: $path',
      );
    }
    final isDirectory = path.endsWith('/');
    final exists = isDirectory
        ? Directory.fromUri(project.uri.resolve(path)).existsSync()
        : File.fromUri(project.uri.resolve(path)).existsSync();
    if (!exists) {
      throw FormatException('Registered asset does not exist: $path');
    }
    if (!registrations.add(path)) {
      throw FormatException('Duplicate Flutter asset entry: $path');
    }
  }
  final directory = Directory.fromUri(project.uri.resolve(prefix));
  if (!directory.existsSync()) return {};
  if (FileSystemEntity.isLinkSync(directory.path)) {
    throw const FormatException('The assets/ directory must not be a symlink.');
  }
  final paths = <String>[];
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is Link) {
      throw FormatException(
        'Asset symlinks are not reproducible: ${entity.path}',
      );
    }
    if (entity is File && entity.uri.pathSegments.last != '.DS_Store') {
      final path = entity.uri.path.substring(project.absolute.uri.path.length);
      if (!path.startsWith(catalogPrefix)) paths.add(path);
    }
  }
  paths.sort();
  final discoveredPaths = paths.toSet();
  final resources = _AssetGroup('assets', 'AppAssets');
  final classes = <String, String>{'appassets': 'assets/'};
  final variants = RegExp(r'^(.+/)([0-9]+(?:\.[0-9]+)?x)/([^/]+)$');
  for (final path in paths) {
    final variant = variants.firstMatch(path);
    final assetKey = variant == null
        ? path
        : '${variant.group(1)}${variant.group(3)}';
    if (!discoveredPaths.contains(assetKey)) {
      throw FormatException('Image variant $path has no base image: $assetKey');
    }
    final parent = assetKey.substring(0, assetKey.lastIndexOf('/') + 1);
    if (!registrations.contains(assetKey) && !registrations.contains(parent)) {
      throw FormatException(
        'Unregistered asset: $assetKey. Add "$parent" or "$assetKey" to '
        'flutter.assets; parent directories do not include nested files.',
      );
    }
    if (variant != null) continue;
    final segments = path.substring(prefix.length).split('/');
    var group = resources;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      final isFile = index == segments.length - 1;
      if (isFile &&
          !RegExp(r'^[A-Za-z][A-Za-z0-9_-]*(?:\.[A-Za-z0-9]+)?$')
              .hasMatch(segment)) {
        throw FormatException('Invalid asset filename: $path');
      }
      final extension = isFile ? segment.lastIndexOf('.') : -1;
      final stem = extension > 0 ? segment.substring(0, extension) : segment;
      final identifier = _assetIdentifier(stem, path);
      final origin = segments.take(index + 1).join('/');
      final collisionKey = identifier.toLowerCase();
      final previous = group.origins[collisionKey];
      if (previous != null && (previous != origin || isFile)) {
        throw FormatException(
          'Asset identifier collision: $previous and $origin '
          'map to $identifier.',
        );
      }
      group.origins[collisionKey] = origin;
      if (isFile) {
        group.files[identifier] = assetKey;
      } else {
        final className = '${group.className}${_upperFirst(identifier)}';
        final previousClass = classes[className.toLowerCase()];
        if (previousClass != null && previousClass != origin) {
          throw FormatException(
            'Asset type collision: $previousClass and $origin '
            'map to $className.',
          );
        }
        classes[className.toLowerCase()] = origin;
        group = group.groups.putIfAbsent(
          identifier,
          () => _AssetGroup(identifier, className),
        );
      }
    }
  }
  if (resources.files.isEmpty && resources.groups.isEmpty) return {};
  final declarations = StringBuffer(_generatedHeader)
    ..writeln('/// Immutable keys for the registered application assets.')
    ..writeln('const assets = AppAssets();');
  final types = <String>[];
  void emit(_AssetGroup group) {
    types.add(group.className);
    declarations
      ..writeln('/// Resources grouped by their source directory.')
      ..writeln('final class ${group.className} {')
      ..writeln('/// Creates this immutable resource group.')
      ..writeln('const new();');
    for (final child in group.groups.values) {
      declarations
        ..writeln('/// The ${child.name} resource directory.')
        ..writeln(
          '${child.className} get ${child.name} => const ${child.className}();',
        );
    }
    for (final MapEntry(key: name, value: key) in group.files.entries) {
      declarations
        ..writeln('/// Flutter asset key for $key.')
        ..writeln("String get $name => '$key';");
    }
    declarations.writeln('}');
    group.groups.values.forEach(emit);
  }

  emit(resources);
  return {
    configuration.assetEntryPoint:
        '$_generatedHeader\n'
        "export '${configuration.assetOutput.split('/').last}' "
        "show assets, ${types.join(', ')};\n",
    configuration.assetOutput: declarations.toString(),
  };
}

final class _AssetGroup {
  new(this.name, this.className);

  final String name;
  final String className;
  final origins = <String, String>{};
  final groups = <String, _AssetGroup>{};
  final files = <String, String>{};
}

String _assetIdentifier(String name, String path) {
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$').hasMatch(name)) {
    throw FormatException(
      'Invalid asset name "$name" in $path. Use ASCII letters, digits, '
      'hyphens or underscores, starting with a letter.',
    );
  }
  final words = name.split(RegExp('[-_]+'));
  String normalize(String word) => word == word.toUpperCase()
      ? word.toLowerCase()
      : '${word[0].toLowerCase()}${word.substring(1)}';
  final identifier =
      normalize(words.first) +
      words
          .skip(1)
          .where((word) => word.isNotEmpty)
          .map(normalize)
          .map(_upperFirst)
          .join();
  _validateIdentifier(identifier, path);
  return identifier;
}

String _upperFirst(String value) =>
    '${value[0].toUpperCase()}${value.substring(1)}';

void _validateIdentifier(String identifier, String location) {
  if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(identifier) ||
      _reservedNames.contains(identifier)) {
    throw FormatException(
      '$location: "$identifier" is not a public Dart resource identifier '
      'or is reserved.',
    );
  }
}

String _relativePath(Object? value, String location) {
  if (value is! String ||
      value.isEmpty ||
      !RegExp(r'^[A-Za-z0-9_./-]+$').hasMatch(value) ||
      value.startsWith('/') ||
      value.contains(r'\') ||
      value.contains(':') ||
      value.contains('//') ||
      value.split('/').any((segment) => segment == '..' || segment == '.')) {
    throw FormatException('$location must be a relative project path: $value');
  }
  return value;
}

Map<String, Object?> _map(Object? value, String location) {
  if (value is! Map<Object?, Object?> ||
      value.keys.any((key) => key is! String)) {
    throw FormatException('$location must be an object with string keys.');
  }
  return {for (final entry in value.entries) entry.key! as String: entry.value};
}

bool _sameKeys(Iterable<String> first, Iterable<String> second) =>
    first.length == second.length && first.toSet().containsAll(second);

void _write(Directory root, String path, String contents) {
  File.fromUri(root.uri.resolve(path))
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);
}

Map<String, Object?> _readJson(File file) {
  if (!file.existsSync() || FileSystemEntity.isLinkSync(file.path)) {
    throw FormatException('JSON file is missing or a symlink: ${file.path}');
  }
  final source = file.readAsStringSync();
  final decoded = jsonDecode(source);
  // jsonDecode validates syntax but silently accepts duplicate object keys.
  final tokens = RegExp(r'"(?:[^"\\]|\\.)*"|[{}\[\]:,]')
      .allMatches(source)
      .map((match) => match[0]!)
      .toList();
  final objects = <Set<String>?>[];
  for (var index = 0; index < tokens.length; index++) {
    final token = tokens[index];
    if (token == '{') {
      objects.add(<String>{});
    } else if (token == '[') {
      objects.add(null);
    } else if (token == '}' || token == ']') {
      objects.removeLast();
    } else if (token.startsWith('"') &&
        index + 1 < tokens.length &&
        tokens[index + 1] == ':') {
      final key = jsonDecode(token) as String;
      if (!objects.last!.add(key)) {
        throw FormatException('${file.path}: duplicate JSON key "$key".');
      }
    }
  }
  return _map(decoded, file.path);
}

void _keys(Map<String, Object?> object, Set<String> allowed, String location) {
  final unknown = object.keys.where((key) => !allowed.contains(key));
  if (unknown.isNotEmpty) {
    throw FormatException(
      '$location: unsupported fields ${unknown.join(', ')}.',
    );
  }
}

/// Validates source catalogs, including their generated API and typed messages.
Map<String, Map<String, Object?>> validateLocalizationCatalogs(
  Directory project,
) {
  final configuration = _ResourceConfiguration.read(project);
  final catalogs = _readCatalogs(project, configuration);
  _compileCatalogs(catalogs, configuration);
  return catalogs;
}

Map<String, Map<String, Object?>> _readCatalogs(
  Directory project,
  _ResourceConfiguration configuration,
) {
  final directory = Directory.fromUri(
    project.uri.resolve(configuration.catalogDirectory),
  );
  final expected = configuration.locales
      .map((locale) => '$locale.json')
      .toSet();
  for (final entry in directory.listSync(followLinks: false)) {
    if (entry is! File || !expected.contains(entry.uri.pathSegments.last)) {
      throw FormatException(
        'Unexpected localization catalog: ${entry.path}. '
        'Catalog filenames must match configured locales.',
      );
    }
  }
  return {
    for (final locale in configuration.locales.toList()..sort())
      locale: _readJson(File.fromUri(directory.uri.resolve('$locale.json'))),
  };
}

final class _Message {
  new(this.text, this.parameters);
  final String text;
  final Map<String, Object?>? parameters;
}

Map<String, _Message> _flattenCatalog(Map<String, Object?> catalog) {
  final messages = <String, _Message>{};
  final classNames = <String, String>{};
  void visit(Map<String, Object?> group, List<String> path) {
    if (group.isEmpty) {
      throw const FormatException('Message groups must not be empty.');
    }
    final names = <String>{};
    for (final key in group.keys.toList()..sort()) {
      final parts = [...path, key];
      final location = parts.join('.');
      _validateIdentifier(key, location);
      if ({
        'localeName',
        'delegate',
        'localizationsDelegates',
        'supportedLocales',
        'forLocale',
      }.contains(key)) {
        throw FormatException('Reserved localization member: $location');
      }
      if (!names.add(key.toLowerCase())) {
        throw FormatException('Localization identifier collision: $location');
      }
      final value = group[key];
      if (value is String) {
        messages[location] = _Message(value, null);
        continue;
      }
      final object = _map(value, location);
      if (!object.containsKey('message')) {
        final className = parts.map(_upperFirst).join().toLowerCase();
        if (classNames.containsKey(className)) {
          throw FormatException(
            'Localization group type collision: '
            '$location and ${classNames[className]}',
          );
        }
        classNames[className] = location;
        visit(object, parts);
        continue;
      }
      _keys(object, {'message', 'placeholders'}, location);
      if (object['message'] is! String) {
        throw FormatException(
          '$location.message must be an ICU message string.',
        );
      }
      messages[location] = _Message(
        object['message']! as String,
        object['placeholders'] == null
            ? null
            : _map(object['placeholders'], location),
      );
    }
  }

  visit(catalog, []);
  return messages;
}

final class _CompiledCatalogs {
  new(this.expressions, this.parameters, this.intlSymbols);
  final Map<String, Map<String, String>> expressions;
  final Map<String, Map<String, Map<String, Object?>>> parameters;
  final Set<String> intlSymbols;
}

_CompiledCatalogs _compileCatalogs(
  Map<String, Map<String, Object?>> catalogs,
  _ResourceConfiguration configuration,
) {
  final flattened = {
    for (final entry in catalogs.entries)
      entry.key: _flattenCatalog(entry.value),
  };
  final template = flattened[configuration.fallback]!;
  final expressions = <String, Map<String, String>>{};
  final parameters = <String, Map<String, Map<String, Object?>>>{};
  final intlSymbols = <String>{};
  for (final entry in flattened.entries) {
    if (!_sameKeys(template.keys, entry.value.keys)) {
      throw FormatException(
        '${entry.key}: translation keys differ from ${configuration.fallback}.',
      );
    }
  }
  for (final entry in template.entries) {
    final metadata = <String, Map<String, Object?>>{};
    for (final parameter in (entry.value.parameters ?? {}).entries) {
      _validateIdentifier(parameter.key, entry.key);
      if (parameter.key == 'localeName') {
        throw FormatException(
          '${entry.key}: placeholder localeName conflicts '
          'with the active locale.',
        );
      }
      final options = _map(parameter.value, '${entry.key}.${parameter.key}');
      _keys(options, {'type', 'format'}, entry.key);
      if (!{'int', 'double', 'num', 'String'}.contains(options['type']) ||
          (options.containsKey('format') &&
              (options['format'] != 'decimalPattern' ||
                  options['type'] == 'String'))) {
        throw FormatException(
          '${entry.key}: declare metadata with an explicit '
          'String/int/double/num type '
          'and optional numeric decimalPattern format.',
        );
      }
      metadata[parameter.key] = options;
    }
    parameters[entry.key] = metadata;
    final translated = <String, String>{};
    // Compile the template first to diagnose undeclared arguments.
    final locales = [
      configuration.fallback,
      ...configuration.locales
          .where((locale) => locale != configuration.fallback)
          .toList()
        ..sort(),
    ];
    for (final locale in locales) {
      final message = flattened[locale]![entry.key]!;
      if (message.parameters != null) {
        if (!_sameKeys(metadata.keys, message.parameters!.keys)) {
          throw FormatException(
            '$locale.${entry.key}: placeholder names must match the fallback.',
          );
        }
        for (final parameter in message.parameters!.entries) {
          final options = _map(parameter.value, entry.key);
          _keys(options, {'type', 'format'}, entry.key);
          final expected = metadata[parameter.key]!;
          if (options['type'] != expected['type'] ||
              options['format'] != expected['format']) {
            throw FormatException(
              '$locale.${entry.key}: use a consistent explicit parameter type '
              'and format.',
            );
          }
        }
      }
      final compiler = _MessageCompiler(
        message.text,
        metadata,
        intlSymbols,
        '$locale.${entry.key}',
        isTemplate: locale == configuration.fallback,
      );
      translated[locale] = compiler.compile();
      if (!_sameKeys(compiler.used, metadata.keys)) {
        throw FormatException(
          '$locale.${entry.key}: placeholder names '
          'must match metadata exactly.',
        );
      }
    }
    expressions[entry.key] = translated;
  }
  return _CompiledCatalogs(expressions, parameters, intlSymbols);
}

// A small ICU subset: typed interpolation, plural/select branches and quoting.
// Locale plural rules and number formatting remain owned by the official intl.
final class _MessageCompiler {
  new(
    this.source,
    this.parameters,
    this.intlSymbols,
    this.location, {
    required this.isTemplate,
  });
  final String source;
  final Map<String, Map<String, Object?>> parameters;
  final Set<String> intlSymbols;
  final String location;
  final bool isTemplate;
  final used = <String>{};
  int offset = 0;

  Never fail(String reason) => throw FormatException(
    '$location: malformed ICU message at $offset: $reason',
  );

  String compile() {
    final expression = _text();
    if (offset != source.length) fail('unexpected closing brace');
    return expression;
  }

  String _text({String? plural}) {
    final expressions = <({String code, bool argument})>[];
    var literal = StringBuffer();
    void flush() {
      if (literal.isNotEmpty) {
        expressions.add((
          code: _dartString(literal.toString()),
          argument: false,
        ));
      }
      literal = StringBuffer();
    }

    while (offset < source.length && source[offset] != '}') {
      final character = source[offset++];
      if (character == '{') {
        flush();
        expressions.add((code: _argument(plural), argument: true));
      } else if (character == "'" &&
          offset < source.length &&
          source[offset] == "'") {
        literal.write("'");
        offset++;
      } else if (character == "'" &&
          offset < source.length &&
          '{}#'.contains(source[offset])) {
        var closed = false;
        while (offset < source.length) {
          final quoted = source[offset++];
          if (quoted == "'") {
            if (offset < source.length && source[offset] == "'") {
              literal.write("'");
              offset++;
            } else {
              closed = true;
              break;
            }
          } else {
            literal.write(quoted);
          }
        }
        if (!closed) fail('unterminated quoted text');
      } else if (character == '#' && plural != null) {
        flush();
        intlSymbols.add('NumberFormat');
        expressions.add((
          code: 'NumberFormat.decimalPattern(localeName).format($plural)',
          argument: true,
        ));
      } else {
        literal.write(character);
      }
    }
    flush();
    if (expressions.isEmpty) return "''";
    if (expressions.length == 1) return expressions.single.code;
    return expressions
        .map((part) => part.argument ? "'\${${part.code}}'" : part.code)
        .join('\n');
  }

  String _token() {
    final start = offset;
    while (offset < source.length && !'{},'.contains(source[offset])) {
      offset++;
    }
    return source.substring(start, offset).trim();
  }

  void _expect(String character) {
    if (offset >= source.length || source[offset] != character) {
      fail('expected $character');
    }
    offset++;
  }

  String _argument(String? enclosingPlural) {
    final name = _token();
    if (offset >= source.length) fail('unclosed argument');
    final options = parameters[name];
    if (options == null) {
      final reason = isTemplate
          ? 'declare metadata for'
          : 'inconsistent placeholder names:';
      throw FormatException('$location: $reason $name.');
    }
    used.add(name);
    if (source[offset] == '}') {
      offset++;
      if (options['format'] == 'decimalPattern') {
        intlSymbols.add('NumberFormat');
        return 'NumberFormat.decimalPattern(localeName).format($name)';
      }
      return options['type'] == 'String' ? name : '$name.toString()';
    }
    _expect(',');
    final kind = _token();
    if (!{'plural', 'select'}.contains(kind)) {
      fail('unsupported argument kind $kind');
    }
    if ((kind == 'plural' && options['type'] == 'String') ||
        (kind == 'select' && options['type'] != 'String')) {
      final type = kind == 'plural' ? 'numeric' : 'String';
      fail('$kind requires a $type placeholder');
    }
    _expect(',');
    final branches = <String, String>{};
    while (true) {
      while (offset < source.length && source[offset].trim().isEmpty) {
        offset++;
      }
      if (offset >= source.length) fail('unclosed $kind argument');
      if (source[offset] == '}') {
        offset++;
        break;
      }
      final selector = _token();
      if (selector.isEmpty || branches.containsKey(selector)) {
        fail('empty or duplicate selector $selector');
      }
      if (kind == 'plural' &&
          !{'zero', 'one', 'two', 'few', 'many', 'other'}.contains(selector) &&
          !RegExp(r'^=[0-9]+$').hasMatch(selector)) {
        fail('unsupported plural selector $selector');
      }
      _expect('{');
      branches[selector] = _text(
        plural: kind == 'plural' ? name : enclosingPlural,
      );
      _expect('}');
    }
    final other = branches.remove('other');
    if (other == null) fail('$kind requires an other branch');
    if (kind == 'select') {
      final cases = branches.entries
          .map((entry) => '${_dartString(entry.key)} => ${entry.value},')
          .join();
      return 'switch ($name) { $cases _ => $other }';
    }
    intlSymbols.add('Intl');
    final exact = branches.entries.where((entry) => entry.key.startsWith('='));
    final categories = branches.entries.where(
      (entry) => !entry.key.startsWith('='),
    );
    final exactCases = exact
        .map(
          (entry) => '$name == ${entry.key.substring(1)} ? ${entry.value} : ',
        )
        .join();
    final arguments = categories
        .map((entry) => '${entry.key}: ${entry.value}, ')
        .join();
    return '${exactCases}Intl.plural($name, $arguments'
        'other: $other, locale: localeName)';
  }
}

String _dartString(String text) {
  if (text.isEmpty) return "''";
  final chunks = <String>[];
  final words = RegExp(r'\S+\s*|\s+')
      .allMatches(text)
      .map((match) => match[0]!);
  var chunk = StringBuffer();
  final parts = <String>[];
  for (final word in words) {
    if (chunk.isNotEmpty && chunk.length + word.length > 48) {
      parts.add(chunk.toString());
      chunk = StringBuffer();
    }
    chunk.write(word);
  }
  if (chunk.isNotEmpty) parts.add(chunk.toString());
  for (final chunk in parts) {
    final encoded = jsonEncode(chunk);
    final escaped = encoded
        .substring(1, encoded.length - 1)
        .replaceAll(r'$', r'\$');
    if (chunk.contains("'") && !chunk.contains('"')) {
      chunks.add('"$escaped"');
    } else {
      final single = escaped.replaceAll(r'\"', '"').replaceAll("'", r"\'");
      chunks.add("'$single'");
    }
  }
  return chunks.join('\n');
}

String _localeExpression(String locale) {
  final parts = locale.split('_');
  final script = parts.length > 1 && parts[1].length == 4 ? parts[1] : null;
  final country = parts.length > (script == null ? 1 : 2) ? parts.last : null;
  return 'Locale.fromSubtags(languageCode: ${_dartString(parts.first)}'
      '${script == null ? '' : ', scriptCode: ${_dartString(script)}'}'
      '${country == null ? '' : ', countryCode: ${_dartString(country)}'})';
}

Map<String, String> _generateMessageSources(
  Directory project,
  _ResourceConfiguration configuration,
) {
  final compiled = _compileCatalogs(
    _readCatalogs(project, configuration),
    configuration,
  );
  final classes = <String, String>{'': 'AppLocalization'};
  for (final path in compiled.expressions.keys) {
    final parts = path.split('.');
    for (var length = 1; length < parts.length; length++) {
      final group = parts.take(length).join('.');
      classes[group] =
          'App${parts.take(length).map(_upperFirst).join()}Messages';
    }
  }
  final locales = [
    configuration.fallback,
    ...(configuration.locales
        .where((locale) => locale != configuration.fallback)
        .toList()
      ..sort()),
  ];
  final source = StringBuffer(_generatedHeader)
    ..writeln("import 'package:flutter/foundation.dart';")
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln(
      "import 'package:flutter_localizations/flutter_localizations.dart';",
    );
  if (compiled.intlSymbols.isNotEmpty) {
    source.writeln(
      "import 'package:intl/intl.dart' "
      "show ${(compiled.intlSymbols.toList()..sort()).join(', ')};",
    );
  }
  for (final group in classes.entries) {
    final root = group.key.isEmpty;
    source
      ..writeln('/// Typed messages resolved for the active locale.')
      ..writeln('final class ${group.value} {')
      ..writeln('const new _(this.localeName);');
    if (root) {
      source.writeln('''
/// Resolves previews and regional locales using Flutter's fallback rules.
factory forLocale(Locale locale) => AppLocalization._(
  basicLocaleListResolution([locale], supportedLocales).toString(),
);

''');
    }
    source
      ..writeln('/// The resolved supported locale identifier.')
      ..writeln('final String localeName;');
    if (root) {
      source.writeln('''
/// Registers this widget as dependent on the active language.
static AppLocalization of(BuildContext context) =>
  Localizations.of<AppLocalization>(context, AppLocalization)!;

/// Loads application messages synchronously from the compiled catalogs.
static const LocalizationsDelegate<AppLocalization> delegate =
  _AppLocalizationDelegate();

/// Preserves Flutter's Material, Cupertino and accessibility translations.
static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

/// The fallback comes first for Flutter's unsupported-locale resolution.
static const supportedLocales = <Locale>[
${locales.map(_localeExpression).join(',')},
];
''');
    }
    final prefix = root ? '' : '${group.key}.';
    for (final child in classes.entries) {
      if (child.key.isEmpty || !child.key.startsWith(prefix)) continue;
      final name = child.key.substring(prefix.length);
      if (name.contains('.')) continue;
      source
        ..writeln('/// Messages in the $name catalog group.')
        ..writeln('${child.value} get $name => ${child.value}._(localeName);');
    }
    for (final message in compiled.expressions.entries) {
      if (!message.key.startsWith(prefix)) continue;
      final name = message.key.substring(prefix.length);
      if (name.contains('.')) continue;
      final parameters = compiled.parameters[message.key]!;
      final arguments = parameters.entries
          .map((entry) => 'required ${entry.value['type']} ${entry.key}')
          .join(', ');
      final signature = parameters.isEmpty
          ? 'get $name'
          : '$name({$arguments})';
      source
        ..writeln('/// Catalog message: ${message.key}.')
        ..writeln('String $signature => switch (localeName) {');
      for (final translation in message.value.entries) {
        if (translation.key == configuration.fallback) continue;
        source.writeln(
          '${_dartString(translation.key)} => ${translation.value},',
        );
      }
      source
        ..writeln('_ => ${message.value[configuration.fallback]},')
        ..writeln('};');
    }
    source.writeln('}');
  }
  source.writeln('''
final class _AppLocalizationDelegate
  extends LocalizationsDelegate<AppLocalization> {
  const new();
  @override
  bool isSupported(Locale locale) => AppLocalization.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );
  @override
  Future<AppLocalization> load(Locale locale) =>
    SynchronousFuture(AppLocalization.forLocale(locale));
  @override
  bool shouldReload(_AppLocalizationDelegate old) => false;
}
''');
  return {
    configuration.messageEntryPoint:
        '$_generatedHeader'
        "export '${configuration.messageOutput.split('/').last}' "
        "show ${classes.values.join(', ')};\n",
    configuration.messageOutput: source.toString(),
  };
}

void _rejectLinks(Directory project, String path) {
  var directory = project;
  for (final segment in path.split('/')) {
    final child = directory.uri.resolve(segment);
    if (FileSystemEntity.isLinkSync(File.fromUri(child).path)) {
      throw FormatException('Resource paths must not traverse symlinks: $path');
    }
    directory = Directory.fromUri(child);
  }
}
