require "../spec_helper"

class FakeRootContext < Spec::RootContext
  def description
    "root"
  end

  def report_formatters(result)
  end
end

def all_spec_descriptions(item) : Array(String)
  child_descriptions = item.responds_to?(:children) ? item.children.flat_map { |c| all_spec_descriptions(c) } : [] of String
  child_descriptions.unshift(item.description)
end

def build_spec(filename, root = nil, count = 2)
  root ||= FakeRootContext.new
  name = filename.chomp(".cr")

  1.upto(count) do |i|
    line = (i - 1) * 10
    root.children << Spec::ExampleGroup.new(root, "context_#{name}_#{i}", filename, line + 1, line + 9, false, nil).tap do |c|
      c.children << Spec::Example.new(c, "example_#{name}_#{i}_1", filename, line + 2, line + 4, false, nil, nil)
      c.children << Spec::Example.new(c, "example_#{name}_#{i}_2", filename, line + 6, line + 8, false, nil, nil)
    end
  end

  root
end
