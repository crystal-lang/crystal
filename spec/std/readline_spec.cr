require "spec"
require "readline"

describe Readline do
  typeof(Readline.readline)
  typeof(Readline.readline("Hello", true))
  typeof(Readline.readline(prompt: "Hello"))
  typeof(Readline.readline(add_history: false))
  typeof(Readline.line_buffer)
  typeof(Readline.point)
  typeof(Readline.autocomplete { |s| %w(foo bar) })
end
