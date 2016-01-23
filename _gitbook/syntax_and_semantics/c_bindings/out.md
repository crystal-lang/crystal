# out

Consider the [waitpid](http://www.gnu.org/software/libc/manual/html_node/Process-Completion.html) function:

```crystal
lib C
  fun waitpid(pid : Int32, status_ptr : Int32*, options : Int32) : Int32
end
```

The documentation of the function says:

```
The status information from the child process is stored in the object
that status_ptr points to, unless status_ptr is a null pointer.
```

We can use this function like this:

```crystal
pid = ...
options = ...
status_ptr = uninitialized Int32

C.waitpid(pid, pointerof(status_ptr), options)
```

In this way we pass a pointer of `status_ptr` to the function for it to fill its value.

There's a simpler way to write the above by using an `out` parameter:

```crystal
pid = ...
options = ...

C.waitpid(pid, out status_ptr, options)
```

The compiler will automatically declare a `status_ptr` variable of type `Int32`, because the argument is an `Int32*`.

This will work for any type, as long as the argument is a pointer of that type (and, of course, as long as the function does fill the value the pointer is pointing to).
