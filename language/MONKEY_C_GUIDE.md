[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Monkey C: The Engineer's Deep Dive

---

## 🔗 Related Documentation
- [Memory Management: ARC & Leaks](../memory/MEM_PART1_ARC_AND_LEAKS.md)

---

## 1. Syntax Basics & Variables
### Declarations
- **`var`**: The standard variable declaration. Historically dynamic, but now supports type annotations.
- **`const`**: For compile-time constants.
- **`enum`**: Standard enumeration. Each member is assigned an integer starting from 0.

### Scoping
- **Global**: Declared outside any class or module.
- **Module**: Shared within a module namespace.
- **Class**: Member variables (instance or static).
- **Local**: Function-level scope.

---

## 2. The Type System (Connect IQ 4.0+)
Monkey C has evolved from a purely dynamic "duck-typed" language to a **gradual type system**.

### Type Annotations
Use the `as` keyword to define types for variables, parameters, and returns.
```monkeyc
var count as Number = 0;
function add(a as Number, b as Number) as Number {
    return a + b;
}
```

### Advanced Type Features
- **Union Types**: A variable can hold multiple defined types.
  - `var data as Number or String;`
- **Null Safety**: Types are non-nullable by default. Append `?` to allow null.
  - `var name as String? = null;`
- **Type Aliases (`typedef`)**:
  - `typedef MyPoint as { :x as Number, :y as Number };`
- **Type Casting**:
  - `var label = view.findDrawableById("TimeLabel") as WatchUi.Text;`

---

## 3. Basic Types & Collections
### Primitive Types
- **Numeric**: `Number` (32-bit int), `Long` (64-bit int), `Float` (32-bit), `Double` (64-bit).
- **Boolean**: `true` / `false`.
- **Char**: Unicode character.
- **String**: UTF-8 strings.

### Collections
- **Array**: Fixed-size or dynamic. Declared with `[]`.
  - `var arr = [1, 2, 3] as Array<Number>;`
- **Dictionary**: Key-value pairs. Uses `{}`.
  - `var map = { "id" => 101, "name" => "Garmin" } as Dictionary<String, Number or String>;`

---

## 4. Classes, Modules, and Inheritance
### Classes
- **`initialize()`**: The constructor. Always called via `ParentClass.initialize()` in subclasses.
- **Instance vs Static**: Methods and variables are instance-specific unless marked `static`.

### Inheritance
Uses the `extends` keyword.
```monkeyc
class BaseView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }
}
```

### Modules
Used for namespacing. Similar to packages in Java or namespaces in C++.
- **`using`**: Imports a module. Supports aliases: `using Toybox.WatchUi as Ui;`.

---

## 5. Control Flow & Capability Checking
### Standard Flow
- Supports `if/else`, `while`, `for`, `do/while`, and `switch`.

### The `instanceof` Operator
Used to check an object's type at runtime.
```monkeyc
if (myObj instanceof Lang.String) { ... }
```

### The `has` Operator (Critical for Compatibility)
Used for **Capability Checking**. Since Garmin firmware varies wildly, you MUST check if a class or method exists before calling it.
```monkeyc
if (Toybox has :Weather) {
    var conditions = Toybox.Weather.getCurrentConditions();
}
```

---

## 6. Methods as Objects (Callbacks)
Functions are not first-class objects. To pass a function as a callback (e.g., for a timer or sensor listener), you must wrap it in a **`Method`** object.
```monkeyc
// Creating a callback
var callback = method(:onTimerUpdate);
timer.start(callback, 1000, true);
```

---

## 7. Memory Management: The ARC System
Monkey C uses **Automatic Reference Counting (ARC)**.

### Pitfalls: Circular References
If Object A points to B, and B points to A, they will **never** be deallocated, causing a memory leak.

### The Solution: `WeakReference`
Use `WeakReference` to break circular loops.
```monkeyc
var strongObj = new MyClass();
var weakRef = strongObj.weak(); // Creates a WeakReference
var obj = weakRef.get(); // Returns the object or null if collected
```

---

## 8. Annotations & Conditional Compilation
Annotations provide metadata to the compiler.
- **`(:test)`**: Code included only during unit tests.
- **`(:background)`**: Marks code that can run in a background process (limited memory/APIs).
- **`(:typecheck)`**: Forces/configures type checking for a specific block.
- **Custom Exclusions**: You can define your own annotations in `monkey.jungle` to exclude code for specific watch models (e.g., `(:round)` vs `(:rect)`).

---

## 9. Exception Handling
Standard `try/catch/finally` blocks.
```monkeyc
try {
    var x = 5 / 0;
} catch (ex instanceof Lang.DivideByZeroException) {
    // Handle specific error
} catch (ex) {
    // Catch-all
} finally {
    // Cleanup
}
```

---

## 11. Symbols: The Core of Dynamic Monkey C
In Monkey C, a **Symbol** (prefixed with a colon, e.g., `:mySymbol`) is a unique identifier used by the VM. Symbols are used for:
- **Method Lookups**: Used with `method(:functionName)`.
- **Capability Checks**: Used with `has :symbol`.
- **Resource IDs**: All resources (images, fonts) are assigned symbols.

Symbols are more efficient than strings because they are resolved to integer IDs at compile-time, saving memory and processing power.

---

## 12. The `Rez` (Resources) System
Resources (layouts, fonts, bitmaps, strings) are defined in XML files within the `resources/` directory. The compiler automatically generates a `Rez` module that allows you to access these resources in your code.

### Accessing Resources
- **Drawables**: `Rez.Drawables.MyImage`
- **Fonts**: `Rez.Fonts.MyCustomFont`
- **Strings**: `WatchUi.loadResource(Rez.Strings.AppName)`
- **Layouts**: `Rez.Layouts.MainLayout(dc)`

### Why it matters:
Because resources are symbols, you can use the `has` operator to check if a resource exists for a specific device build, enabling powerful conditional UI logic.

---

## 13. Duck Typing vs. Static Typing
Historically, Monkey C was **purely duck-typed**. If an object had a method called `draw()`, you could call it regardless of the object's class. 

With the introduction of the **Gradual Type System**, you can now choose your level of safety:
1. **Dynamic (Legacy)**: No type annotations, maximum flexibility, higher risk of runtime `Symbol Not Found` errors.
2. **Static (Recommended)**: Explicit type annotations, compile-time safety, easier debugging, and better IDE completions.

**Pro-tip**: Use `(:typecheck)` annotations to selectively enable strict typing in performance-critical modules while keeping high-level UI logic dynamic.
