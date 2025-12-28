# **The Architecture, Operating Principles, and Technical Comparison Analysis Report of dart-code-metrics and the Dart Analyzer**

## **1. Introduction: The Evolution of the Dart Static Analysis Ecosystem and the Status of dart-code-metrics**

In modern software engineering, static analysis has become a core methodology for ensuring code quality, stability, and maintainability. Particularly, as the Google-developed Dart language and the Flutter framework have emerged as mainstream in multi-platform development across mobile, web, and desktop, the importance of tools for maintaining the health of Dart codebases has increased exponentially. While the Dart language itself provides a powerful type system and a built-in analyzer, complex application development environments at the enterprise level required tools capable of detecting deep-seated code quality metrics and architectural violations beyond simple syntax errors or type mismatches.

`dart-code-metrics` (hereafter DCM) emerged as an open-source package to meet these needs and has functioned as a de facto standard static analysis tool in the Dart ecosystem. This tool goes beyond the role of a simple linter, calculating quantitative metrics such as code complexity, maintainability, and technical debt, and contributes to code quality management by providing independent rules and anti-pattern detection not covered by the built-in Dart analyzer.

This report provides an in-depth analysis of the internal operating principles and architecture of `dart-code-metrics`. It details the technical implementation of the plugin architecture—the integration mechanism with the Dart Analysis Server (DAS)—and the resulting structural limitations. It also dissects the algorithmic implementation of major software metrics like Cyclomatic Complexity and Halstead Metrics from the perspective of Dart AST (Abstract Syntax Tree) traversal, ultimately arguing for the technical validity of how the technical bottlenecks of this tool triggered the transition to the next-generation commercial tool, DCM (New Dart Code Metrics).

## **2. Architecture Overview of the Dart Static Analysis System**

To understand the operation of `dart-code-metrics`, one must first understand the architecture and plugin system of the Dart Analysis Server it is hosted in.

### **2.1 Role and Structure of the Dart Analysis Server (DAS)**

The Dart Analysis Server included in the Dart SDK is a long-lived process providing language support features to IDEs (IntelliJ, VS Code, etc.) and editors. DAS continuously parses source code in the background while the user writes code and provides error, warning, code completion, and navigation info through a resolution process.

DAS basically uses `package:analyzer` to analyze Dart code. This process is largely divided into two stages:

1. **Parsing:** Reads source code, tokenizes it, and generates an AST (Abstract Syntax Tree) representing the grammatical structure.
2. **Resolution:** Assigns semantic information to each node of the generated AST. For example, it identifies where a variable is declared, its type, and what function is being called, creating an Element Model.

### **2.2 Operating Mechanism of the Analyzer Plugin System**

While `dart-code-metrics` also operates as a standalone CLI (Command Line Interface), the core of the developer experience (DX) lies in the **Analyzer Plugin** mode, which provides real-time feedback within the IDE. The Dart team provided a plugin API so that external packages could extend analysis logic without modifying the compiler or analyzer's internal code.

#### **2.2.1 Isolate-based Plugin Execution Model**

Following the DAS design philosophy, which prioritizes stability, external plugins do not share the same memory space as the main analysis server. Instead, each plugin runs in a separate Dart **Isolate**. Dart's Isolates are independent execution units that do not share a memory heap—similar to threads, but characterized by the absence of race conditions due to the lack of memory sharing.

When `dart-code-metrics` is registered as a plugin in the `analysis_options.yaml` file, DAS performs the following:

1. **Plugin Discovery:** Identifies the entry point of the plugin package (`bin/plugin.dart` or `lib/plugin.dart`) via `pubspec.yaml` and the `.dart_tool` directory.
2. **Isolate Spawning:** Creates a separate Isolate to load and execute the plugin code.
3. **Establishing Communication Channels:** Forms a channel based on ports or streams for communication between the main server and the plugin Isolate.

#### **2.2.2 Data Serialization and Exchange Protocols**

The most significant technical feature and bottleneck of this architecture is the **data exchange method**. Since memory is not shared, the main server cannot directly pass the AST or Element Model it has analyzed to the plugin. Instead, an inefficient process occurs:

1. **Analysis Request:** The main server sends an "AnalyzeRequest" to the plugin upon detecting a file change.
2. **Data Transmission Limits:** The main server passes the file's path and content but cannot pass the heavy AST objects already calculated.
3. **Re-analysis:** Upon receiving the request, the `dart-code-metrics` plugin Isolate must independently re-parse and re-resolve the source code of that file to create its own AST.
4. **Returning Results:** After analysis, derived metrics or lint errors are serialized as `AnalysisError` objects and sent to the main server.

This "Double Analysis" structure is the fundamental reason `dart-code-metrics` consumes excessive memory in large projects.

## **3. Internal Analysis Engine: AST Traversal and Data Collection**

The core logic of `dart-code-metrics` lies in transforming Dart source code into structured data and traversing it to calculate quantitative metrics. This process is implemented based on the Visitor pattern provided by `package:analyzer`.

### **3.1 Utilization of the RecursiveAstVisitor Pattern**

Dart's AST has a hierarchical structure starting from the root `CompilationUnit` down to classes, methods, statements, and expressions. `dart-code-metrics` extends the `RecursiveAstVisitor<R>` class to traverse this tree in a depth-first search (DFS) manner.

#### **3.1.1 Concreteness of Visitor Implementation**

For example, a visitor calculating cyclomatic complexity (let's assume `ComplexityVisitor`) operates as follows:

```dart
class ComplexityVisitor extends RecursiveAstVisitor<void> {
  int complexity = 0;

  @override
  void visitIfStatement(IfStatement node) {
    complexity++; // Increment complexity upon finding an if statement
    super.visitIfStatement(node); // Traverse inner blocks (then/else)
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    complexity++; // Increment complexity upon finding a while statement
    super.visitWhileStatement(node);
  }

  //... Overrides for other control flow statements
}
```

This visitor visits every node in the AST and increments an internal counter whenever it encounters specific node types (`IfStatement`, `ForStatement`, `CatchClause`, etc.). By using `RecursiveAstVisitor`, developers don't need to implement tree traversal logic themselves; they just need to inject processing logic for the node types they care about by overriding `visit...` methods.

### **3.2 Scope Analysis and Variable Tracking**

Beyond simple structural metrics, implementing rules like `unused-code` or `unused-parameters` requires **Scope Analysis**. `dart-code-metrics` maintains a symbol-table-like structure that tracks variable declarations and references during AST traversal.

* **Declaration Tracking:** When visiting a `VariableDeclaration` node, it registers the variable's name and declaration location in the currently active scope object.
* **Reference Tracking:** When visiting a `SimpleIdentifier` node, it checks if the identifier is a variable reference and traverses up the scope chain to increment the use count of that variable.
* **Shadowing Handling:** To accurately handle shadowing—where a variable in a local scope has the same name as one in a parent scope (e.g., a class field)—it manages scope entry and exit using a stack data structure.

## **4. In-depth Analysis of Software Metric Algorithms**

The most distinctive feature provided by `dart-code-metrics` is the calculation of quantitative code quality metrics. The tool implements academically established metrics like Cyclomatic Complexity, Halstead Metrics, Maintainability Index, and Technical Debt, tailored to the characteristics of the Dart language.

### **4.1 Cyclomatic Complexity**

Cyclomatic complexity is a metric devised by Thomas McCabe that measures the number of linearly independent paths in a program's Control Flow Graph. Theoretically defined as $V(G) = E - N + 2P$ (E: edges, N: nodes, P: connected components), `dart-code-metrics` uses a practical approximation via AST node counting.

#### **4.1.1 Naming Weights for Dart Specifics**

A noteworthy point in the implementation of `dart-code-metrics` is the inclusion of **boolean operators** and **null-aware operators** as complexity-increasing factors. This reflects the tool's philosophy of measuring "understanding difficulty."

| AST Node Type | Weight | Description |
| :---- | :---- | :---- |
| **Basic Function/Method** | 1 | Every function has at least one path |
| `IfStatement` | +1 | Branch occurs |
| `ForStatement`, `ForEachStatement` | +1 | Branch due to loop |
| `WhileStatement`, `DoStatement` | +1 | Branch due to loop |
| `SwitchCase` | +1 | Branch for each case (excluding `default`) |
| `CatchClause` | +1 | Exception handling path |
| `ConditionalExpression (? :)` | +1 | Branch due to ternary operator |
| `BinaryExpression (&&, ||)` | +1 | Hidden branch due to short-circuit evaluation |
| **Null-aware operators (?., ??, ??=)** | **+1** | Implicit branch for null check |

**Analysis:** In Dart, `a && b` is logically equivalent to `if (a) { b } else { false }`. Thus, the `&&` operator performs a branching role in the control flow, which `dart-code-metrics` accurately reflects in the complexity. This enables a more precise measurement of cognitive complexity than other tools that simply count keywords (`if`, `for`).

### **4.2 Halstead Metrics**

Halstead metrics view code as a sequence of operators and operands, estimating program "volume" and implementation "effort" through their diversity and length.

#### **4.2.1 Classification of Operators and Operands**

`dart-code-metrics` classifies and counts AST nodes as follows:

* **Operators ($n_1, N_1$):**
  * Arithmetic, logical, bitwise operators (`+`, `-`, `&&`, `|`, etc.)
  * Assignment operators (`=`, `+=`, etc.)
  * Control flow keywords (`if`, `return`, `await`, `yield`, etc.)
  * Punctuation and parentheses (`(`, `)`, `;`, `{`, `}`)
  * Call operators (parentheses used in function calls)
* **Operands ($n_2, N_2$):**
  * Identifiers (variable names, function names, class names)
  * Literals (strings, numbers, boolean values)
  * Type annotations (`int`, `String`, `void`, etc.)

#### **4.2.2 Calculation Formulas**

Based on the collected primary data, the following derived metrics are calculated:

1. **Program Vocabulary ($n$):** Sum of unique operators and operands.
   $$n = n_1 + n_2$$
2. **Program Length ($N$):** Sum of total occurrences of operators and operands.
   $$N = N_1 + N_2$$
3. **Halstead Volume ($V$):** Number of bits of info the code contains.
   $$V = N \times \log_2(n)$$
4. **Difficulty ($D$):** Difficulty in writing or understanding the code.
   $$D = \frac{n_1}{2} \times \frac{N_2}{n_2}$$
5. **Effort ($E$):** Mental cost spent on implementation.
   $$E = D \times V$$

Among these, **Halstead Volume** is used as a core input for calculating the Maintainability Index (MI), representing the informational size of code rather than its physical size.

### **4.3 Maintainability Index (MI)**

The Maintainability Index is a composite metric representing the ease of code modification as a score between 0 and 100. `dart-code-metrics` adopts a modified formula used in Microsoft Visual Studio for intuitive score understanding.

Formula:
$$MI_{orig} = 171 - 5.2 \ln(V) - 0.23 G - 16.2 \ln(SLOC)$$
$$MI = \max\left(0, \frac{MI_{orig} \times 100}{171}\right)$$
Where $V$ is Halstead Volume, $G$ is cyclomatic complexity, and $SLOC$ is source lines of code.

**Interpretation:**
* **80 ~ 100:** Easy to Maintain (Green)
* **50 ~ 79:** Average (Yellow)
* **0 ~ 49:** Hard to Maintain (Red)

This formula is designed so that the score decreases on a log scale with larger volume, higher complexity, or more lines, encouraging the separation of code into small functions.

### **4.4 Technical Debt**

DCM assigns a "Cost" to each violation and sums them to calculate technical debt. This helps managers understand code quality degradation from a cost perspective.

* **Cost Calculation:**
  * Lint Violations: Fixed cost per rule (e.g., `avoid-dynamic`: $16)
  * Metric Overages: Cost proportional to the excess over the threshold
  * TODO Comments: Cost for unresolved tasks

## **5. Differences and Comparative Analysis with Built-in Dart Analyzer**

While `dart-code-metrics` complements rather than replaces the Dart Analyzer, it shows clear differences in its design philosophy and analysis scope.

### **5.1 Analysis Philosophy: Conservative vs. Opinionated**

* **Dart Analyzer (Lints):** Managed by Google's Dart team, focusing on "general" error prevention and adherence to the "Effective Dart" style guide. It tends to be conservative, not including rules that might have false positives or are controversial in the default lint sets (`lints`, `flutter_lints`).
* **dart-code-metrics:** Includes many "opinionated" rules. For example, `prefer-trailing-comma` demands a specific style, and rules like `avoid-passing-async-when-sync-expected` point out potential runtime performance issues. Also, complexity-based anti-pattern detection like `long-method` or `long-parameter-list` is a feature not present in the built-in analyzer.

### **5.2 Functional Comparison Table**

Below is a table comparing the main features of the two tools from a technical perspective.

| Feature | Dart Built-in Analyzer | dart-code-metrics (Legacy) |
| :---- | :---- | :---- |
| **Analysis Engine** | Direct integration with Analysis Server (Native) | Analysis Server Plugin (Isolated) |
| **Metric Calculation** | Not supported beyond basic line count | Supports Cyclomatic, Halstead, MI, Technical Debt |
| **Anti-patterns** | Not supported | Detects structural flaws like Long Method, Heavy Class |
| **Configuration** | `analysis_options.yaml` (Simple On/Off) | `analysis_options.yaml` (Detailed settings for thresholds, regex, etc.) |
| **Reporting** | Console text output | Diverse, including HTML, JSON, CodeClimate, GitHub Annotations |
| **Extensibility** | Hard to write custom rules (requires SDK contribution) | Extensible via plugin API (but performance issues exist) |

### **5.3 Technical Significance of Anti-pattern Detection**

The built-in analyzer primarily examines "local" grammar errors or styles. In contrast, `dart-code-metrics` handles "global" or "structural" problems. For example, the `Weight of Class` metric combines the number of methods, number of fields, and size of the public interface in a class to identify the "God Class" anti-pattern—a mechanical attempt to detect Single Responsibility Principle (SRP) violations.

## **6. Technical Limitations and Structural Bottlenecks**

Despite providing powerful features, `dart-code-metrics` faced serious performance and scalability issues due to inherent limitations in the Dart plugin system. This ultimately led to the archiving of the project and the transition to the new commercial product (DCM).

### **6.1 Memory Consumption and the "Double AST" Problem**

As mentioned in Section 2.2, the plugin Isolate does not share memory with the main server.

* **Redundant Parsing:** Since the AST info already parsed and resolved by the main server cannot be reused, the plugin must re-parse and re-resolve the same source code. The cost of generating a `ResolvedUnitResult` is very high and increases with the number of files in large projects (monorepos).
* **Memory Bloat:** Consequently, analyzing the same project consumes 2 to 3 times more memory than using the built-in analyzer alone. Even on development machines with over 10GB of RAM, it frequently occupied over 1GB of heap memory, triggering OOM (Out of Memory) crashes.

### **6.2 Serialization Overhead and Latency**

The cost of data serialization/deserialization for inter-Isolate communication impairs the responsiveness of real-time analysis.

* **Event Flooding:** Numerous `edit` events and `analysis` requests generated as a user types pile up in the queue, and significant latency occurs as the plugin processes them and serializes results back. This leads to a stuttering experience in IDE syntax highlighting or auto-completion.
* **Context Root Management:** Logic for the plugin to detect file system changes and manage analysis targets (Context Root) runs redundantly with the main server, adding to the file system I/O load.

### **6.3 Version Dependency Conflicts (Dependency Hell)**

`dart-code-metrics` strongly depends on the Dart SDK's internal `analyzer` package. However, the `analyzer` package frequently has breaking changes in its API as the Dart language spec evolves.

* **Version Mismatch:** If the project's `analyzer` version used by the user differs from the one `dart-code-metrics` depends on, dependency resolution fails during `pub get`.
* **Maintenance Burden:** Every time the Dart SDK is updated, `dart-code-metrics` also had to be immediately updated and released, a structural vulnerability that placed an excessive maintenance burden on open-source maintainers.

## **7. Transitioning to a Next-Generation Architecture: DCM (New Dart Code Metrics)**

The limitations described above were structural issues that couldn't be solved within the existing plugin architecture. Thus, the development team made the decision to stop maintaining the `dart-code-metrics` package (deprecating it) and transition to **DCM**, a commercial tool with a completely new architecture.

### **7.1 Standalone Server Architecture**

The new DCM operates as an **independent language server** or **binary executable**, not a plugin for the Dart Analysis Server.

* **Native Compilation:** Instead of running from Dart source, it's distributed as a binary compiled to native machine language (AOT, Ahead-Of-Time). This drastically reduces startup time and eliminates JIT compilation overhead.
* **Rust and Optimized Internal Engine:** Some performance-critical modules are rewritten in system languages like Rust, or even when written in Dart, they use a lightweight AST model with unnecessary data removed, reducing memory usage by over 50%.
* **Unified Toolchain:** To solve dependency conflict issues, DCM takes the form of a toolchain that is installed and run independently of the project's `pubspec.yaml` dependencies.

These changes suggest that to overcome the performance limits encountered in managed language environments, static analysis tools should build a separate analysis infrastructure independent of the language runtime.

## **8. Conclusion and Implications**

`dart-code-metrics` was a pioneering tool that raised awareness of code quality in the Dart and Flutter development ecosystems and proved the necessity of quantitative metrics. Technically, it implemented complex semantic analysis by leveraging the power of Dart's `RecursiveAstVisitor` pattern and the `analyzer` package, but it also clearly illustrated the performance limits of the memory isolation model and serialization communication in the Dart Analysis Server's plugin architecture.

While the open-source version of `dart-code-metrics` is no longer maintained, the metric calculation algorithms (such as cyclomatic complexity including boolean operators) and the anti-pattern detection logic it established remain valid and form the basis of the new DCM tool. Developers should recognize the limits of legacy tools and consider strategic approaches like adopting standalone analysis tools optimized for performance in large projects or selectively using CLI mode in CI/CD pipelines.

These technical evolution processes show that static analysis tools are evolving beyond simple code checkers into 'data processing engines' that must efficiently handle large volumes of source code. Proportionally to the growth of the Dart ecosystem, the architecture of analysis tools is also expected to continue to advance.

---

**References**

1. `dart-code-checker/dart-code-metrics` - GitHub, accessed Dec 26, 2025, [https://github.com/dart-code-checker/dart-code-metrics](https://github.com/dart-code-checker/dart-code-metrics)
2. `steeple-org/flutter_package_dart_code_metrics` - GitHub, accessed Dec 26, 2025, [https://github.com/steeple-org/flutter_package_dart_code_metrics](https://github.com/steeple-org/flutter_package_dart_code_metrics)
3. Improving Code Quality With Dart Code Metrics | Wrike TechClub, accessed Dec 26, 2025, [https://medium.com/wriketechclub/improving-code-quality-with-dart-code-metrics-430a5e3e316d](https://medium.com/wriketechclub/improving-code-quality-with-dart-code-metrics-430a5e3e316d)
4. A brief introduction to the analysis server (and to me) - Google Groups, accessed Dec 26, 2025, [https://groups.google.com/a/dartlang.org/g/analyzer-discuss/c/d3pxsecsOhY](https://groups.google.com/a/dartlang.org/g/analyzer-discuss/c/d3pxsecsOhY)
5. AnalysisSession `getResolvedUnit2` is slower than AnalysisServer ..., accessed Dec 26, 2025, [https://github.com/dart-lang/sdk/issues/46914](https://github.com/dart-lang/sdk/issues/46914)
6. Analyzer plugins - Dart, accessed Dec 26, 2025, [https://dart.dev/tools/analyzer-plugins](https://dart.dev/tools/analyzer-plugins)
7. Creating a Custom Plugin for Dart Analyzer | by Dmitry Zhifarsky, accessed Dec 26, 2025, [https://medium.com/wriketechclub/creating-a-custom-plugin-for-dart-analyzer-48b76d81a239](https://medium.com/wriketechclub/creating-a-custom-plugin-for-dart-analyzer-48b76d81a239)
8. Announcing DCM for Teams - Dmitry Zhifarsky - Medium, accessed Dec 26, 2025, [https://incendial.medium.com/announcing-dcm-for-teams-84db2cffce99](https://incendial.medium.com/announcing-dcm-for-teams-84db2cffce99)
9. Dart Analyzer Plugin - Google Groups, accessed Dec 26, 2025, [https://groups.google.com/a/dartlang.org/g/analyzer-discuss/c/J3gVtRKfzcI](https://groups.google.com/a/dartlang.org/g/analyzer-discuss/c/J3gVtRKfzcI)
10. The Anatomy of Dart Code Analysis: Understanding Key Entities, accessed Dec 26, 2025, [https://medium.com/@lordjadawin/the-anatomy-of-dart-code-analysis-understanding-key-entities-ba75cf20d8ba](https://medium.com/@lordjadawin/the-anatomy-of-dart-code-analysis-understanding-key-entities-ba75cf20d8ba)
11. Finding Unused Files With Dart Code Metrics | by Dmitry Zhifarsky, accessed Dec 26, 2025, [https://medium.com/wriketechclub/finding-unused-files-with-dart-code-metrics-b9aba48ad7ca](https://medium.com/wriketechclub/finding-unused-files-with-dart-code-metrics-b9aba48ad7ca)
12. Cyclomatic Complexity Guide | How To Calculate & Test - Sonar, accessed Dec 26, 2025, [https://www.sonarsource.com/resources/library/cyclomatic-complexity/](https://www.sonarsource.com/resources/library/cyclomatic-complexity/)
13. Cyclomatic Complexity - Code Quality Tool for Flutter Developers, accessed Dec 26, 2025, [https://dcm.dev/docs/metrics/function/cyclomatic-complexity/](https://dcm.dev/docs/metrics/function/cyclomatic-complexity/)
14. Catching issues: A practical guide to DCM (Part 1) | by Jonas Uekötter, accessed Dec 26, 2025, [https://medium.com/@jonasuekoetter/catching-issues-a-practical-guide-to-dcm-part-1-c023109cab6d](https://medium.com/@jonasuekoetter/catching-issues-a-practical-guide-to-dcm-part-1-c023109cab6d)
15. cyclomatic complexity = 1 + #if statements? - Stack Overflow, accessed Dec 26, 2025, [https://stackoverflow.com/questions/24191174/cyclomatic-complexity-1-if-statements](https://stackoverflow.com/questions/24191174/cyclomatic-complexity-1-if-statements)
16. Halstead Volume | DCM - Code Quality Tool for Flutter Developers, accessed Dec 26, 2025, [https://dcm.dev/docs/metrics/function/halstead-volume/](https://dcm.dev/docs/metrics/function/halstead-volume/)
17. Halstead's Software Metrics - Software Engineering - GeeksforGeeks, accessed Dec 26, 2025, [https://www.geeksforgeeks.org/software-engineering/software-engineering-halsteads-software-metrics/](https://www.geeksforgeeks.org/software-engineering/software-engineering-halsteads-software-metrics/)
18. Maintainability Index | DCM - Code Quality Tool for Flutter Developers, accessed Dec 26, 2025, [https://dcm.dev/docs/metrics/function/maintainability-index/](https://dcm.dev/docs/metrics/function/maintainability-index/)
19. Visual Studio Code Metrics and the Maintainability index of switch ..., accessed Dec 26, 2025, [https://stackoverflow.com/questions/2936814/visual-studio-code-metrics-and-the-maintainability-index-of-switch-case](https://stackoverflow.com/questions/2936814/visual-studio-code-metrics-and-the-maintainability-index-of-switch-case)
20. Flutter Linting and Linter Comparison, accessed Dec 26, 2025, [https://rydmike.com/blog_flutter_linting.html](https://rydmike.com/blog_flutter_linting.html)
21. `dart-code-metrics/analysis_options.yaml` at master - GitHub, accessed Dec 26, 2025, [https://github.com/dart-code-checker/dart-code-metrics/blob/master/analysis_options.yaml](https://github.com/dart-code-checker/dart-code-metrics/blob/master/analysis_options.yaml)
22. Analyzer memory consumption after updating to Dart 2.19, accessed Dec 26, 2025, [https://groups.google.com/a/dartlang.org/g/analyzer-scalability/c/J6PydDEthKo](https://groups.google.com/a/dartlang.org/g/analyzer-scalability/c/J6PydDEthKo)
23. `dart analyze` reads more than it should for a single file analysis #48832, accessed Dec 26, 2025, [https://github.com/dart-lang/sdk/issues/48832](https://github.com/dart-lang/sdk/issues/48832)
24. Issue 15 - This Week in Dart, accessed Dec 26, 2025, [https://thisweekindart.dev/issues/issue-15](https://thisweekindart.dev/issues/issue-15)
25. [BUG] `dart_code_metrics` resolving error for local packages #289, accessed Dec 26, 2025, [https://github.com/dart-code-checker/dart-code-metrics/issues/289](https://github.com/dart-code-checker/dart-code-metrics/issues/289)
26. Cross-compiling Dart CLI applications with Codemagic, accessed Dec 26, 2025, [https://blog.codemagic.io/cross-compiling-dart-cli-applications-with-codemagic/](https://blog.codemagic.io/cross-compiling-dart-cli-applications-with-codemagic/)
