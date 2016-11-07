require "../spec_helper"
require "tempfile"

describe "Backtrace" do
  it "prints file line:colunm" do
    tempfile = Tempfile.new("compiler_spec_output")
    tempfile.close
    sample = "#{__DIR__}/data/backtrace_sample"

    `bin/crystal build --debug #{sample.inspect} -o #{tempfile.path.inspect}`
    File.exists?(tempfile.path).should be_true

    {% if flag?(:darwin) %}
      `dsymutil --flat #{tempfile.path}`
    {% end %}

    output = `#{tempfile.path}`

    output.should match(/#{sample} 3:10/) # callee1
    output.should match(/#{sample} 15:3/) # callee3
    output.should match(/#{sample} 17:1/) # ???
  end
end
