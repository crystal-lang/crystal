require "spec"
require "yaml"
require "../../../../src/compiler/crystal/**"

include Crystal

def implementations(code)
  code.lines.each_with_index do |line, line_number_0|
    if column_number = line.index('‸')
      code = code.gsub('‸', "")

      compiler = Compiler.new
      compiler.no_build = true
      result = compiler.compile(Compiler::Source.new(".", code), "fake-no-build")

      visitor = ImplementationsVisitor.new(Location.new(line_number_0+1, column_number, "."))
      visitor.process(result)

      return visitor.locations.map(&.to_s).sort
    end
  end

  raise "no cursor found in spec"
end

describe "implementations" do
  it "find top level method calls" do
    implementations("
def foo
  1
end

puts f‸oo
").should eq([".:2:1"])
  end
end
