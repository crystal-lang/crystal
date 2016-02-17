require "../../spec_helper"

describe "Type inference: private def" do
  it "doesn't find private def in another file" do
    expect_raises Crystal::TypeException, "undefined local variable or method 'foo'" do
      compiler = Compiler.new
      sources = [
        Compiler::Source.new("foo.cr", %(
                                          private def foo
                                            1
                                          end
                                        )),
        Compiler::Source.new("bar.cr", %(
                                          foo
                                        )),
      ]
      compiler.no_codegen = true
      compiler.prelude = "empty"
      compiler.compile sources, "output"
    end
  end

  it "finds private def in same file" do
    compiler = Compiler.new
    sources = [
      Compiler::Source.new("foo.cr", %(
                                        private def foo
                                          1
                                        end

                                        foo
                                      )),
    ]
    compiler.no_codegen = true
    compiler.prelude = "empty"
    compiler.compile sources, "output"
  end

  it "finds private def in same file that invokes another def" do
    compiler = Compiler.new
    sources = [
      Compiler::Source.new("foo.cr", %(
                                        def bar
                                          2
                                        end

                                        private def foo
                                          bar
                                        end

                                        foo
                                      )),
    ]
    compiler.no_codegen = true
    compiler.prelude = "empty"
    compiler.compile sources, "output"
  end

  it "types private def correctly" do
    assert_type(%(
      private def foo
        1
      end

      def foo
        'a'
      end

      foo
      )) { int32 }
  end

  it "doesn't find private macro in another file" do
    expect_raises Crystal::TypeException, "undefined local variable or method 'foo'" do
      compiler = Compiler.new
      sources = [
        Compiler::Source.new("foo.cr", %(
                                          private macro foo
                                            1
                                          end
                                        )),
        Compiler::Source.new("bar.cr", %(
                                          foo
                                        )),
      ]
      compiler.no_codegen = true
      compiler.prelude = "empty"
      compiler.compile sources, "output"
    end
  end

  it "finds private macro in same file" do
    compiler = Compiler.new
    sources = [
      Compiler::Source.new("foo.cr", %(
                                        private macro foo
                                          1
                                        end

                                        foo
                                      )),
    ]
    compiler.no_codegen = true
    compiler.prelude = "empty"
    compiler.compile sources, "output"
  end

  it "finds private macro in same file, invoking from another macro (#1265)" do
    compiler = Compiler.new
    sources = [
      Compiler::Source.new("foo.cr", %(
                                        private macro foo
                                          1
                                        end

                                        macro bar
                                          foo
                                        end

                                        bar
                                      )),
    ]
    compiler.no_codegen = true
    compiler.prelude = "empty"
    compiler.compile sources, "output"
  end

  it "finds private def when invoking from inside macro (#2082)" do
    assert_type(%(
      private def foo
        42
      end

      {% begin %}
        foo
      {% end %}
      )) { int32 }
  end
end
