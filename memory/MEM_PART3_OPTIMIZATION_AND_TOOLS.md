[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Memory Part 3: Optimization & Debugging Tools

For the Forerunner 265 and Vivoactive 6, you will often find yourself "fighting for every kilobyte." These tools and flags are your primary weapons for shrinking your app's memory footprint.

---

## 1. The Monkey C Optimizer (Compiler Flags)
Garmin recently introduced a much more powerful optimizer.
- **`-O2` or `-O3` Flags**: These enable advanced optimizations like:
  - **Constant Folding**: Replacing `5 + 2` with `7` at compile-time.
  - **Dead Code Elimination**: Removing functions or modules that are never called.
  - **Type-Checking Speedups**: Reducing the runtime overhead of the gradual type system.
- **How to enable**: Add `optimizer_level = 2` to your `monkey.jungle` file or set it in your VS Code extension preferences.

---

## 2. Resource Mapping (The `Jungle` Strategy)
Memory constraints vary by device. The FR 265 has 128KB, while older watches might only have 64KB.
- **The Trick**: Use the **Jungles** system to exclude high-resolution bitmaps or fonts for lower-end devices while keeping them for your primary watches.
  ```jungle
  # Only include high-res assets for specific models
  fr265.resourcePath = $(base.resourcePath);resources-high-res
  ```

---

## 3. Debugging: The Memory Profile Tool
In the **Connect IQ Simulator**, go to **File > View Memory**.

### What to watch for:
1. **Object Count**: If this number is steadily increasing while your watchface is running, you have a **Memory Leak** (likely a circular reference).
2. **Handle Count**: If you hit the limit (e.g., 512), your app will crash even if you have free heap space.
3. **Peak Memory**: This shows the highest point your heap usage reached. If this is within 10% of your limit, your app may crash when a system event occurs (like a notification or low battery alert).

---

## 4. The "Symbol Not Found" Myth
Often, if your app runs out of memory, it doesn't just say "Out of Memory." It will crash with a **"Symbol Not Found"** error. 
- **The Reason**: When the heap is full, the VM cannot allocate the memory required to "look up" a method or variable name. If you see this error and *know* the method exists, check your memory usage first.

---

## 5. Pro Tip: Prettier Monkey C (The Optimizer)
A community-made tool by **markw65** (available as a VS Code extension) is the "gold standard" for Garmin optimization. It performs:
- **Minification**: Renames your long variable names (`mCurrentHeartRate`) to 1-character names (`a`) in the final PRG.
- **Aggressive Inlining**: Replaces function calls with their literal code, saving the overhead of a function call.
- **Dead Code Stripping**: Much more thorough than the official Garmin compiler.

---

## 6. Cleanup Checklist
- [ ] Are all large bitmaps set to `null` in `onHide()`?
- [ ] Did you use `parallel arrays` instead of `dictionaries`?
- [ ] Is `-O2` optimization enabled in your `monkey.jungle`?
- [ ] Have you checked for circular references using the simulator's memory tool?
- [ ] Are you using `Rez.Strings` instead of hardcoded strings?

---

[Prev: Object Overhead & Type Efficiency](MEM_PART2_OVERHEAD_AND_TYPES.md)
