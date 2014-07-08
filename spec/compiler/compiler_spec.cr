#!/usr/bin/env bin/crystal --run
require "../spec_helper"

describe "Compiler" do
  pending "compiles a file" do
    output_filename = "compiler_spec_output"

    tmp_fd = C.mkstemp output_filename
    C.close tmp_fd

    compiler = Compiler.new
    compiler.process_options(["#{__DIR__}/data/compiler_sample", "-o", output_filename])

    File.exists?(output_filename).should be_true

    Program.exec("./#{output_filename}").should eq("Hello!")
  end
end
