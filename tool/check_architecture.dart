import 'dart:io';

// Logical ownership is independent of directory depth or import syntax.
const Map<String, ({String entryPoint, Set<String> dependencies})> _modules = {
  'app': (
    entryPoint: 'lib/app/app.dart',
    dependencies: {'app/appearance', 'app/localization', 'game', 'home'},
  ),
  'app/appearance': (
    entryPoint: 'lib/app/appearance/appearance.dart',
    dependencies: <String>{},
  ),
  'app/localization': (
    entryPoint: 'lib/app/localization/localization.dart',
    dependencies: <String>{},
  ),
  'game': (
    entryPoint: 'lib/game/game.dart',
    dependencies: {'game/engine', 'game/modes', 'app/localization'},
  ),
  'game/engine': (
    entryPoint: 'lib/game/engine/engine.dart',
    dependencies: <String>{},
  ),
  'game/modes': (
    entryPoint: 'lib/game/modes/modes.dart',
    dependencies: {'game/engine'},
  ),
  'home': (
    entryPoint: 'lib/home/home.dart',
    dependencies: {'app/localization'},
  ),
};

// Checks formatted, handwritten directives without a parser dependency.
void main() {
  final root = Directory.current.uri;
  final packageName = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
  final problems = <String>[];
  final graph = <String, Set<String>>{};
  final publicOwners = <String, String>{};
  final sources = [
    for (final directory in ['lib', 'test'])
      ...Directory(directory)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.absolute),
  ]..sort((first, second) => first.path.compareTo(second.path));
  final directives = RegExp(
    r'''^\s*(import|export)\s+(['"][\s\S]*?);''',
    multiLine: true,
  );
  final libraryUris = RegExp(r'''(?:^|if\s*\([^)]*\)\s*)(['"])([^'"]+)\1''');

  if (File('lib/realms.dart').existsSync()) {
    problems.add('Use module entry points, not a global realms.dart barrel.');
  }
  for (final module in _modules.values) {
    if (!File(module.entryPoint).existsSync()) {
      problems.add('Missing module entry point: ${module.entryPoint}.');
    }
  }

  for (final source in sources) {
    final sourcePath = source.uri.path.substring(root.path.length);
    if (_isGenerated(sourcePath)) continue;

    final moduleName = _moduleOf(sourcePath);
    final module = _modules[moduleName];
    final isTest = sourcePath.startsWith('test/');
    final isDomain =
        !isTest && (moduleName == 'game/engine' || moduleName == 'game/modes');
    final dependencies = graph[sourcePath] = <String>{};
    final exportedNames = <String>{};

    void report(String message) => problems.add('$sourcePath: $message');

    if (!isTest && module == null && sourcePath != 'lib/main.dart') {
      report('Implementation libraries must belong to a logical module.');
    }

    for (final directive in directives.allMatches(source.readAsStringSync())) {
      final isExport = directive.group(1) == 'export';
      final body = directive.group(2)!;

      if (RegExp(r'\bas\s+\w+').hasMatch(body)) {
        report('Use descriptive declarations and unprefixed imports.');
      }
      if (isExport) {
        if (sourcePath != module?.entryPoint) {
          report('Only module entry points may export libraries.');
        }
        final shown = RegExp(r'\bshow\s+([\w,\s]+)$').firstMatch(body);
        if (shown == null) {
          report('Exports must use an explicit show list.');
        } else {
          for (final name
              in shown.group(1)!.split(',').map((name) => name.trim())) {
            if (!exportedNames.add(name)) {
              report('Duplicate public export: $name.');
            }
            final owner = publicOwners[name];
            if (owner != null && owner != sourcePath) {
              report('$name already belongs to the public API in $owner.');
            }
            publicOwners[name] = sourcePath;
          }
        }
      }

      // Check each conditional URI, excluding strings in its condition.
      for (final libraryUri in libraryUris.allMatches(body)) {
        final uri = libraryUri.group(2)!;
        if (uri.startsWith('dart:')) {
          if (isDomain && uri.startsWith('dart:ui')) {
            report('Engine and modes must not depend on Flutter.');
          }
          if (isExport) {
            report('Only declarations owned by this module may be exported.');
          }
          continue;
        }
        if (uri.startsWith('package:') &&
            !uri.startsWith('package:$packageName/')) {
          if (isDomain) {
            report('Engine and modes may only import Dart and game internals.');
          }
          if (isExport) {
            report('Only declarations owned by this module may be exported.');
          }
          continue;
        }

        final isPackageImport = uri.startsWith('package:$packageName/');
        final targetUri = isPackageImport
            ? root.resolve(
                'lib/${uri.substring('package:$packageName/'.length)}',
              )
            : source.uri.resolve(uri);
        if (targetUri.scheme != 'file' ||
            !targetUri.path.startsWith(root.resolve('lib/').path)) {
          report('Project dependencies must resolve inside lib/: $uri.');
          continue;
        }
        final targetPath = targetUri.path.substring(root.path.length);
        if (!File.fromUri(targetUri).existsSync()) {
          report('Missing dependency: $targetPath.');
        }
        dependencies.add(targetPath);
        final targetModuleName = _moduleOf(targetPath);
        final targetModule = _modules[targetModuleName];
        if (targetModule == null) {
          report('Dependency has no owning module: $targetPath.');
          continue;
        }
        final isSameModule = moduleName == targetModuleName;

        if (isExport && !isSameModule) {
          report('Only declarations owned by this module may be exported.');
        }
        if (isTest) {
          if (!isPackageImport) report('Tests use package imports.');
          if (!isSameModule && targetPath != targetModule.entryPoint) {
            report(
              'Tests access other modules through their public entry points.',
            );
          }
          continue;
        }
        if (isSameModule) {
          if (targetPath == module?.entryPoint) {
            report(
              'Implementations must not import their own module entry point.',
            );
          }
          if (Uri.parse(uri).hasScheme) {
            report('Use relative imports within a module.');
          }
          continue;
        }
        if (!isPackageImport || targetPath != targetModule.entryPoint) {
          report(
            'Consume $targetModuleName through '
            'package:$packageName/${targetModule.entryPoint.substring(4)}.',
          );
        }
        if (module != null && !module.dependencies.contains(targetModuleName)) {
          report('Forbidden dependency: $targetModuleName.');
        }
      }
    }
  }

  final visited = <String>{};
  void visit(String source, List<String> ancestors) {
    if (ancestors.contains(source)) {
      problems.add('Dependency cycle: ${[...ancestors, source].join(' -> ')}');
      return;
    }
    if (!visited.add(source)) return;
    for (final target in graph[source] ?? <String>{}) {
      visit(target, [...ancestors, source]);
    }
  }

  for (final source in graph.keys) {
    visit(source, []);
  }
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln('Architecture checks passed for ${graph.length} libraries.');
}

String? _moduleOf(String path) {
  final relativePath = path.substring(path.indexOf('/') + 1);
  String? owner;
  for (final module in _modules.keys) {
    if (relativePath.startsWith('$module/') &&
        (owner == null || module.length > owner.length)) {
      owner = module;
    }
  }
  return owner;
}

bool _isGenerated(String path) =>
    path.startsWith('lib/app/localization/') && path.endsWith('.dart');
