require "../spec_helper"
require "tempfile"

describe "Compiler" do
  it "compiles a file" do
    tempfile = Tempfile.new "compiler_spec_output"
    tempfile.close

    Crystal::Command.run ["build", "#{__DIR__}/data/compiler_sample", "-o", tempfile.path]

    expect(File.exists?(tempfile.path)).to be_true

    expect(`#{tempfile.path}`).to eq("Hello!")
  end
end
