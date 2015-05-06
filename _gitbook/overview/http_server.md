# HTTP Server

A slightly more interesting example is an HTTP Server:

```ruby
require "http/server"

server = HTTP::Server.new(8080) do |request|
  HTTP::Response.ok "text/plain", "Hello world! The time is #{Time.now}"
end

puts "Listening on http://0.0.0.0:8080"
server.listen
```

The above code will make sense once you read the whole documentation, but we can already learn some things.

* You can [require](../syntax_and_semantics/requiring_files.html) code defined in other files:

    ```ruby
    require "http/server"
    ```
* You can define [local variables](../syntax_and_semantics/local_variables.html) without the need to specify their type:

    ```ruby
    server = HTTP::Server.new ...
    ```

* You program by invoking [methods](../syntax_and_semantics/classes_and_methods.html) (or sending messages) to objects.

    ```ruby
    HTTP::Server.new(8000) ...
    ...
    Time.now
    ...
    puts "Listening on http://0.0.0.0:8080"
    ...
    server.listen
    ```

* You can use code blocks, or simply [blocks](../syntax_and_semantics/blocks_and_procs.html), which are a very convenient way to reuse code and get some features from the functional world:

    ```ruby
    HTTP::Server.new(8080) do |request|
      ...
    end
    ```

* You can easily create strings with embedded content, known as string interpolation. The language comes with other [syntax](../syntax_and_semantics/literals.html) as well to create arrays, hashes, ranges, tuples and more:

    ```ruby
    "Hello world! The time is #{Time.now}"
    ```


