# Concurrency

To execute a block of code without blocking the main routine, use `spawn`:

```crystal
spawn do
  puts "Hello!"
end
```

The above program prints nothing because the program exited before the concurrent code could finish.
This is fine if you are implementing a sort of "fire and forget" operation.

To receive the output of a concurrent operation, implement a `Channel`:

```crystal
channel = Channel(String).new
spawn do
  channel.send "Hello!"
end
puts channel.receive
```

Now you will see "Hello!" printed.

Channels are concurrent "conduits" through which you can send and receive values.
A coroutine is a lightweight thread of execution.

Both `send` and `receive` are synchronous operations that block the current coroutine but not other coroutines.
Because of this behavior the above example implements `send` inside a `spawn` block.

`receive` will block the current coroutine until the number of `send`s match the number of `receive`s.
This allows you to send asynchronous operations down a channel and wait for all operations to complete before continuing.

For example, the following program will be blocked until the 2nd `channel.send` executes:

```crystal
channel = Channel(String).new
spawn do
  channel.send "Hello!"
end

spawn do
  sleep 1
  channel.send "World!"
end

puts channel.receive
puts channel.receive
```
