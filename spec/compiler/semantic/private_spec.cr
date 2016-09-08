require "../../spec_helper"

describe "Semantic: private" do
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

  it "doesn't find private class in another file" do
    expect_raises Crystal::TypeException, "undefined constant Foo" do
      compiler = Compiler.new
      sources = [
        Compiler::Source.new("foo.cr", %(
                                          private class Foo
                                          end
                                        )),
        Compiler::Source.new("bar.cr", %(
                                          Foo
                                        )),
      ]
      compiler.no_codegen = true
      compiler.prelude = "empty"
      compiler.compile sources, "output"
    end
  end

  it "finds private type in same file" do
    compiler = Compiler.new
    sources = [
      Compiler::Source.new("foo.cr", %(
                                        private class Foo
                                          def foo
                                            1
                                          end
                                        end

                                        Foo.new.foo
                                      )),
    ]
    compiler.no_codegen = true
    compiler.prelude = "empty"
    compiler.compile sources, "output"
  end

  it "can use types in private type" do
    assert_type(%(
      private class Foo
        def initialize(@x : Int32)
        end

        def foo
          @x + 20
        end
      end

      Foo.new(10).foo
      )) { int32 }
  end

  it "can use class var initializer in private type" do
    assert_type(%(
      private class Foo
        @@x = 1

        def self.x
          @@x
        end
      end

      Foo.x
      ), inject_primitives: false) { int32 }
  end

  it "can use instance var initializer in private type" do
    assert_type(%(
      private class Foo
        @x = 1

        def x
          @x
        end
      end

      Foo.new.x
      ), inject_primitives: false) { int32 }
  end

  it "finds private class in macro expansion" do
    assert_type(%(
      private class Foo
        @x = 1

        def x
          @x
        end
      end

      macro foo
        Foo.new.x
      end

      foo
      ), inject_primitives: false) { int32 }
  end
end
