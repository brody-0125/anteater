import 'dart:io';

import 'package:anteater/frontend/source_loader.dart';
import 'package:anteater/server/code_actions_provider.dart';
import 'package:anteater/server/diagnostics_provider.dart';
import 'package:anteater/server/hover_provider.dart';
import 'package:anteater/server/language_server.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('Diagnostic', () {
    test('creates diagnostic with required fields', () {
      const diagnostic = Diagnostic(
        message: 'Test message',
        severity: DiagnosticSeverity.warning,
        range: Range.zero,
        source: 'anteater',
      );

      expect(diagnostic.message, equals('Test message'));
      expect(diagnostic.severity, equals(DiagnosticSeverity.warning));
      expect(diagnostic.source, equals('anteater'));
      expect(diagnostic.code, isNull);
    });

    test('creates diagnostic with optional code', () {
      const diagnostic = Diagnostic(
        message: 'Test message',
        severity: DiagnosticSeverity.error,
        range: Range.zero,
        source: 'anteater',
        code: 'test_code',
      );

      expect(diagnostic.code, equals('test_code'));
    });

    test('toJson includes all fields', () {
      const diagnostic = Diagnostic(
        message: 'Test message',
        severity: DiagnosticSeverity.warning,
        range: Range.zero,
        source: 'anteater',
        code: 'test_code',
      );

      final json = diagnostic.toJson();
      expect(json['message'], equals('Test message'));
      expect(json['severity'], equals(DiagnosticSeverity.warning.index));
      expect(json['source'], equals('anteater'));
      expect(json['code'], equals('test_code'));
    });

    test('toString formats severity and message', () {
      const diagnostic = Diagnostic(
        message: 'Test message',
        severity: DiagnosticSeverity.error,
        range: Range.zero,
        source: 'anteater',
      );

      expect(diagnostic.toString(), contains('error'));
      expect(diagnostic.toString(), contains('Test message'));
    });
  });

  group('Range', () {
    test('zero creates zero range', () {
      expect(Range.zero.start.line, equals(0));
      expect(Range.zero.start.character, equals(0));
      expect(Range.zero.end.line, equals(0));
      expect(Range.zero.end.character, equals(0));
    });

    test('toJson returns correct structure', () {
      const range = Range(
        start: Position(line: 1, character: 5),
        end: Position(line: 2, character: 10),
      );

      final json = range.toJson();
      final start = json['start'] as Map<String, dynamic>;
      final end = json['end'] as Map<String, dynamic>;
      expect(start['line'], equals(1));
      expect(start['character'], equals(5));
      expect(end['line'], equals(2));
      expect(end['character'], equals(10));
    });
  });

  group('Position', () {
    test('toJson returns line and character', () {
      const position = Position(line: 5, character: 10);

      final json = position.toJson();
      expect(json['line'], equals(5));
      expect(json['character'], equals(10));
    });
  });

  group('DiagnosticSeverity', () {
    test('has correct ordering', () {
      expect(DiagnosticSeverity.error.index, lessThan(DiagnosticSeverity.warning.index));
      expect(DiagnosticSeverity.warning.index, lessThan(DiagnosticSeverity.info.index));
      expect(DiagnosticSeverity.info.index, lessThan(DiagnosticSeverity.hint.index));
    });
  });

  group('CodeActionsProvider', () {
    late CodeActionsProvider provider;

    setUp(() {
      provider = CodeActionsProvider();
    });

    test('returns empty list for no diagnostics', () async {
      final actions = await provider.getCodeActions(
        filePath: '/test/file.dart',
        range: Range.zero,
        diagnostics: [],
      );

      expect(actions, isEmpty);
    });

    test('returns extract method action for high cyclomatic complexity', () async {
      const diagnostic = Diagnostic(
        message: 'High complexity',
        severity: DiagnosticSeverity.warning,
        range: Range.zero,
        source: 'anteater',
        code: 'high_cyclomatic_complexity',
      );

      final actions = await provider.getCodeActions(
        filePath: '/test/file.dart',
        range: Range.zero,
        diagnostics: [diagnostic],
      );

      expect(actions.length, equals(2));
      expect(actions[0].title, contains('Extract'));
      expect(actions[0].kind, equals(CodeActionKind.refactorExtract));
    });

    test('returns null check action for potential null dereference', () async {
      const diagnostic = Diagnostic(
        message: 'Potential null',
        severity: DiagnosticSeverity.warning,
        range: Range.zero,
        source: 'anteater',
        code: 'potential_null_dereference',
      );

      final actions = await provider.getCodeActions(
        filePath: '/test/file.dart',
        range: Range.zero,
        diagnostics: [diagnostic],
      );

      expect(actions.length, equals(2));
      expect(actions[0].title, contains('null check'));
      expect(actions[0].isPreferred, isTrue);
      expect(actions[0].kind, equals(CodeActionKind.quickfix));
    });

    test('returns bounds check action for bounds violation', () async {
      const diagnostic = Diagnostic(
        message: 'Bounds violation',
        severity: DiagnosticSeverity.warning,
        range: Range.zero,
        source: 'anteater',
        code: 'potential_bounds_violation',
      );

      final actions = await provider.getCodeActions(
        filePath: '/test/file.dart',
        range: Range.zero,
        diagnostics: [diagnostic],
      );

      expect(actions.length, equals(2));
      expect(actions[0].title, contains('bounds check'));
      expect(actions[0].isPreferred, isTrue);
    });

    test('returns actions for multiple diagnostics', () async {
      final diagnostics = [
        const Diagnostic(
          message: 'Complexity',
          severity: DiagnosticSeverity.warning,
          range: Range.zero,
          source: 'anteater',
          code: 'high_cyclomatic_complexity',
        ),
        const Diagnostic(
          message: 'Too long',
          severity: DiagnosticSeverity.info,
          range: Range.zero,
          source: 'anteater',
          code: 'function_too_long',
        ),
      ];

      final actions = await provider.getCodeActions(
        filePath: '/test/file.dart',
        range: Range.zero,
        diagnostics: diagnostics,
      );

      expect(actions.length, equals(4)); // 2 for each diagnostic
    });
  });

  group('CodeAction', () {
    test('toJson includes all fields', () {
      const diagnostic = Diagnostic(
        message: 'Test',
        severity: DiagnosticSeverity.warning,
        range: Range.zero,
        source: 'anteater',
      );

      const action = CodeAction(
        title: 'Fix it',
        kind: CodeActionKind.quickfix,
        diagnostic: diagnostic,
        isPreferred: true,
      );

      final json = action.toJson();
      expect(json['title'], equals('Fix it'));
      expect(json['kind'], equals('quickfix'));
      expect(json['isPreferred'], isTrue);
      expect(json['diagnostics'], isNotNull);
    });

    test('toJson includes command when present', () {
      const action = CodeAction(
        title: 'Extract',
        kind: CodeActionKind.refactorExtract,
        command: CodeCommand(
          title: 'Extract Method',
          command: 'anteater.extractMethod',
          arguments: ['/test.dart', Range.zero],
        ),
      );

      final json = action.toJson();
      expect(json['command'], isNotNull);
      final command = json['command'] as Map<String, dynamic>;
      expect(command['command'], equals('anteater.extractMethod'));
    });
  });

  group('CodeActionKind', () {
    test('has correct string values', () {
      expect(CodeActionKind.quickfix.value, equals('quickfix'));
      expect(CodeActionKind.refactor.value, equals('refactor'));
      expect(CodeActionKind.refactorExtract.value, equals('refactor.extract'));
      expect(CodeActionKind.refactorInline.value, equals('refactor.inline'));
      expect(CodeActionKind.refactorRewrite.value, equals('refactor.rewrite'));
      expect(CodeActionKind.source.value, equals('source'));
      expect(
        CodeActionKind.sourceOrganizeImports.value,
        equals('source.organizeImports'),
      );
    });
  });

  group('TextEdit', () {
    test('toJson returns range and newText', () {
      const edit = TextEdit(
        range: Range(
          start: Position(line: 1, character: 0),
          end: Position(line: 1, character: 10),
        ),
        newText: 'replacement',
      );

      final json = edit.toJson();
      expect(json['newText'], equals('replacement'));
      expect(json['range'], isNotNull);
    });
  });

  group('CodeCommand', () {
    test('toJson returns title and command', () {
      const command = CodeCommand(
        title: 'Run Test',
        command: 'anteater.runTest',
      );

      final json = command.toJson();
      expect(json['title'], equals('Run Test'));
      expect(json['command'], equals('anteater.runTest'));
      expect(json.containsKey('arguments'), isFalse);
    });

    test('toJson includes arguments when present', () {
      const command = CodeCommand(
        title: 'Run Test',
        command: 'anteater.runTest',
        arguments: ['arg1', 'arg2'],
      );

      final json = command.toJson();
      expect(json['arguments'], equals(['arg1', 'arg2']));
    });
  });

  group('Hover', () {
    test('toJson returns contents and range', () {
      const hover = Hover(
        contents: HoverContents(
          kind: MarkupKind.markdown,
          value: '**Bold** text',
        ),
        range: Range.zero,
      );

      final json = hover.toJson();
      expect(json['contents'], isNotNull);
      expect(json['range'], isNotNull);
    });

    test('toJson excludes range when null', () {
      const hover = Hover(
        contents: HoverContents(
          kind: MarkupKind.plaintext,
          value: 'Plain text',
        ),
      );

      final json = hover.toJson();
      expect(json['contents'], isNotNull);
      expect(json.containsKey('range'), isFalse);
    });
  });

  group('HoverContents', () {
    test('toJson returns kind and value', () {
      const contents = HoverContents(
        kind: MarkupKind.markdown,
        value: '# Heading',
      );

      final json = contents.toJson();
      expect(json['kind'], equals('markdown'));
      expect(json['value'], equals('# Heading'));
    });
  });

  group('MarkupKind', () {
    test('has correct string values', () {
      expect(MarkupKind.plaintext.value, equals('plaintext'));
      expect(MarkupKind.markdown.value, equals('markdown'));
    });
  });

  group('DiagnosticThresholds', () {
    test('has sensible defaults', () {
      const thresholds = DiagnosticThresholds();

      expect(thresholds.cyclomaticComplexity, equals(20));
      expect(thresholds.cognitiveComplexity, equals(15));
      expect(thresholds.maintainabilityIndex, equals(50.0));
      expect(thresholds.linesOfCode, equals(100));
      expect(thresholds.parameters, equals(4));
    });

    test('allows custom values', () {
      const thresholds = DiagnosticThresholds(
        cyclomaticComplexity: 10,
        cognitiveComplexity: 8,
        maintainabilityIndex: 70.0,
        linesOfCode: 50,
        parameters: 3,
      );

      expect(thresholds.cyclomaticComplexity, equals(10));
      expect(thresholds.cognitiveComplexity, equals(8));
      expect(thresholds.maintainabilityIndex, equals(70.0));
      expect(thresholds.linesOfCode, equals(50));
      expect(thresholds.parameters, equals(3));
    });
  });

  group('ProjectAnalysisResult', () {
    test('calculates totalDiagnostics correctly', () {
      const result = ProjectAnalysisResult(
        fileCount: 2,
        diagnostics: {
          '/file1.dart': [
            Diagnostic(
              message: 'Error 1',
              severity: DiagnosticSeverity.error,
              range: Range.zero,
              source: 'anteater',
            ),
          ],
          '/file2.dart': [
            Diagnostic(
              message: 'Warning 1',
              severity: DiagnosticSeverity.warning,
              range: Range.zero,
              source: 'anteater',
            ),
            Diagnostic(
              message: 'Warning 2',
              severity: DiagnosticSeverity.warning,
              range: Range.zero,
              source: 'anteater',
            ),
          ],
        },
      );

      expect(result.totalDiagnostics, equals(3));
    });

    test('counts errors correctly', () {
      const result = ProjectAnalysisResult(
        fileCount: 1,
        diagnostics: {
          '/file.dart': [
            Diagnostic(
              message: 'Error',
              severity: DiagnosticSeverity.error,
              range: Range.zero,
              source: 'anteater',
            ),
            Diagnostic(
              message: 'Warning',
              severity: DiagnosticSeverity.warning,
              range: Range.zero,
              source: 'anteater',
            ),
          ],
        },
      );

      expect(result.errorCount, equals(1));
      expect(result.warningCount, equals(1));
    });

    test('toString formats correctly', () {
      const result = ProjectAnalysisResult(
        fileCount: 5,
        diagnostics: {},
      );

      final str = result.toString();
      expect(str, contains('files: 5'));
      expect(str, contains('diagnostics: 0'));
    });
  });

  // ===========================================================================
  // Integration Tests - Real File Analysis
  // ===========================================================================

  group('AnteaterLanguageServer Integration', () {
    late Directory tempDir;
    late String tempPath;
    late AnteaterLanguageServer server;
    bool serverInitialized = false;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anteater_server_test_');
      tempPath = tempDir.path;
      server = AnteaterLanguageServer(tempPath);
      serverInitialized = false;
    });

    tearDown(() async {
      if (serverInitialized) {
        await server.shutdown();
      }
      tempDir.deleteSync(recursive: true);
    });

    test('throws StateError when not initialized', () async {
      final dartFile = File(path.join(tempPath, 'test.dart'));
      dartFile.writeAsStringSync('void main() {}');

      expect(
        () => server.analyzeFile(dartFile.path),
        throwsA(isA<StateError>()),
      );
      // Don't mark as initialized since it should fail
    });

    test('analyzes simple file without diagnostics', () async {
      final dartFile = File(path.join(tempPath, 'simple.dart'));
      dartFile.writeAsStringSync('''
void main() {
  print('Hello');
}
''');

      await server.initialize();
      serverInitialized = true;
      final diagnostics = await server.analyzeFile(dartFile.path);

      expect(diagnostics, isEmpty);
    });

    test('detects high cyclomatic complexity', () async {
      final dartFile = File(path.join(tempPath, 'complex.dart'));
      // Generate a function with CC > 20 (threshold)
      // Each if/else-if adds 1 to CC, so we need at least 21 branches
      dartFile.writeAsStringSync('''
int complexFunction(int x) {
  if (x == 1) return 1;
  else if (x == 2) return 2;
  else if (x == 3) return 3;
  else if (x == 4) return 4;
  else if (x == 5) return 5;
  else if (x == 6) return 6;
  else if (x == 7) return 7;
  else if (x == 8) return 8;
  else if (x == 9) return 9;
  else if (x == 10) return 10;
  else if (x == 11) return 11;
  else if (x == 12) return 12;
  else if (x == 13) return 13;
  else if (x == 14) return 14;
  else if (x == 15) return 15;
  else if (x == 16) return 16;
  else if (x == 17) return 17;
  else if (x == 18) return 18;
  else if (x == 19) return 19;
  else if (x == 20) return 20;
  else if (x == 21) return 21;
  else if (x == 22) return 22;
  else return 0;
}
''');

      await server.initialize();
      serverInitialized = true;
      final diagnostics = await server.analyzeFile(dartFile.path);

      expect(diagnostics.any((d) => d.code == 'high_cyclomatic_complexity'),
          isTrue);
    });

    test('analyzeProject analyzes multiple files', () async {
      File(path.join(tempPath, 'file1.dart'))
          .writeAsStringSync('void func1() { print("1"); }');
      File(path.join(tempPath, 'file2.dart'))
          .writeAsStringSync('void func2() { print("2"); }');

      await server.initialize();
      serverInitialized = true;
      final result = await server.analyzeProject();

      expect(result.fileCount, equals(2));
    });

    test('returns empty diagnostics for non-existent file', () async {
      await server.initialize();
      serverInitialized = true;
      final diagnostics =
          await server.analyzeFile(path.join(tempPath, 'nonexistent.dart'));

      expect(diagnostics, isEmpty);
    });

    test('initialize is idempotent', () async {
      await server.initialize();
      serverInitialized = true;
      await server.initialize(); // Should not throw

      final dartFile = File(path.join(tempPath, 'test.dart'));
      dartFile.writeAsStringSync('void main() {}');

      final diagnostics = await server.analyzeFile(dartFile.path);
      expect(diagnostics, isEmpty);
    });
  });

  group('DiagnosticsProvider Integration', () {
    late Directory tempDir;
    late String tempPath;
    late SourceLoader loader;
    late DiagnosticsProvider provider;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anteater_diag_test_');
      tempPath = tempDir.path;
      loader = SourceLoader(tempPath);
      provider = DiagnosticsProvider(sourceLoader: loader);
    });

    tearDown(() async {
      await loader.dispose();
      tempDir.deleteSync(recursive: true);
    });

    test('analyzes file with metrics diagnostics', () async {
      final dartFile = File(path.join(tempPath, 'metrics.dart'));
      dartFile.writeAsStringSync('''
void simpleFunction() {
  var x = 1;
  print(x);
}
''');

      final diagnostics = await provider.analyze(dartFile.path);

      // Simple function should pass all thresholds
      expect(
          diagnostics.where((d) =>
              d.code == 'high_cyclomatic_complexity' ||
              d.code == 'high_cognitive_complexity'),
          isEmpty);
    });

    test('detects long function', () async {
      final dartFile = File(path.join(tempPath, 'long.dart'));
      // Generate a function with >100 lines using print statements
      // (toSource() preserves print statements on separate lines)
      final lines = List.generate(120, (i) => "  print('line $i');").join('\n');
      dartFile.writeAsStringSync('''
void longFunction() {
$lines
}
''');

      final diagnostics = await provider.analyze(dartFile.path);

      expect(diagnostics.any((d) => d.code == 'function_too_long'), isTrue);
    });

    test('custom thresholds are applied', () async {
      final strictProvider = DiagnosticsProvider(
        sourceLoader: loader,
        thresholds: const DiagnosticThresholds(
          cyclomaticComplexity: 1, // Very strict
          cognitiveComplexity: 1,
          maintainabilityIndex: 99.0,
          linesOfCode: 5,
        ),
      );

      final dartFile = File(path.join(tempPath, 'strict.dart'));
      dartFile.writeAsStringSync('''
void mediumFunction(int x) {
  if (x > 0) {
    print('positive');
  } else {
    print('non-positive');
  }
}
''');

      final diagnostics = await strictProvider.analyze(dartFile.path);

      // With strict thresholds, this should trigger warnings
      expect(diagnostics, isNotEmpty);
    });

    test('returns empty diagnostics for non-existent file', () async {
      final diagnostics =
          await provider.analyze(path.join(tempPath, 'missing.dart'));

      expect(diagnostics, isEmpty);
    });

    test('analyzes style rules', () async {
      final dartFile = File(path.join(tempPath, 'style.dart'));
      dartFile.writeAsStringSync('''
// ignore_for_file: unused_local_variable

void test() {
  dynamic x = 1;  // avoid-dynamic violation
}
''');

      final diagnostics = await provider.analyze(dartFile.path);

      // Should detect avoid-dynamic rule violation
      expect(diagnostics.any((d) => d.code == 'avoid-dynamic'), isTrue);
    });
  });

  group('HoverProvider Integration', () {
    late Directory tempDir;
    late String tempPath;
    late SourceLoader loader;
    late HoverProvider provider;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anteater_hover_test_');
      tempPath = tempDir.path;
      loader = SourceLoader(tempPath);
      provider = HoverProvider(sourceLoader: loader);
    });

    tearDown(() async {
      await loader.dispose();
      tempDir.deleteSync(recursive: true);
    });

    test('returns null for non-existent file', () async {
      final hover = await provider.getHover(
        filePath: path.join(tempPath, 'missing.dart'),
        position: const Position(line: 0, character: 0),
      );

      expect(hover, isNull);
    });

    test('returns hover info for function', () async {
      final dartFile = File(path.join(tempPath, 'func.dart'));
      dartFile.writeAsStringSync('''
void testFunction() {
  var x = 1;
  print(x);
}
''');

      final hover = await provider.getHover(
        filePath: dartFile.path,
        position: const Position(line: 1, character: 5), // Inside function body
      );

      expect(hover, isNotNull);
      expect(hover!.contents.kind, equals(MarkupKind.markdown));
      expect(hover.contents.value, contains('testFunction'));
      expect(hover.contents.value, contains('Cyclomatic Complexity'));
    });

    test('returns hover info for class', () async {
      final dartFile = File(path.join(tempPath, 'cls.dart'));
      dartFile.writeAsStringSync('''
class TestClass {
  final int value;

  TestClass(this.value);

  void method() {
    print(value);
  }
}
''');

      final hover = await provider.getHover(
        filePath: dartFile.path,
        position: const Position(line: 1, character: 5), // Inside class
      );

      expect(hover, isNotNull);
      expect(hover!.contents.value, contains('TestClass'));
    });

    test('returns null for position outside code', () async {
      final dartFile = File(path.join(tempPath, 'pos.dart'));
      dartFile.writeAsStringSync('void main() {}');

      final hover = await provider.getHover(
        filePath: dartFile.path,
        position: const Position(line: 100, character: 0), // Beyond file
      );

      expect(hover, isNull);
    });

    test('hover shows Halstead metrics for complex function', () async {
      final dartFile = File(path.join(tempPath, 'halstead.dart'));
      dartFile.writeAsStringSync('''
int calculate(int a, int b, int c) {
  var sum = a + b + c;
  var product = a * b * c;
  var result = sum + product;
  return result;
}
''');

      final hover = await provider.getHover(
        filePath: dartFile.path,
        position: const Position(line: 1, character: 5),
      );

      expect(hover, isNotNull);
      expect(hover!.contents.value, contains('Halstead'));
    });
  });

  group('CodeActionsProvider Integration', () {
    late CodeActionsProvider provider;

    setUp(() {
      provider = CodeActionsProvider();
    });

    test('returns actions for cognitive complexity', () async {
      const diagnostic = Diagnostic(
        message: 'High cognitive complexity',
        severity: DiagnosticSeverity.hint,
        range: Range.zero,
        source: 'anteater',
        code: 'high_cognitive_complexity',
      );

      final actions = await provider.getCodeActions(
        filePath: '/test.dart',
        range: Range.zero,
        diagnostics: [diagnostic],
      );

      expect(actions.length, equals(2));
      expect(actions.any((a) => a.title.contains('Simplify')), isTrue);
      expect(actions.any((a) => a.title.contains('Extract')), isTrue);
    });

    test('returns actions for low maintainability', () async {
      const diagnostic = Diagnostic(
        message: 'Low MI',
        severity: DiagnosticSeverity.warning,
        range: Range.zero,
        source: 'anteater',
        code: 'low_maintainability_index',
      );

      final actions = await provider.getCodeActions(
        filePath: '/test.dart',
        range: Range.zero,
        diagnostics: [diagnostic],
      );

      expect(actions.length, equals(2));
      expect(actions.any((a) => a.title.contains('maintainability')), isTrue);
      expect(actions.any((a) => a.title.contains('documentation')), isTrue);
    });

    test('returns actions for mutable shared state', () async {
      const diagnostic = Diagnostic(
        message: 'Mutable state',
        severity: DiagnosticSeverity.info,
        range: Range.zero,
        source: 'anteater',
        code: 'mutable_shared_state',
      );

      final actions = await provider.getCodeActions(
        filePath: '/test.dart',
        range: Range.zero,
        diagnostics: [diagnostic],
      );

      expect(actions.length, equals(2));
      expect(actions.any((a) => a.title.contains('final')), isTrue);
      expect(actions.any((a) => a.title.contains('immutable')), isTrue);
    });

    test('returns actions for semantic clone', () async {
      const diagnostic = Diagnostic(
        message: 'Semantic clone detected',
        severity: DiagnosticSeverity.info,
        range: Range.zero,
        source: 'anteater',
        code: 'semantic_clone',
      );

      final actions = await provider.getCodeActions(
        filePath: '/test.dart',
        range: Range.zero,
        diagnostics: [diagnostic],
      );

      expect(actions.length, equals(2));
      expect(actions[0].isPreferred, isTrue);
      expect(actions.any((a) => a.title.contains('common function')), isTrue);
    });

    test('applyCodeAction returns null (not yet implemented)', () async {
      const action = CodeAction(
        title: 'Test',
        kind: CodeActionKind.quickfix,
      );

      final edit = await provider.applyCodeAction(
        filePath: '/test.dart',
        action: action,
      );

      expect(edit, isNull);
    });
  });
}
