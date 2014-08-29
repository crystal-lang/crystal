# Pointer

The `Pointer(T)` type is a generic, built-in, low-level, **unsafe** type. It's used to interface with C and to implement some data structures efficiently, like `Array` and `Hash`.

You don't generally deal with pointers unless you are in one of the situations described above, and you are encouraged to limit their use as much as possible because of their unsafeness.

You can allocate some heap memory with `malloc`:

```ruby
# Allocate ten ints in the heap and get a pointer
# to the first one.
pointer = Pointer(Int32).malloc(10)
```

Memory allocated like this will be garbage collected when nobody referts to any part of it.

You can get and set the value a pointer points to with `value` and `value=`.

```ruby
pointer = Pointer(Int32).malloc(10)
pointer.value = 1
pointer.value #=> 1
```

You can make the pointer point to another value by using the `+` method:

```ruby
first = Pointer(Int32).malloc(10)
first.value = 1

second = first + 1
second.value = 3
second.value #=> 3

first.value #=> 1
```

The `+` method moves the pointer taking the type it points to into account. In the above example the pointer moved four bytes, because an `Int32` is represented by four bytes.

You can create a pointer to a given address with `new`:

```ruby
ptr = Pointer(Int32).new(0x108213fc0)
```

You can ask a pointer's address with `address`:

```ruby
ptr = Pointer(Int32).new(0x108213fc0)
ptr.address #=> 0x108213fc0
```

You can invoke `realloc` on a pointer to get a pointer that points to more/less memory, possibly reusing existing memory:

```ruby
ptr = Pointer(Int32).malloc(10)
another_ptr = ptr.realloc(20)
```

The standard library adds lots of methods to `Pointer` to make it easier to work with it:

```ruby
pointer = Pointer(Int32).malloc(10)
pointer[0] = 1
pointer[0] #=> 1

pointer[1] = 3
pointer[1] #=> 3
```

Moving the pointer outside the memory it allocated and getting/setting its value is undefined behaviour and will probably cause a segmentation fault. The standard library provides a `Slice` type that is a struct with a length and a pointer, with index bounds check, making it safer to deal with pointers (but also a bit slower).
