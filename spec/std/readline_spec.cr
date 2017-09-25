require "spec"
require "readline"

describe(Readline) do
  typeof(Readline.readline)
  typeof(Readline.readline("Hello", true))
  typeof(Readline.readline(prompt: "Hello"))
  typeof(Readline.readline(add_history: false))
  typeof(Readline.line_buffer)
  typeof(Readline.point)
  typeof(Readline.autocomplete { |s| %w(foo bar) })

  it("gets prefix in bytesize between two strings") do
    Readline.common_prefix_bytesize("", "foo").should eq(0)
    Readline.common_prefix_bytesize("foo", "").should eq(0)
    Readline.common_prefix_bytesize("a", "a").should eq(1)
    Readline.common_prefix_bytesize("open", "operate").should eq(3)
    Readline.common_prefix_bytesize("operate", "open").should eq(3)
    Readline.common_prefix_bytesize(["operate", "open", "optional"]).should eq(2)
  end
end
