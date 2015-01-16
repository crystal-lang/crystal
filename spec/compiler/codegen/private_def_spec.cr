require "../../spec_helper"

describe "Codegen: private def" do
  it "codegens private def in same file" do
    compiler = Compiler.new
    sources = [
      Compiler::Source.new("foo.cr", %(
                                        private def foo
                                          1
                                        end

                                        foo
                                      )),
    ]
    compiler.prelude = "empty"

    tempfile = Tempfile.new("crystal-spec-output")
    output_filename = tempfile.path
    tempfile.close

    compiler.compile sources, output_filename
  end

  it "codegens overloaded private def in same file" do
    compiler = Compiler.new
    sources = [
      Compiler::Source.new("foo.cr", %(
                                        private def foo(x : Int32)
                                          1
                                        end

                                        private def foo(x : Char)
                                          2
                                        end

                                        a = 3 || 'a'
                                        foo a
                                      )),
    ]
    compiler.prelude = "empty"

    tempfile = Tempfile.new("crystal-spec-output")
    output_filename = tempfile.path
    tempfile.close

    compiler.compile sources, output_filename
  end
end
