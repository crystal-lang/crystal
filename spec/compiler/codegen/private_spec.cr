require "../../spec_helper"

describe "Codegen: private" do
  it "codegens private def in same file" do
    compiler = create_spec_compiler
    sources = [
      Compiler::Source.new("foo.cr", %(
                                        private def foo
                                          1
                                        end

                                        foo
                                      )),
    ]
    compiler.prelude = "empty"

    with_temp_executable "crystal-spec-output" do |output_filename|
      compiler.compile sources, output_filename
    end
  end

  it "codegens overloaded private def in same file" do
    compiler = create_spec_compiler
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

    with_temp_executable "crystal-spec-output" do |output_filename|
      compiler.compile sources, output_filename
    end
  end

  it "codegens class var of private type with same name as public type (#11620)" do
    src1 = Compiler::Source.new("foo.cr", <<-CRYSTAL)
      module Foo
        @@x = true
      end
      CRYSTAL

    src2 = Compiler::Source.new("foo_private.cr", <<-CRYSTAL)
      private module Foo
        @@x = 1
      end
      CRYSTAL

    compiler = create_spec_compiler
    compiler.prelude = "empty"
    with_temp_executable "crystal-spec-output" do |output_filename|
      compiler.compile [src1, src2], output_filename
    end
  end

  it "codegens class vars of private types with same name (#11620)" do
    src1 = Compiler::Source.new("foo1.cr", <<-CRYSTAL)
      private module Foo
        @@x = true
      end
      CRYSTAL

    src2 = Compiler::Source.new("foo2.cr", <<-CRYSTAL)
      private module Foo
        @@x = 1
      end
      CRYSTAL

    compiler = create_spec_compiler
    compiler.prelude = "empty"
    with_temp_executable "crystal-spec-output" do |output_filename|
      compiler.compile [src1, src2], output_filename
    end
  end

  it "doesn't include filename for private types" do
    run(%(
      private class Foo
        def foo
          {{@type.stringify}}
        end
      end

      Foo.new.foo
      ), filename: "foo").to_string.should eq("Foo")
  end
end
