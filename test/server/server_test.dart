import 'package:test/test.dart';
import 'package:anteater/server/language_server.dart';
import 'package:anteater/server/code_actions_provider.dart';
import 'package:anteater/server/hover_provider.dart';
import 'package:anteater/server/diagnostics_provider.dart';

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
}
