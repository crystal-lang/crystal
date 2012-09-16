require 'spec_helper'

describe Compiler do
  it "uses a.out filename if no output specified" do
    ARGV.replace []
    compiler = Compiler.new
    compiler.command.should eq("llc | clang -x assembler -")
  end

  it "uses filename without extension when compiling file" do
    ARGV.replace ['foo.cr']
    compiler = Compiler.new
    compiler.command.should eq("llc | clang -x assembler -o foo -")
  end

  it "uses filename from -o switch without space" do
    ARGV.replace ['-otest', 'foo.cr']
    compiler = Compiler.new
    compiler.command.should eq("llc | clang -x assembler -o test -")
  end

  it "uses filename from -o switch with space" do
    ARGV.replace ['-o', 'test', 'foo.cr']
    compiler = Compiler.new
    compiler.command.should eq("llc | clang -x assembler -o test -")
  end
end