# Attributes

Some types and methods can be annotated with attributes. The attribute list is fixed, but eventually (maybe) there will be user-defined attributes.

## Link

Tells the compiler how to link a C library. This is explained in the [lib](c_bindings/lib.html) section.

## ThreadLocal

The `@[ThreadLocal]` attribute can be applied to global variables and class variables. It makes them be thread local.

```ruby
# One for each thread
@[ThreadLocal]
$values = [] of Int32
```

## Packed

Allows marking a [C struct](c_bindings/struct.html) as packed, which makes the alignment of the struct to be one byte, and that there is no padding between the elements. In non-packed structs, padding between field types is inserted according to the target system.

## AlwaysInline

Gives a hint to the compiler to always inline a method:

```ruby
@[AlwaysInline]
def foo
  1
end
```

## NoInline

Tells the compiler to never inline a method call. This has no effect if the method yields.

```ruby
@[NoInline]
def foo
  1
end
```

## ReturnsTwice

Marks a method or [lib fun](c_bindings/fun.html) as returning twice. The C `setjmp` is an example of such a function.

## Raises

Marks a method or [lib fun](c_bindings/fun.html) as potentially raising an exception. This is explained in the [callbacks](c_bindings/callbacks.html) section.

## CallConvention

Indicates the call convention of a [lib fun](c_bindings/fun.html). For example:

```ruby
lib LibFoo
  @[CallConvention("X86_StdCall")]
  fun foo : Int32
end
```

The list of valid call conventions is:

* C (the default)
* Fast
* Cold
* WebKit_JS
* AnyReg
* X86_StdCall
* X86_FastCall

They are explained [here](http://llvm.org/docs/LangRef.html#calling-conventions).

## Flags

Marks an [enum](enum.html) as a "flags enum", which changes the behaviour of some of its methods, like `to_s`.
