[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Memory Part 2: Object Overhead & Type Efficiency

In Monkey C, it's not just the *data* that costs memory—it's the *object* that holds it. On a Forerunner 265 or Vivoactive 6, understanding the hidden cost of a `Class` vs. a `Module` can be the difference between a working app and a crash.

---

## 1. The "Handle" Overhead
Every unique object (Array, Dictionary, Class Instance) consumes one **Handle**. 
- On older Garmin devices, there was a strict limit of 256 or 512 total handles.
- On modern devices like the FR 265, you are mostly limited by the **Heap Size** (e.g., 128 KB for watchfaces), but each handle still costs a few bytes in the VM's internal table.

---

## 2. Object Costs: Classes vs. Modules
### Classes (High Cost)
- **Base Class Instance**: ~96 bytes of overhead.
- **Each Member Variable**: ~12 bytes.
- **Inheritance**: Extending a class (e.g., `extends WatchUi.View`) adds another ~60 bytes of overhead.

### Modules (Zero Instance Cost)
- Modules are for namespacing and grouping functions.
- They have no "instance" cost. If you have a collection of utility functions, keep them in a **Module**, not a **Class**.

---

## 3. Collections: Array vs. Dictionary
This is the most critical trade-off in Garmin development.

### Arrays (The Winner)
- **Overhead**: Very low.
- **Access**: Fixed-time O(1) access.
- **Pro-Tip**: Use **Parallel Arrays** if you need key-value pairs. One array for IDs, one for names. This is much leaner than a Dictionary.

### Dictionaries (The Memory Eater)
- **Overhead**: Extremely high.
- **Why?**: They require a hash table, collision handling logic, and extra space for the keys.
- **Constraint**: **NEVER** use a Dictionary inside a high-frequency loop or for storing hundreds of items. You will blow the heap in seconds.

---

## 4. Primitives & Literals
- **Strings**: Large memory eaters.
  - *Tip*: Use `Rez.Strings` where possible. Resources are loaded from disk only when needed, while hardcoded strings in your code are always in memory.
- **Enums and Consts**: These don't have a "handle" cost but do take up "Code Space" (your PRG file size).
  - *Tip*: Use the **Monkey C Optimizer** (SDK 4.1+) to inline these as literal numbers during compilation.

---

## 5. Performance/Memory Trade-off: Local Variables
Accessing a class member (`self.x`) is slow and involves a lookup.
- **The Pro Hack**: In a performance-critical loop, copy a class member to a **Local Variable**.
  - Local variables are stored on the **Stack**, which is much faster than the **Heap** and has virtually zero lookup overhead.

---

## 6. Engineering Cheat Sheet
| Use Case | Recommended Type | Why? |
| :--- | :--- | :--- |
| **Storing data** | `Array` | Leanest footprint. |
| **Utility functions** | `Module` | Zero instance cost. |
| **UI Text** | `Rez.Strings` | External resource loading. |
| **Object lookup** | `Parallel Arrays` | Dictionaries are too heavy. |
| **Looping** | `Local Variable` | Fastest access, no heap lookup. |

---

[Prev: ARC & Leaks](MEM_PART1_ARC_AND_LEAKS.md) | [Next: Optimization & Tools](MEM_PART3_OPTIMIZATION_AND_TOOLS.md)
