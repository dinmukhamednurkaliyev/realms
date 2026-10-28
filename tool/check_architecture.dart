import 'dart:io';

// Checks handwritten import/export directives without adding a parser dependency.
void main() {
  final root = Directory.current.uri;
  final packageName = RegExp(
    r'^name:\s*(\S+)',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
  final problems = <String>[];
  final graph = <String, Set<String>>{};
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
  final quotedUris = RegExp('''['"]([^'"]+)['"]''');

  for (final source in sources) {
    final sourcePath = source.uri.path.substring(root.path.length);
    if (_isGenerated(sourcePath)) continue;

    final module = _moduleOf(sourcePath);
    final isTest = sourcePath.startsWith('test/');
    final isEngine = sourcePath.startsWith('lib/game/engine/');
    final isMode = sourcePath.startsWith('lib/game/modes/');
    final entryPoint = 'lib/$module/$module.dart';
    final exportedNames = <String>{};
    final dependencies = graph[sourcePath] = <String>{};
    final contents = source.readAsStringSync();

    void report(String message) => problems.add('$sourcePath: $message');

    for (final directive in directives.allMatches(contents)) {
      final isExport = directive.group(1) == 'export';
      final body = directive.group(2)!;
      final prefix = RegExp(r'\bas\s+(\w+)').firstMatch(body)?.group(1);

      if (isExport) {
        if (sourcePath != entryPoint) {
          report('Only feature entry points may export libraries.');
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
          }
        }
      }

      // All URI alternatives in conditional directives must obey the boundary.
      for (final quotedUri in quotedUris.allMatches(body)) {
        final uri = quotedUri.group(1)!;
        if (uri.startsWith('dart:')) {
          if ((isEngine || isMode) && uri == 'dart:ui') {
            report('Engine and modes must not depend on Flutter.');
          }
          continue;
        }
        if (uri.startsWith('package:') &&
            !uri.startsWith('package:$packageName/')) {
          if (isEngine || isMode) {
            report('Engine and modes may only import Dart and game internals.');
          }
          continue;
        }

        final isPackageImport = uri.startsWith('package:$packageName/');
        final targetUri = isPackageImport
            ? root.resolve(
                'lib/${uri.substring('package:$packageName/'.length)}',
              )
            : source.uri.resolve(uri);
        if (!targetUri.path.startsWith(root.resolve('lib/').path)) {
          report('Project dependencies must resolve inside lib/: $uri.');
          continue;
        }
        final targetPath = targetUri.path.substring(root.path.length);
        if (!File.fromUri(targetUri).existsSync()) {
          report('Missing dependency: $targetPath.');
        }
        dependencies.add(targetPath);
        final targetModule = _moduleOf(targetPath);
        final targetEntry = 'lib/$targetModule/$targetModule.dart';

        if (isEngine && !targetPath.startsWith('lib/game/engine/')) {
          report('Engine dependencies must stay inside engine/.');
        }
        if (isMode &&
            !targetPath.startsWith('lib/game/engine/') &&
            !targetPath.startsWith('lib/game/modes/')) {
          report('Modes may depend only on engine/ and modes/.');
        }
        if (!isTest && module == targetModule && targetPath == targetEntry) {
          report('Internal libraries must not import their own entry point.');
        }
        if (isExport && module != targetModule) {
          report('A feature may only export its own libraries.');
        }

        if (!isTest && module == targetModule) {
          if (isPackageImport) {
            report('Use a relative import within the $module feature: $uri.');
          }
          continue;
        }

        // Generated strings are a shared leaf, not application composition.
        final isLocalization =
            targetPath == 'lib/app/localization/localization.dart' &&
            (module == 'home' ||
                sourcePath.startsWith('lib/game/screens/') ||
                (isTest && module == 'app'));
        if (isLocalization) {
          if (!isPackageImport || prefix != 'localization') {
            report('Import shared strings with the localization prefix.');
          }
          continue;
        }
        if (isTest && module == targetModule && targetPath != targetEntry) {
          if (!isPackageImport || prefix == null) {
            report('Intentional internal tests use prefixed package imports.');
          }
          continue;
        }
        if (!isPackageImport ||
            targetPath != targetEntry ||
            prefix != targetModule) {
          report(
            'Consume $targetModule through its prefixed public entry point.',
          );
        }
        if (!isTest && module == 'game' && targetModule != 'game') {
          report('Game must not depend on App or Home composition.');
        }
        if (!isTest && module == 'home' && targetModule == 'app') {
          report('Home must not depend on App composition.');
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
  final segments = path.split('/');
  return segments.length > 2 && {'app', 'game', 'home'}.contains(segments[1])
      ? segments[1]
      : null;
}

bool _isGenerated(String path) =>
    path.startsWith('lib/app/localization/') && path.endsWith('.dart');
