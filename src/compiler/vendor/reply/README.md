# REPLy

REPLy is a shard that provide a term reader for a REPL (Read Eval Print Loop).

## Features

It includes the following features:
* Multiline input
* History
* Pasting of large expressions
* Hook for Syntax highlighting
* Hook for Auto formatting
* Hook for Auto indentation
* Hook for Auto completion (Experimental)
* Work on Windows 10

It doesn't support yet:
* History reverse i-search
* Customizable hotkeys
* Unicode characters

NOTE: REPLy was extracted from https://github.com/I3oris/ic, it was first designed to fit exactly the usecase of a crystal interpreter, so don't hesitate to open an issue to make REPLy more generic and suitable for your project if needed.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     reply:
       github: I3oris/reply
   ```

2. Run `shards install`

## Usage

### Minimal example

```crystal
require "reply"

reader = Reply::Reader.new
reader.read_loop do |expression|
  # Eval expression here
  puts " => #{expression}"
end
```

### Customize the Interface

```crystal
require "reply"

class MyReader < Reply::Reader
  def prompt(io : IO, line_number : Int32, color? : Bool) : Nil
    # Display a custom prompt
  end

  def highlight(expression : String) : String
    # Highlight the expression
  end

  def continue?(expression : String) : Bool
    # Return whether the interface should continue on multiline, depending of the expression
  end

  def format(expression : String) : String?
    # Reformat when expression is submitted
  end

  def indentation_level(expression_before_cursor : String) : Int32?
    # Compute the indentation from the expression
  end

  def save_in_history?(expression : String) : Bool
    # Return whether the expression is saved in history
  end

  def auto_complete(name_filter : String, expression : String) : {String, Array(String)}
    # Return the auto-completion result from expression
  end
end
```

## Similar Project
* [fancyline](https://github.com/Papierkorb/fancyline)
* [crystal-readline](https://github.com/crystal-lang/crystal-readline)

## Development

Free to pull request!

## Contributing

1. Fork it (<https://github.com/I3oris/reply/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [I3oris](https://github.com/I3oris) - creator and maintainer
