import 'language_server.dart';

/// Provides code actions (quick fixes and refactoring suggestions).
///
/// Code actions are returned in response to diagnostics and allow
/// users to apply automated fixes or refactoring.
class CodeActionsProvider {
  CodeActionsProvider();

  /// Returns code actions for the given range and diagnostics.
  Future<List<CodeAction>> getCodeActions({
    required String filePath,
    required Range range,
    required List<Diagnostic> diagnostics,
  }) async {
    final actions = <CodeAction>[];

    for (final diagnostic in diagnostics) {
      final diagnosticActions = _getActionsForDiagnostic(
        filePath: filePath,
        diagnostic: diagnostic,
      );
      actions.addAll(diagnosticActions);
    }

    return actions;
  }

  /// Returns code actions for a specific diagnostic.
  List<CodeAction> _getActionsForDiagnostic({
    required String filePath,
    required Diagnostic diagnostic,
  }) {
    final actions = <CodeAction>[];

    switch (diagnostic.code) {
      case 'high_cyclomatic_complexity':
        actions.add(CodeAction(
          title: 'Extract method to reduce complexity',
          kind: CodeActionKind.refactorExtract,
          diagnostic: diagnostic,
          command: CodeCommand(
            title: 'Extract Method',
            command: 'anteater.extractMethod',
            arguments: [filePath, diagnostic.range],
          ),
        ));
        actions.add(CodeAction(
          title: 'Split conditional into guard clauses',
          kind: CodeActionKind.refactorRewrite,
          diagnostic: diagnostic,
        ));

      case 'high_cognitive_complexity':
        actions.add(CodeAction(
          title: 'Simplify nested conditions',
          kind: CodeActionKind.refactorRewrite,
          diagnostic: diagnostic,
        ));
        actions.add(CodeAction(
          title: 'Extract helper function',
          kind: CodeActionKind.refactorExtract,
          diagnostic: diagnostic,
        ));

      case 'low_maintainability_index':
        actions.add(CodeAction(
          title: 'Refactor for better maintainability',
          kind: CodeActionKind.refactorRewrite,
          diagnostic: diagnostic,
        ));
        actions.add(CodeAction(
          title: 'Add documentation comments',
          kind: CodeActionKind.quickfix,
          diagnostic: diagnostic,
        ));

      case 'function_too_long':
        actions.add(CodeAction(
          title: 'Extract method',
          kind: CodeActionKind.refactorExtract,
          diagnostic: diagnostic,
        ));
        actions.add(CodeAction(
          title: 'Split into smaller functions',
          kind: CodeActionKind.refactorRewrite,
          diagnostic: diagnostic,
        ));

      case 'potential_null_dereference':
        actions.add(CodeAction(
          title: 'Add null check',
          kind: CodeActionKind.quickfix,
          diagnostic: diagnostic,
          isPreferred: true,
        ));
        actions.add(CodeAction(
          title: 'Use null-aware operator (?. or ??)',
          kind: CodeActionKind.quickfix,
          diagnostic: diagnostic,
        ));

      case 'potential_bounds_violation':
        actions.add(CodeAction(
          title: 'Add bounds check',
          kind: CodeActionKind.quickfix,
          diagnostic: diagnostic,
          isPreferred: true,
        ));
        actions.add(CodeAction(
          title: 'Use safe access method (elementAtOrNull)',
          kind: CodeActionKind.quickfix,
          diagnostic: diagnostic,
        ));

      case 'mutable_shared_state':
        actions.add(CodeAction(
          title: 'Mark fields as final',
          kind: CodeActionKind.quickfix,
          diagnostic: diagnostic,
        ));
        actions.add(CodeAction(
          title: 'Extract immutable data class',
          kind: CodeActionKind.refactorExtract,
          diagnostic: diagnostic,
        ));

      case 'semantic_clone':
        actions.add(CodeAction(
          title: 'Extract common function',
          kind: CodeActionKind.refactorExtract,
          diagnostic: diagnostic,
          isPreferred: true,
        ));
        actions.add(CodeAction(
          title: 'Create shared utility',
          kind: CodeActionKind.refactorExtract,
          diagnostic: diagnostic,
        ));
    }

    return actions;
  }

  /// Applies a code action edit to the document.
  ///
  /// Returns the edited content or null if the action cannot be applied.
  Future<TextEdit?> applyCodeAction({
    required String filePath,
    required CodeAction action,
  }) async {
    // For now, return null as edits require more complex AST manipulation
    // This will be enhanced in future iterations
    return null;
  }
}

/// A code action that can be applied to fix or refactor code.
class CodeAction {
  /// The display title for this action.
  final String title;

  /// The kind of action (quickfix, refactor, etc).
  final CodeActionKind kind;

  /// The diagnostic this action addresses.
  final Diagnostic? diagnostic;

  /// Whether this is the preferred action for the diagnostic.
  final bool isPreferred;

  /// Optional text edits to apply.
  final List<TextEdit>? edits;

  /// Optional command to execute.
  final CodeCommand? command;

  const CodeAction({
    required this.title,
    required this.kind,
    this.diagnostic,
    this.isPreferred = false,
    this.edits,
    this.command,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'kind': kind.value,
        if (diagnostic != null) 'diagnostics': [diagnostic!.toJson()],
        if (isPreferred) 'isPreferred': true,
        if (edits != null) 'edit': {'changes': edits!.map((e) => e.toJson())},
        if (command != null) 'command': command!.toJson(),
      };
}

/// Kinds of code actions.
class CodeActionKind {
  final String value;

  const CodeActionKind._(this.value);

  static const quickfix = CodeActionKind._('quickfix');
  static const refactor = CodeActionKind._('refactor');
  static const refactorExtract = CodeActionKind._('refactor.extract');
  static const refactorInline = CodeActionKind._('refactor.inline');
  static const refactorRewrite = CodeActionKind._('refactor.rewrite');
  static const source = CodeActionKind._('source');
  static const sourceOrganizeImports =
      CodeActionKind._('source.organizeImports');

  @override
  String toString() => value;
}

/// A text edit to apply to a document.
class TextEdit {
  final Range range;
  final String newText;

  const TextEdit({required this.range, required this.newText});

  Map<String, dynamic> toJson() => {
        'range': range.toJson(),
        'newText': newText,
      };
}

/// A command to execute.
class CodeCommand {
  final String title;
  final String command;
  final List<dynamic>? arguments;

  const CodeCommand({
    required this.title,
    required this.command,
    this.arguments,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'command': command,
        if (arguments != null) 'arguments': arguments,
      };
}
