# **The Deep Structure of Dart Static Analysis: An Analysis Report on the Algorithms and Architectures of the SDK Analyzer and Dart Code Metrics**

## **1. Introduction: The Dual Structure of the Dart Static Analysis Ecosystem**

In modern software engineering, static analysis has become more than just a tool for preemptively catching errors; it is essential infrastructure that guarantees language type safety and enforces maintainable architecture. The Dart programming language ecosystem approaches static analysis through two distinct yet complementary axes. The first is the **built-in Dart SDK Analyzer**, which serves as an implementation of the Dart Language Specification and a frontend for the compiler. The second is **Dart Code Metrics (DCM)**, which quantitatively measures code complexity and maintainability.

This report provides a deep dive into the algorithmic foundations adopted by these two systems. It details the constraint-solving algorithms and flow analysis mechanisms used during lexical analysis, parsing, and semantic analysis by the SDK Analyzer. Simultaneously, it analyzes the mathematical models and implementation methods for Cyclomatic Complexity, Cognitive Complexity, and Halstead Complexity used by DCM to quantify code quality. Through this, we identify how the Dart development environment achieves the dual goals of 'correctness' and 'quality.'

## **2. Dart SDK Analyzer: The Engine for Semantic Correctness and Type Soundness**

The `package:analyzer` in the Dart SDK is not just a linter. It is the frontend of a compiler that transforms Dart code into a semantic model understandable by machines and the foundation that provides intelligent features to IDEs through the Language Server Protocol (LSP). This system uses deterministic algorithms to ensure a sound type system.

### **2.1 Evolution of Parsing and the Element Model**

The first step of static analysis is transforming source code into an Abstract Syntax Tree (AST). However, the Dart Analyzer goes beyond AST and elevates it into a higher-level 'Element Model.' Recently, the Dart Analyzer architecture underwent fundamental algorithmic changes to support Macros and Augmentation features.

#### **2.1.1 Separation of FragmentBuilder and ElementBuilder**

In the past, the analyzer had a simple structure that mapped source files and elements 1:1. However, the pattern matching introduced after Dart 3.0 and the upcoming macro system imply that a single logical element (e.g., a class) can be defined across multiple files or code generation stages. To solve this, the Analyzer adopted algorithms that separate the concepts of **Fragment** and **Element**.

* **Fragment Construction:** The `FragmentBuilder` algorithm traverses individual source files (or part files) to collect partial declarations. This stage assumes that each declaration might be incomplete.
* **Element Synthesis:** The `ElementBuilder` merges collected fragments to create a complete Element. During this process, each fragment is recorded in a Summary file via a unique identifier (ID), and these logically separated code pieces are reconstructed into one logical unit using these IDs during the linking phase.

This two-stage build algorithm maximizes analysis performance by allowing the compiler to recompute only changed fragments and quickly recombine them with existing elements during incremental compilation, rather than re-analyzing everything.

### **2.2 Constraint-Based Type Inference**

Dart's type inference system, particularly in determining types in generic function calls or collection literals, is not based on mere guesswork but on a **Constraint Solving** algorithm that resolves complex systems of inequalities.

#### **2.2.1 Constraint Generation**

The analyzer traverses code and collects constraints on a type variable $X$. For example, passing an `int` argument to a function `void fn<T>(T a)` causes the analyzer to internally generate a subtype constraint $int <: T$ (meaning `int` must be a subtype of `T`).

Constraints generally appear in two forms:

* **Upper Bound Constraint:** $X <: T$ ($X$ is a subtype of $T$)
* **Lower Bound Constraint:** $T <: X$ ($T$ is a subtype of $X$)

This algorithm accumulates constraints by scanning code context top-down and bottom-up simultaneously.

#### **2.2.2 Constraint Solving Algorithm**

For a set of collected constraints $C$, the analyzer must find the optimal type that satisfies variable $X$. During this process, **Least Upper Bound (LUB)** and **Greatest Lower Bound (GLB)** operations are primarily used.

1. **Merge:** By calculating the LUB of all lower bound constraints for $X$, it finds $Mb$ (the lower bound of X), and by calculating the GLB of all upper bound constraints, it finds $Mt$ (the upper bound of X). This forms a merged constraint: $Mb <: X <: Mt$.
2. **Substitution:** If the resolved type $Vi$ contains other unknown type variables, the analyzer substitutes them using a type schema. This is essential for solving F-Bounded Quantification problems when handling recursive generics like `class A<T extends A<T>>`.
3. **Optimal Solution Selection:** Between $Mb$ and $Mt$, the Dart language specification usually applies deterministic rules that prefer more specific types or choose `dynamic` or `Object?` depending on context.

This algorithm further strengthens type safety by throwing errors instead of allowing implicit `dynamic` when inference fails if `strict-inference` mode is active.

### **2.3 Flow Analysis and Type Promotion**

One of Dart's most powerful features, "Type Promotion," is powered by Control Flow Analysis (CFA) within function bodies. This occurs when the compiler can guarantee that a variable's type is more specific than its declared type.

#### **2.3.1 Reachability and the Variable Model**

The analyzer maintains a **Flow Model** at each point (Node) in the program. This model tracks two core states:

| Component | Description | Algorithmic Role |
| :---- | :---- | :---- |
| **Reachability** | Whether the current execution point is logically reachable | Identifies code following `return`, `throw`, or `break` as 'Dead Code.' Manages reachability of nested control structures using a flow model stack. |
| **Variable Model** | Current state of each local variable (assignment status, type, etc.) | Tracks if a variable is 'Definitely Assigned' or if it has been 'Promoted' to a specific type. |

#### **2.3.2 Join and Split Algorithms**

When control flow branches (e.g., `if-else`) or merges, the analyzer splits or joins the models.

* **Branch Handling:** When encountering an `if (E)` statement, the analyzer generates a model `true(E)` for when condition `E` is true and a model `false(E)` for when it is false. For example, if `E` is `x is String`, variable `x` is promoted to type `String` in the `true(E)` model.
* **Join Logic:** When branched flows merge again (Merge Point), a variable's state is calculated as the **intersection** of the two flows. That is, if variable `x` was promoted to `String` in both the `if` and `else` blocks, it remains `String` after the join; however, if it was promoted in only one side, the promotion is invalidated. This can be expressed as $Promotion(x)_{after} = Promotion(x)_{then} \cap Promotion(x)_{else}$.

#### **2.3.3 Conservative Join and Loops**

Handling variables within a loop or a closure is much more complex. A loop could run any number of times, and a closure could be executed at any time. Thus, the analyzer uses a **Conservative Join** algorithm. If there's any possibility of a variable being re-assigned within a loop, it invalidates all type promotion info it had before entering the loop. This serves as a safeguard against runtime type errors.

### **2.4 Constant Evaluation and Symbolic Execution**

The `const` keyword in Dart signifies that a value must be determined at compile time. To achieve this, the analyzer performs **Symbolic Execution** without actually running the code.

* **Symbolic Value:** The analyzer represents constants using a wrapper class called `DartObject`. Literals and constant expressions in source code are transformed into this `DartObject`, and operators (`+`, `*`, etc.) are simulated via symbolic operations rather than actual CPU operations.
* **Dependency Graphs and Cycle Detection:** If constants reference each other (e.g., `const A = B; const B = A;`), the analyzer must detect this. To do so, it builds a dependency graph between constants and checks for cycles using a topological sort algorithm. If a cycle is found, it throws a compile-time error.

## **3. Dart Code Metrics (DCM): Quantitative Algorithms for Measuring Code Quality**

While the Dart SDK Analyzer determines the 'right or wrong' of code, Dart Code Metrics (DCM) assesses 'complexity' and 'maintainability.' DCM operates on top of the Analyzer's plugin architecture and calculates various software engineering metrics via the Visitor pattern traversing the AST.

### **3.1 Cyclomatic Complexity**

Cyclomatic complexity is a metric devised by Thomas McCabe that measures the number of linearly independent paths in a program's Control Flow Graph (CFG). DCM implemented this for the specifics of the Dart language.

#### **3.1.1 Measurement Algorithm based on Dart AST**

DCM's `RecursiveAstVisitor` traverses the AST and increments a complexity score whenever it encounters a keyword that branches the control flow. The base score is 1, and the following elements increase it:

1. **Control Statements:** `if`, `while`, `do-while`, and `for` statements each add +1 point.
2. **Conditional Operators:** The ternary operator `? :` also generates a branch, adding +1 point.
3. **Logical Operators:** `&&` and `||` create hidden branches due to short-circuit evaluation, each adding +1 point.
4. **Switch Statements:** DCM adds +1 point for each `case` block in a `switch` statement (excluding `default`). This reflecting that complexity increases linearly with more cases.
5. **Null-aware Operators (Dart-specific):** Dart's characteristic null-aware operators like `?.`, `??`, `??=`, and `...?` imply branches like `if (x != null)` and are thus considered elements that increase complexity.

#### **3.1.2 Specifics of Asynchrony (Await) Handling**

Based on analysis of DCM documentation, the `await` keyword itself is not listed as an element that directly increases cyclomatic complexity. This is because `await` suspends execution but is considered to maintain a linear flow without generating a logical branch unless exception handling is involved. However, DCM detects misuse of `await` (e.g., calling within a synchronous function) through separate lint rules, controlling it from a correctness perspective rather than complexity.

### **3.2 Cognitive Complexity**

While cyclomatic complexity measures "how hard it is to test," cognitive complexity measures "how hard it is for a human to understand." This algorithm applies the model proposed by SonarQube to Dart.

#### **3.2.1 Nesting Penalty Algorithm**

The core of the cognitive complexity algorithm is assigning weight to **Nesting**.

* **Basic Increment:** Structures that break the flow of reading code (`if`, `else`, `for`, `switch`, `catch`) receive a base score of +1.
* **Nesting Increment:** When a control structure is nested within another, extra points equal to the nesting level are assigned.
  * Level 0 `if`: +1 point.
  * Level 1 `if` (inside another `if`): +2 points (Basic 1 + Nesting 1).
  * Level 2 `if`: +3 points.

#### **3.2.2 Differentiation of Structural Weights**

Unlike cyclomatic complexity, cognitive complexity handles `switch` statements more leniently. Since a `switch` statement is often perceived as a single mapping table by human cognitive structures even with many branches, it assigns only +1 point to the entire `switch` regardless of the number of cases. Furthermore, consecutive logical operators (`A && B && C`) are treated as a single logical block rather than individual operators, assigning only +1 point to more realistically reflect code readability.

### **3.3 Halstead Complexity**

Halstead metrics measure the 'physical' properties of code by viewing it as a sequence of operators and operands and examining their statistical characteristics.

#### **3.3.1 Dart Token Classification Algorithm**

DCM decomposes Dart source into a token stream and classifies them as follows:

| Category | Elements Included | Note |
| :---- | :---- | :---- |
| **Operators** | Arithmetic (`+`, `-`), Logical (`&&`, `!`), Assignment (`=`), Comparison (`==`), Control Keywords (`if`, `return`, `await`, etc.), Parentheses and Punctuation | Includes all elements responsible for control flow or value transformation. |
| **Operands** | Variable names, Function names, Literals (`String`, `int`, `bool`), Class names | All elements representing data or identifiers. |

#### **3.3.2 Metric Calculation Formulas**

Based on the number of unique operators ($n_1$), unique operands ($n_2$), total operators ($N_1$), and total operands ($N_2$), the following metrics are calculated:

* **Program Vocabulary ($n$):** $n = n_1 + n_2$
* **Program Length ($N$):** $N = N_1 + N_2$
* **Halstead Volume ($V$):** $V = N \times \log_2(n)$
  * This represents the number of bits of information the code contains.
* **Difficulty ($D$):** $D = (n_1 / 2) \times (N_2 / n_2)$
  * Indicates how difficult it is to write or understand the code.
* **Effort ($E$):** $E = D \times V$
  * Represents a numerical value for the mental effort put into implementing the code.

### **3.4 Maintainability Index**

DCM synthesizes the previously calculated metrics into a single Maintainability Index (MI). This formula combines lines of code (LOC), Halstead volume, and cyclomatic complexity, using a log scale to reflect how the index drops rapidly as code size increases and then levels off.

$$MI = \max(0, (171 - 5.2 \ln(V) - 0.23 G - 16.2 \ln(LOC)) \times 100 / 171)$$
Where $V$ is Halstead volume, $G$ is cyclomatic complexity, and $LOC$ is lines of code. The resulting value is normalized between 0 and 100, where higher values indicate easier maintainability.

## **4. Algorithms for Anti-pattern Detection and Rule Verification**

Beyond mere numerical calculations, DCM includes heuristic algorithms for detecting structural problems in code.

### **4.1 Unused Code Detection: Reachability Graph**

Unused code detection cannot be achieved with simple text searches. DCM uses a **Reference Graph** algorithm for this purpose.

1. **Collection of Declarations:** All class, function, and variable declarations within the analyzed files are indexed. Private members starting with an underscore (_) are tracked with particular focus.
2. **Reference Tracking:** It traverses the AST and creates graph edges for where each identifier is referenced.
3. **Set Subtraction:** It subtracts the set of declarations present in the reference graph (the reachable ones) from the total set of private declarations. Elements in this difference set are classified as 'unused code.' During this process, it utilizes the Analyzer's `ResolvedUnitResult` to resolve reference relationships between Dart part files or libraries.

### **4.2 Copy-Paste Detection**

Code duplication is an enemy of maintainability. DCM uses a variant of the **Rabin-Karp algorithm** or **AST hashing** to detect this. After tokenizing source code, it calculates hash values as it slides across a window of a certain size. If code blocks with identical hash values are found, they are treated as potential duplicates, and a precise comparison is performed. This method excels at finding logical structure similarities while ignoring differences in whitespace or comments.

### **4.3 God Class and Anti-pattern Thresholds**

The 'God Class' anti-pattern, where a particular class takes on too much responsibility, is detected via a multi-threshold algorithm. DCM simultaneously checks metrics like `number-of-methods`, `number-of-fields`, and `lines-of-code`. It only flags a class as an anti-pattern when multiple conditions are satisfied via a logical AND, such as when the number of methods exceeds 20 and the number of fields exceeds 10. This algorithmic design aims to reduce false positives that might occur when judging based on a single metric alone.

## **5. Comparative Analysis and Conclusion: Complementary Evolution**

### **5.1 Correctness vs. Empirical Judgment**

This analysis reveals that the Dart SDK Analyzer and DCM operate under fundamentally different philosophies.

* The **SDK Analyzer** operates in the realm of **mathematical proof**. Type inference and flow analysis must guarantee 100% execution safety of code based on constraint logic and set theory. Thus, it adopts conservative algorithms and judges on the side of safety (invalidating type promotion) in cases of uncertainty (e.g., variables within a loop).
* **DCM** operates in the realm of **empirical statistics**. Cognitive complexity and the maintainability index are not absolute truths but approximations based on decades of software engineering data. Thus, DCM's algorithms are tuned to mimic human cognitive models.

### **5.2 Architectural Integration**

Technically, DCM does not have an independent parser and relies entirely on the AST and Element Model generated by the SDK Analyzer. This means DCM is immediately affected by the evolution of the SDK (e.g., introduction of new syntax). As the SDK Analyzer strengthens incremental analysis features through `FragmentBuilder` and elsewhere, DCM also faces the task of optimizing its algorithms to perform delta analysis on changed elements rather than re-analyzing entire files.

In conclusion, Dart developers should adopt a dual strategy of preventing **runtime errors** through the SDK Analyzer's strict type checking and reducing **maintainability costs** through DCM's multi-faceted complexity analysis. A deep understanding of the algorithmic characteristics of these two tools is an essential competency for designing high-quality, robust Dart/Flutter applications.

#### **References**

1. c0bca2c2100b6d9775879d9c16..., accessed Dec 26, 2025, [https://dart.googlesource.com/sdk/+/c0bca2c2100b6d9775879d9c16966962571496b6](https://dart.googlesource.com/sdk/+/c0bca2c2100b6d9775879d9c16966962571496b6)
2. language/resources/type-system/inference.md at main - GitHub, accessed Dec 26, 2025, [https://github.com/dart-lang/language/blob/main/resources/type-system/inference.md](https://github.com/dart-lang/language/blob/main/resources/type-system/inference.md)
3. Type inference does not solve some constraints involving F-bounds, accessed Dec 26, 2025, [https://github.com/dart-lang/language/issues/3009](https://github.com/dart-lang/language/issues/3009)
4. Customizing static analysis - Dart, accessed Dec 26, 2025, [https://dart.dev/tools/analysis](https://dart.dev/tools/analysis)
5. flow-analysis.md - dart-lang/language - GitHub, accessed Dec 26, 2025, [https://github.com/dart-lang/language/blob/main/resources/type-system/flow-analysis.md](https://github.com/dart-lang/language/blob/main/resources/type-system/flow-analysis.md)
6. dart/constant/value library - Pub.dev, accessed Dec 26, 2025, [https://pub.dev/documentation/analyzer/latest/dart_constant_value](https://pub.dev/documentation/analyzer/latest/dart_constant_value)
7. The Dart type system, accessed Dec 26, 2025, [https://dart.dev/language/type-system](https://dart.dev/language/type-system)
8. Cyclomatic Complexity | DCM - Code Quality Tool for Flutter ..., accessed Dec 26, 2025, [https://dcm.dev/docs/metrics/function/cyclomatic-complexity/](https://dcm.dev/docs/metrics/function/cyclomatic-complexity/)
9. Dart static code analysis | brain-overload - Rules Sonarsource, accessed Dec 26, 2025, [https://rules.sonarsource.com/dart/tag/brain-overload/rspec-3776/](https://rules.sonarsource.com/dart/tag/brain-overload/rspec-3776/)
10. Cognitive Complexity of functions should not be too high - Projects, accessed Dec 26, 2025, [https://next.sonarqube.com/sonarqube/coding_rules?open=javascript:S3776&rule_key=javascript:S3776](https://next.sonarqube.com/sonarqube/coding_rules?open=javascript:S3776&rule_key=javascript:S3776)
11. {Cognitive Complexity} a new way of measuring understandability, accessed Dec 26, 2025, [https://www.sonarsource.com/docs/CognitiveComplexity.pdf](https://www.sonarsource.com/docs/CognitiveComplexity.pdf)
12. Halstead Volume | DCM - Code Quality Tool for Flutter Developers, accessed Dec 26, 2025, [https://dcm.dev/docs/metrics/function/halstead-volume/](https://dcm.dev/docs/metrics/function/halstead-volume/)
13. 7 Code Complexity Metrics Developers Must Track - Daily.dev, accessed Dec 26, 2025, [https://daily.dev/blog/7-code-complexity-metrics-developers-must-track](https://daily.dev/blog/7-code-complexity-metrics-developers-must-track)
14. dart_code_linter | Dart package - Pub.dev, accessed Dec 26, 2025, [https://pub.dev/packages/dart_code_linter](https://pub.dev/packages/dart_code_linter)
15. What's new in DCM 1.11.0 - Code Quality Tool for Flutter Developers, accessed Dec 26, 2025, [https://dcm.dev/blog/2023/11/07/whats-new-in-dcm-1-11-0/](https://dcm.dev/blog/2023/11/07/whats-new-in-dcm-1-11-0/)
16. Creating a Custom Plugin for Dart Analyzer | by Dmitry Zhifarsky, accessed Dec 26, 2025, [https://medium.com/wriketechclub/creating-a-custom-plugin-for-dart-analyzer-48b76d81a239](https://medium.com/wriketechclub/creating-a-custom-plugin-for-dart-analyzer-48b76d81a239)
