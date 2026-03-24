[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Memory Part 1: ARC, Weak Pointers, and the "Leaking Trap"

Memory management in Monkey C is governed by **Automatic Reference Counting (ARC)**. While this sounds like it's "automatic," it requires careful engineering to avoid crashing your app on devices with limited heap space like the FR 265 and VA 6.

---

## 🔗 Related Documentation
- [Monkey C Language Guide](../language/MONKEY_C_GUIDE.md)

---

## 1. How ARC Works
Every object in your code (Arrays, Classes, Dictionaries) has a "Reference Count."
- **Count increases**: When you assign an object to a variable or pass it to a function.
- **Count decreases**: When a variable goes out of scope or is set to `null`.
- **Cleanup**: When the count hits **zero**, the object is immediately destroyed and its memory is reclaimed.

---

## 2. The "Circular Reference" Trap
ARC has one fatal flaw: it cannot handle **circular loops**.

### The Scenario:
- Object A holds a reference to Object B.
- Object B holds a reference to Object A.
- Both objects now have a reference count of at least **1**.

### The Leak:
If you delete your primary reference to Object A, its count drops, but Object B still points to it (count = 1). Object B's count stays at 1 because Object A still points to it. Since neither count will ever hit zero, they stay in memory **forever**, even if they are unreachable by the rest of your app.

---

## 3. The Solution: `WeakReference`
To break a circular loop, use a **Weak Pointer**. A weak reference does not increment the reference count.

### Breaking the Cycle:
```monkeyc
class Parent {
    var child;
    function initialize() {
        child = new Child(self.weak()); // Pass a weak reference to 'self'
    }
}

class Child {
    var parentRef;
    function initialize(parent) {
        parentRef = parent; // This is a weak reference
    }

    function doSomething() {
        var strongParent = parentRef.get(); // Resolve to a strong pointer
        if (strongParent != null) {
            // Parent still exists
            strongParent.update();
        }
    }
}
```

---

## 4. Engineering Pro-Tips for ARC
1. **The `null` Reset**: If you are finished with a large object (like a bitmap or a massive array), explicitly set it to `null`. This triggers the ARC cleanup immediately rather than waiting for it to fall out of scope.
2. **Watch your Callbacks**: When passing a `method(:myFunc)` as a callback, you are creating a strong reference to the object containing that method. Be careful if that callback is stored in another object.
3. **The Simulator Tool**: Use **File > View Memory** in the simulator. If your "Object Count" keeps climbing every time you perform an action, you have a circular reference leak.

---

## 5. Summary: Strong vs. Weak
- **Strong Reference**: "I own this object. Don't delete it while I'm using it."
- **Weak Reference**: "I want to know about this object, but don't keep it alive just for me."

---

[Next: Object Overhead & Type Efficiency](MEM_PART2_OVERHEAD_AND_TYPES.md)
