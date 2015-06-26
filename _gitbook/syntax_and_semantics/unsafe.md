# Unsafe code

These parts of the language are considered unsafe:

* Code involving raw pointers: the [Pointer](http://crystal-lang.org/api/Pointer.html) type and [pointerof](pointerof.html).
* The [allocate](new,_initialize_and_allocate.html) class method.
* Code involving C bindings
* [Uninitialized variable declaration](declare_var.html)

"Unsafe" means that memory corruption, segmentation faults and crashes are possible to achieve. For example:

```ruby
a = 1
ptr = pointerof(a)
ptr[100_000] = 2   # undefined behaviour, probably a segmentation fault
```

However, regular code usually never involves pointer manipulation or uninitialized variables. And C bindings are usually wrapped in safe wrappers that include null pointers and bounds checks.

No language is 100% safe: some parts will inevitably be low-level, interface with the operating system and involve pointer manipulation. But once you abstract that and operate on a higher level, and assume (after mathematical proof or thorough testing) that the lower grounds are safe, you can be confident that your entire codebase is safe.

