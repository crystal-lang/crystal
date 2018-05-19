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

  it "find module private macro inside the module" do
    assert_type(%(
      class Foo
        private macro foo
          def bar
            1
          end
        end

        foo
      end

      Foo.new.bar
      )) { int32 }
  end

  it "find module private macro inside a module, which is inherited by the module" do
    assert_type(%(
      class Foo
        private macro foo
          def bar
            1
          end
        end
      end

      class Bar < Foo
        foo
      end

      Bar.new.bar
      )) { int32 }
  end

  it "doesn't find module private macro outside the module" do
    assert_error %(
      class Foo
        private macro foo
          1
        end
      end

      Foo.foo
    ), "private macro 'foo' called for Foo"
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

  it "doesn't find private class from outside namespace" do
    assert_error %(
      class Foo
        private class Bar
        end
      end

      Foo::Bar
      ),
      "private constant Foo::Bar referenced"
  end

  it "doesn't find private module from outside namespace" do
    assert_error %(
      class Foo
        private module Bar
        end
      end

      Foo::Bar
      ),
      "private constant Foo::Bar referenced"
  end

  it "doesn't find private enum from outside namespace" do
    assert_error %(
      class Foo
        private enum Bar
          A
        end
      end

      Foo::Bar
      ),
      "private constant Foo::Bar referenced"
  end

  it "doesn't find private alias from outside namespace" do
    assert_error %(
      class Foo
        private alias Bar = Int32
      end

      Foo::Bar
      ),
      "private constant Foo::Bar referenced"
  end

  it "doesn't find private lib from outside namespace" do
    assert_error %(
      class Foo
        private lib LibBar
        end
      end

      Foo::LibBar
      ),
      "private constant Foo::LibBar referenced"
  end

  it "doesn't find private constant from outside namespace" do
    assert_error %(
      class Foo
        private Bar = 1
      end

      Foo::Bar
      ),
      "private constant Foo::Bar referenced"
  end

  it "finds private type from inside namespace" do
    assert_type(%(
      class Foo
        private class Bar
          def self.foo
            1
          end
        end

        x = Bar.foo
      end

      x
      )) { int32 }
  end

  it "finds private type from inside namespace in subclass" do
    assert_type(%(
      class Foo
        private class Bar
          def self.foo
            1
          end
        end
      end

      class Foo2 < Foo
        x = Bar.foo
      end

      x
      )) { int32 }
  end

  it "gives private constant error in macro" do
    assert_error %(
      class Foo
        private class Bar
        end
      end

      {{ Foo::Bar }}
      ),
      "private constant Foo::Bar referenced"
  end

  it "applies bulk visibility" do
    result = semantic(%(
      class Foo
        def foo
        end

        private

        class Class
        end

        module Module
        end

        enum Enum
          A
        end

        lib Lib
        end

        alias Alias = Int32

        CONST = 1

        def bar
        end

        def baz
        end

        macro some_macro
        end

        public

        def qux
        end

        private

        def another
        end
      end

      def foo
      end
      ))

    program = result.program
    program.lookup_first_def("foo", false).not_nil!.visibility.should be_nil

    foo = program.types["Foo"]
    foo.lookup_first_def("foo", false).not_nil!.visibility.should be_nil
    foo.lookup_first_def("bar", false).not_nil!.visibility.should eq(Visibility::Private)
    foo.lookup_first_def("baz", false).not_nil!.visibility.should eq(Visibility::Private)
    foo.lookup_first_def("qux", false).not_nil!.visibility.should eq(Visibility::Public)
    foo.lookup_first_def("another", false).not_nil!.visibility.should eq(Visibility::Private)

    foo.lookup_macro("some_macro", [] of ASTNode, nil).as(Macro).visibility.should eq(Visibility::Private)

    foo.types["Class"].private?.should be_true
    foo.types["Module"].private?.should be_true
    foo.types["Enum"].private?.should be_true
    foo.types["Lib"].private?.should be_true
    foo.types["Alias"].private?.should be_true
    foo.types["CONST"].private?.should be_true
  end
end
