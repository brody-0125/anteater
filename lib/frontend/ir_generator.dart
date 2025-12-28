import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../ir/cfg/cfg_builder.dart';
import '../ir/cfg/control_flow_graph.dart';
import '../ir/ssa/ssa_builder.dart';
import 'source_loader.dart';

/// Represents the IR for a single function/method.
class FunctionIr {
  /// Fully qualified name (e.g., "MyClass.myMethod" or "topLevelFunction").
  final String name;

  /// The Control Flow Graph in SSA form.
  final ControlFlowGraph cfg;

  /// Parameter variables.
  final List<Variable> parameters;

  /// Source file path.
  final String filePath;

  /// Start offset in source.
  final int offset;

  /// End offset in source.
  final int endOffset;

  FunctionIr({
    required this.name,
    required this.cfg,
    required this.parameters,
    required this.filePath,
    required this.offset,
    required this.endOffset,
  });

  @override
  String toString() => 'FunctionIr($name)';
}

/// Represents the IR for an entire file.
class FileIr {
  final String filePath;
  final List<FunctionIr> functions;
  final List<ClassIr> classes;

  FileIr({
    required this.filePath,
    required this.functions,
    required this.classes,
  });

  /// All function IRs including those inside classes.
  Iterable<FunctionIr> get allFunctions sync* {
    yield* functions;
    for (final cls in classes) {
      yield* cls.methods;
    }
  }
}

/// Represents the IR for a class.
class ClassIr {
  final String name;
  final List<FunctionIr> methods;
  final List<FieldInfo> fields;

  ClassIr({
    required this.name,
    required this.methods,
    required this.fields,
  });
}

/// Information about a class field.
class FieldInfo {
  final String name;
  final String? typeName;
  final bool isFinal;
  final bool isStatic;

  FieldInfo({
    required this.name,
    this.typeName,
    this.isFinal = false,
    this.isStatic = false,
  });
}

/// Generates IR from Dart source files.
///
/// Pipeline: SourceLoader → AST → CFG → SSA
class IrGenerator {
  final SourceLoader _loader;
  final CfgBuilder _cfgBuilder = CfgBuilder();

  IrGenerator(this._loader);

  /// Analyzes a single file and returns its IR.
  Future<FileIr?> analyzeFile(String filePath) async {
    final resolved = await _loader.resolveFile(filePath);
    if (resolved == null) return null;

    final collector = _DeclarationCollector();
    resolved.unit.accept(collector);

    final functions = <FunctionIr>[];
    final classes = <ClassIr>[];

    // Process top-level functions
    for (final func in collector.functions) {
      final ir = _buildFunctionIr(func, filePath, null);
      if (ir != null) {
        functions.add(ir);
      }
    }

    // Process classes
    for (final cls in collector.classes) {
      final classIr = _buildClassIr(cls, filePath);
      classes.add(classIr);
    }

    // Process mixins (ADR-015 1.1)
    for (final mixin in collector.mixins) {
      final mixinIr = _buildMixinIr(mixin, filePath);
      classes.add(mixinIr);
    }

    // Process extensions (ADR-015 1.1)
    for (final ext in collector.extensions) {
      final extIr = _buildExtensionIr(ext, filePath);
      classes.add(extIr);
    }

    // Process enums with methods (ADR-015 1.2)
    for (final enumDecl in collector.enums) {
      final enumIr = _buildEnumIr(enumDecl, filePath);
      if (enumIr.methods.isNotEmpty) {
        classes.add(enumIr);
      }
    }

    return FileIr(
      filePath: filePath,
      functions: functions,
      classes: classes,
    );
  }

  /// Analyzes all Dart files in the project.
  Future<List<FileIr>> analyzeProject() async {
    final files = _loader.discoverDartFiles();
    final results = <FileIr>[];

    for (final file in files) {
      final ir = await analyzeFile(file);
      if (ir != null) {
        results.add(ir);
      }
    }

    return results;
  }

  FunctionIr? _buildFunctionIr(
    FunctionDeclaration node,
    String filePath,
    String? className,
  ) {
    final body = node.functionExpression.body;
    if (body is EmptyFunctionBody) {
      // Skip abstract/external functions
      return null;
    }

    // Extract parameters before SSA conversion so they can be versioned
    final parameters = _extractParameters(node.functionExpression.parameters);

    final cfg = _cfgBuilder.buildFromFunction(node);
    final ssaCfg = cfg.toSsa(parameters);

    final name = className != null ? '$className.${node.name.lexeme}' : node.name.lexeme;

    return FunctionIr(
      name: name,
      cfg: ssaCfg,
      parameters: parameters,
      filePath: filePath,
      offset: node.offset,
      endOffset: node.end,
    );
  }

  FunctionIr? _buildMethodIr(
    MethodDeclaration node,
    String filePath,
    String className,
  ) {
    if (node.isAbstract) {
      return null;
    }

    final body = node.body;
    if (body is EmptyFunctionBody) {
      return null;
    }

    // Extract parameters before SSA conversion so they can be versioned
    final parameters = _extractParameters(node.parameters);

    final cfg = _cfgBuilder.buildFromMethod(node);
    final ssaCfg = cfg.toSsa(parameters);

    final name = '$className.${node.name.lexeme}';

    return FunctionIr(
      name: name,
      cfg: ssaCfg,
      parameters: parameters,
      filePath: filePath,
      offset: node.offset,
      endOffset: node.end,
    );
  }

  ClassIr _buildClassIr(ClassDeclaration node, String filePath) {
    final methods = <FunctionIr>[];
    final fields = <FieldInfo>[];

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final ir = _buildMethodIr(member, filePath, node.name.lexeme);
        if (ir != null) {
          methods.add(ir);
        }
      } else if (member is ConstructorDeclaration) {
        final ir = _buildConstructorIr(member, filePath, node.name.lexeme);
        if (ir != null) {
          methods.add(ir);
        }
      } else if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          fields.add(FieldInfo(
            name: variable.name.lexeme,
            typeName: member.fields.type?.toSource(),
            isFinal: member.fields.isFinal,
            isStatic: member.isStatic,
          ));
        }
      }
    }

    return ClassIr(
      name: node.name.lexeme,
      methods: methods,
      fields: fields,
    );
  }

  /// Builds IR for a mixin declaration (ADR-015 1.1).
  ClassIr _buildMixinIr(MixinDeclaration node, String filePath) {
    final methods = <FunctionIr>[];

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final ir = _buildMethodIr(member, filePath, node.name.lexeme);
        if (ir != null) {
          methods.add(ir);
        }
      }
    }

    return ClassIr(
      name: node.name.lexeme,
      methods: methods,
      fields: const [],
    );
  }

  /// Builds IR for an extension declaration (ADR-015 1.1).
  ClassIr _buildExtensionIr(ExtensionDeclaration node, String filePath) {
    final methods = <FunctionIr>[];
    final extensionName = node.name?.lexeme ?? '_extension';

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final ir = _buildMethodIr(member, filePath, extensionName);
        if (ir != null) {
          methods.add(ir);
        }
      }
    }

    return ClassIr(
      name: extensionName,
      methods: methods,
      fields: const [],
    );
  }

  /// Builds IR for an enum declaration with methods (ADR-015 1.2).
  ClassIr _buildEnumIr(EnumDeclaration node, String filePath) {
    final methods = <FunctionIr>[];

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final ir = _buildMethodIr(member, filePath, node.name.lexeme);
        if (ir != null) {
          methods.add(ir);
        }
      }
    }

    return ClassIr(
      name: node.name.lexeme,
      methods: methods,
      fields: const [],
    );
  }

  FunctionIr? _buildConstructorIr(
    ConstructorDeclaration node,
    String filePath,
    String className,
  ) {
    final body = node.body;
    if (body is EmptyFunctionBody) {
      return null;
    }

    // Extract parameters before SSA conversion so they can be versioned
    final parameters = _extractParameters(node.parameters);

    // Build CFG using CfgBuilder (handles initializers and body)
    final cfg = _cfgBuilder.buildFromConstructor(node, className);
    final ssaCfg = cfg.toSsa(parameters);

    return FunctionIr(
      name: cfg.functionName,
      cfg: ssaCfg,
      parameters: parameters,
      filePath: filePath,
      offset: node.offset,
      endOffset: node.end,
    );
  }

  List<Variable> _extractParameters(FormalParameterList? params) {
    if (params == null) return [];

    return params.parameters.map((param) {
      final name = param.name?.lexeme ?? '_';
      return Variable(name);
    }).toList();
  }
}

/// Collects top-level declarations from an AST.
class _DeclarationCollector extends RecursiveAstVisitor<void> {
  final List<FunctionDeclaration> functions = [];
  final List<ClassDeclaration> classes = [];
  final List<MixinDeclaration> mixins = [];
  final List<ExtensionDeclaration> extensions = [];
  final List<EnumDeclaration> enums = [];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    functions.add(node);
    // Don't recurse into the function body for collection
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    classes.add(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    mixins.add(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    extensions.add(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    enums.add(node);
  }
}

/// Extension to provide convenient IR generation from SourceLoader.
extension IrGeneratorExtension on SourceLoader {
  /// Creates an IR generator for this loader.
  IrGenerator get irGenerator => IrGenerator(this);
}
