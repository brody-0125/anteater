import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:anteater/frontend/ir_generator.dart';
import 'package:anteater/frontend/kernel_reader.dart';
import 'package:anteater/frontend/source_loader.dart';
import 'package:anteater/ir/cfg/cfg_builder.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('SourceLoader', () {
    late Directory tempDir;
    late String tempPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anteater_test_');
      tempPath = tempDir.path;
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    group('discoverDartFiles', () {
      test('returns empty list for empty directory', () {
        final loader = SourceLoader(tempPath);
        final files = loader.discoverDartFiles();

        expect(files, isEmpty);
      });

      test('discovers single Dart file', () {
        final dartFile = File(path.join(tempPath, 'example.dart'));
        dartFile.writeAsStringSync('void main() {}');

        final loader = SourceLoader(tempPath);
        final files = loader.discoverDartFiles();

        expect(files, hasLength(1));
        expect(files.first, endsWith('example.dart'));
      });

      test('discovers multiple Dart files', () {
        File(path.join(tempPath, 'a.dart')).writeAsStringSync('void a() {}');
        File(path.join(tempPath, 'b.dart')).writeAsStringSync('void b() {}');
        File(path.join(tempPath, 'c.dart')).writeAsStringSync('void c() {}');

        final loader = SourceLoader(tempPath);
        final files = loader.discoverDartFiles();

        expect(files, hasLength(3));
      });

      test('discovers files in subdirectories', () {
        final subDir = Directory(path.join(tempPath, 'sub'));
        subDir.createSync();
        File(path.join(subDir.path, 'nested.dart'))
            .writeAsStringSync('void nested() {}');

        final loader = SourceLoader(tempPath);
        final files = loader.discoverDartFiles();

        expect(files, hasLength(1));
        expect(files.first, contains('nested.dart'));
      });

      test('excludes .g.dart files', () {
        File(path.join(tempPath, 'model.dart'))
            .writeAsStringSync('class Model {}');
        File(path.join(tempPath, 'model.g.dart'))
            .writeAsStringSync('// GENERATED');

        final loader = SourceLoader(tempPath);
        final files = loader.discoverDartFiles();

        expect(files, hasLength(1));
        expect(files.first, isNot(contains('.g.dart')));
      });

      test('excludes .freezed.dart files', () {
        File(path.join(tempPath, 'state.dart'))
            .writeAsStringSync('class State {}');
        File(path.join(tempPath, 'state.freezed.dart'))
            .writeAsStringSync('// GENERATED');

        final loader = SourceLoader(tempPath);
        final files = loader.discoverDartFiles();

        expect(files, hasLength(1));
        expect(files.first, isNot(contains('.freezed.dart')));
      });

      test('handles single file path', () {
        final dartFile = File(path.join(tempPath, 'single.dart'));
        dartFile.writeAsStringSync('void single() {}');

        final loader = SourceLoader(dartFile.path);
        final files = loader.discoverDartFiles();

        expect(files, hasLength(1));
        expect(files.first, endsWith('single.dart'));
      });

      test('returns empty list for non-dart single file', () {
        final txtFile = File(path.join(tempPath, 'readme.txt'));
        txtFile.writeAsStringSync('Hello');

        final loader = SourceLoader(txtFile.path);
        final files = loader.discoverDartFiles();

        expect(files, isEmpty);
      });
    });

    group('resolveFile', () {
      test('resolves valid Dart file', () async {
        final dartFile = File(path.join(tempPath, 'valid.dart'));
        dartFile.writeAsStringSync('''
void main() {
  print('Hello');
}
''');

        final loader = SourceLoader(tempPath);
        final result = await loader.resolveFile(dartFile.path);

        expect(result, isNotNull);
        expect(result!.unit.declarations, hasLength(1));

        await loader.dispose();
      });

      test('returns unit with declarations', () async {
        final dartFile = File(path.join(tempPath, 'declarations.dart'));
        dartFile.writeAsStringSync('''
class MyClass {
  void method() {}
}

void topLevel() {}

int get getter => 42;
''');

        final loader = SourceLoader(tempPath);
        final result = await loader.resolveFile(dartFile.path);

        expect(result, isNotNull);
        expect(result!.unit.declarations.length, greaterThanOrEqualTo(3));

        await loader.dispose();
      });
    });

    group('parseFile', () {
      test('parses valid Dart file', () async {
        final dartFile = File(path.join(tempPath, 'parse.dart'));
        dartFile.writeAsStringSync('''
void example() {
  var x = 1;
}
''');

        final loader = SourceLoader(tempPath);
        final unit = await loader.parseFile(dartFile.path);

        expect(unit, isNotNull);
        expect(unit!.declarations, isNotEmpty);

        await loader.dispose();
      });
    });
  });

  group('IrGenerator', () {
    late Directory tempDir;
    late String tempPath;
    late SourceLoader loader;
    late IrGenerator generator;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anteater_ir_test_');
      tempPath = tempDir.path;
      loader = SourceLoader(tempPath);
      generator = IrGenerator(loader);
    });

    tearDown(() async {
      await loader.dispose();
      tempDir.deleteSync(recursive: true);
    });

    group('analyzeFile', () {
      test('returns FileIr with empty functions for file without functions', () async {
        final dartFile = File(path.join(tempPath, 'empty.dart'));
        dartFile.writeAsStringSync('// Empty file with no declarations');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        expect(result!.functions, isEmpty);
        expect(result.classes, isEmpty);
      });

      test('analyzes top-level function', () async {
        final dartFile = File(path.join(tempPath, 'toplevel.dart'));
        dartFile.writeAsStringSync('''
void topLevel() {
  var x = 1;
}
''');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        expect(result!.functions, hasLength(1));
        expect(result.functions.first.name, equals('topLevel'));
      });

      test('analyzes class methods', () async {
        final dartFile = File(path.join(tempPath, 'class.dart'));
        dartFile.writeAsStringSync('''
class MyClass {
  void method() {
    var x = 1;
  }

  int compute() {
    return 42;
  }
}
''');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        expect(result!.classes, hasLength(1));
        expect(result.classes.first.name, equals('MyClass'));
        expect(result.classes.first.methods, hasLength(2));
      });

      test('collects class fields', () async {
        final dartFile = File(path.join(tempPath, 'fields.dart'));
        dartFile.writeAsStringSync('''
class WithFields {
  final String name;
  int count = 0;
  static const version = 1;

  WithFields(this.name);
}
''');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        expect(result!.classes.first.fields, hasLength(3));

        final fields = result.classes.first.fields;
        expect(fields.any((f) => f.name == 'name' && f.isFinal), isTrue);
        expect(fields.any((f) => f.name == 'count' && !f.isFinal), isTrue);
        expect(fields.any((f) => f.name == 'version' && f.isStatic), isTrue);
      });

      test('skips abstract methods', () async {
        final dartFile = File(path.join(tempPath, 'abstract.dart'));
        dartFile.writeAsStringSync('''
abstract class Abstract {
  void concrete() {
    print('hello');
  }

  void abstractMethod();
}
''');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        expect(result!.classes.first.methods, hasLength(1));
        expect(result.classes.first.methods.first.name, contains('concrete'));
      });

      test('analyzes mixin methods', () async {
        final dartFile = File(path.join(tempPath, 'mixin.dart'));
        dartFile.writeAsStringSync('''
mixin MyMixin {
  void mixinMethod() {
    var x = 1;
  }
}
''');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        expect(result!.classes, hasLength(1));
        expect(result.classes.first.name, equals('MyMixin'));
        expect(result.classes.first.methods, hasLength(1));
      });

      test('analyzes extension methods', () async {
        final dartFile = File(path.join(tempPath, 'extension.dart'));
        dartFile.writeAsStringSync('''
extension StringExtension on String {
  String doubled() {
    return this + this;
  }
}
''');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        expect(result!.classes, hasLength(1));
        expect(result.classes.first.name, equals('StringExtension'));
        expect(result.classes.first.methods, hasLength(1));
      });

      test('analyzes enum methods', () async {
        final dartFile = File(path.join(tempPath, 'enum.dart'));
        dartFile.writeAsStringSync('''
enum Status {
  active,
  inactive;

  bool get isActive {
    return this == Status.active;
  }

  String describe() {
    return name;
  }
}
''');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        // Enum with methods should be included
        final enumClass =
            result!.classes.where((c) => c.name == 'Status').toList();
        expect(enumClass, isNotEmpty);
      });

      test('analyzes constructor', () async {
        final dartFile = File(path.join(tempPath, 'constructor.dart'));
        dartFile.writeAsStringSync('''
class WithConstructor {
  final int value;

  WithConstructor(this.value) {
    print('Created with \$value');
  }

  WithConstructor.named() : value = 0 {
    print('Named constructor');
  }
}
''');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        final methods = result!.classes.first.methods;
        expect(methods.length, greaterThanOrEqualTo(2));
      });
    });

    group('analyzeProject', () {
      test('analyzes multiple files', () async {
        File(path.join(tempPath, 'file1.dart'))
            .writeAsStringSync('void func1() { var x = 1; }');
        File(path.join(tempPath, 'file2.dart'))
            .writeAsStringSync('void func2() { var y = 2; }');

        final results = await generator.analyzeProject();

        expect(results, hasLength(2));
      });

      test('returns empty list for empty project', () async {
        final results = await generator.analyzeProject();

        expect(results, isEmpty);
      });
    });

    group('allFunctions', () {
      test('returns both top-level and class methods', () async {
        final dartFile = File(path.join(tempPath, 'all.dart'));
        dartFile.writeAsStringSync('''
void topLevel() {
  var x = 1;
}

class MyClass {
  void method1() {
    var a = 1;
  }

  void method2() {
    var b = 2;
  }
}
''');

        final result = await generator.analyzeFile(dartFile.path);

        expect(result, isNotNull);
        final allFunctions = result!.allFunctions.toList();
        expect(allFunctions, hasLength(3));
      });
    });
  });

  group('FunctionIr', () {
    test('toString returns readable format', () {
      final func = parseFunction('''
void example() {
  var x = 1;
}
''');
      final builder = CfgBuilder();
      final cfg = builder.buildFromFunction(func);

      final ir = FunctionIr(
        name: 'TestFunction',
        cfg: cfg,
        parameters: [],
        filePath: '/test/file.dart',
        offset: 0,
        endOffset: 100,
      );

      expect(ir.toString(), equals('FunctionIr(TestFunction)'));
    });
  });

  group('KernelReader', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anteater_kernel_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('returns null for non-existent file', () async {
      final reader = KernelReader();
      final result =
          await reader.loadFromFile(path.join(tempDir.path, 'nonexistent.dill'));

      expect(result, isNull);
    });

    test('returns KernelProgram for existing file', () async {
      // Create a dummy .dill file (kernel parsing is stubbed)
      final dillFile = File(path.join(tempDir.path, 'test.dill'));
      dillFile.writeAsBytesSync([0, 1, 2, 3]); // Dummy bytes

      final reader = KernelReader();
      final result = await reader.loadFromFile(dillFile.path);

      // Current implementation returns empty program (stub)
      expect(result, isNotNull);
      expect(result!.libraries, isEmpty);
    });
  });

  group('Kernel Data Classes', () {
    test('KernelProgram holds libraries', () {
      final program = KernelProgram(libraries: [
        KernelLibrary(uri: 'package:test/test.dart'),
      ]);

      expect(program.libraries, hasLength(1));
    });

    test('KernelLibrary has uri and members', () {
      final library = KernelLibrary(
        uri: 'package:test/lib.dart',
        classes: [KernelClass(name: 'MyClass')],
        procedures: [KernelProcedure(name: 'myFunc')],
      );

      expect(library.uri, equals('package:test/lib.dart'));
      expect(library.classes, hasLength(1));
      expect(library.procedures, hasLength(1));
    });

    test('KernelClass has name and members', () {
      final cls = KernelClass(
        name: 'TestClass',
        procedures: [
          KernelProcedure(name: 'method', isStatic: false),
          KernelProcedure(name: 'staticMethod', isStatic: true),
        ],
        fields: [
          KernelField(name: 'field', isFinal: true),
        ],
      );

      expect(cls.name, equals('TestClass'));
      expect(cls.procedures, hasLength(2));
      expect(cls.fields, hasLength(1));
    });

    test('KernelProcedure has properties', () {
      final proc = KernelProcedure(
        name: 'abstractMethod',
        isStatic: false,
        isAbstract: true,
      );

      expect(proc.name, equals('abstractMethod'));
      expect(proc.isStatic, isFalse);
      expect(proc.isAbstract, isTrue);
    });

    test('KernelField has properties', () {
      final field = KernelField(
        name: 'staticFinal',
        isFinal: true,
        isStatic: true,
      );

      expect(field.name, equals('staticFinal'));
      expect(field.isFinal, isTrue);
      expect(field.isStatic, isTrue);
    });
  });
}

// Helper to parse a function declaration
FunctionDeclaration parseFunction(String code) {
  final result = parseString(content: code);
  return result.unit.declarations.first as FunctionDeclaration;
}
