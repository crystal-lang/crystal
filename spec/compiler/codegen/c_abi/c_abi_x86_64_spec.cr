require "../../../spec_helper"

{% if flag?(:x86_64) %}
  describe "Code gen: C ABI x86_64" do
    it "passes struct less than 64 bits as { i64 }" do
      mod = codegen(%(
        lib LibFoo
          struct Struct
            x : Int8
            y : Int16
          end

          fun foo(s : Struct)
        end

        s = LibFoo::Struct.new
        LibFoo.foo(s)
        ))
      str = mod.to_s
      str.should contain("call void @foo({ i64 }")
      str.should contain("declare void @foo({ i64 })")
    end

    it "passes struct less than 64 bits (for real)" do
      test_c(
        %(
          struct s {
            char x;
            short y;
          };

          int foo(struct s a) {
            return a.x + a.y;
          }
        ),
        %(
          lib LibFoo
            struct Struct
              x : Int8
              y : Int16
            end

            fun foo(s : Struct) : Int32
          end

          s = LibFoo::Struct.new x: 1_i8, y: 2_i16
          LibFoo.foo(s)
        ), &.to_i.should eq(3))
    end

    it "passes struct less than 64 bits as { i64 } in varargs" do
      mod = codegen(%(
        lib LibFoo
          struct Struct
            x : Int8
            y : Int16
          end

          fun foo(...)
        end

        s = LibFoo::Struct.new
        LibFoo.foo(s)
        ))
      str = mod.to_s
      str.should contain("call void (...)")
    end

    it "passes struct between 64 and 128 bits as { i64, i64 }" do
      mod = codegen(%(
        lib LibFoo
          struct Struct
            x : Int64
            y : Int16
          end

          fun foo(s : Struct)
        end

        s = LibFoo::Struct.new
        LibFoo.foo(s)
        ))
      str = mod.to_s
      str.should contain("call void @foo({ i64, i64 }")
      str.should contain("declare void @foo({ i64, i64 })")
    end

    it "passes struct between 64 and 128 bits as { i64, i64 } (with multiple modules/contexts)" do
      codegen(%(
        require "prelude"

        lib LibFoo
          struct Struct
            x : Int64
            y : Int16
          end

          fun foo(s : Struct)
        end

        module Moo
          def self.moo
            s = LibFoo::Struct.new
            LibFoo.foo(s)
          end
        end

        Moo.moo
        ))
    end

    it "passes struct between 64 and 128 bits (for real)" do
      test_c(
        %(
          struct s {
            long x;
            short y;
          };

          long foo(struct s a) {
            return a.x + a.y;
          }
        ),
        %(
          lib LibFoo
            struct Struct
              x : Int64
              y : Int16
            end

            fun foo(s : Struct) : Int64
          end

          s = LibFoo::Struct.new x: 1_i64, y: 2_i16
          LibFoo.foo(s)
        ), &.to_i.should eq(3))
    end

    it "passes struct bigger than128 bits with byval" do
      mod = codegen(%(
        lib LibFoo
          struct Struct
            x : Int64
            y : Int64
            z : Int8
          end

          fun foo(s : Struct)
        end

        s = LibFoo::Struct.new
        LibFoo.foo(s)
        ))
      str = mod.to_s
      str.scan(/byval/).size.should eq(2)
    end

    it "passes struct bigger than128 bits (for real)" do
      test_c(
        %(
          struct s {
            long x;
            long y;
            char z;
          };

          long foo(struct s a) {
            return a.x + a.y + a.z;
          }
        ),
        %(
          lib LibFoo
            struct Struct
              x : Int64
              y : Int64
              z : Int8
            end

            fun foo(s : Struct) : Int64
          end

          s = LibFoo::Struct.new x: 1_i64, y: 2_i64, z: 3_i8
          LibFoo.foo(s)
        ), &.to_i.should eq(6))
    end

    it "returns struct less than 64 bits as { i64 }" do
      mod = codegen(%(
        lib LibFoo
          struct Struct
            x : Int8
            y : Int16
          end

          fun foo : Struct
        end

        str = LibFoo.foo
        ))
      str = mod.to_s
      str.should contain("call { i64 } @foo()")
      str.should contain("declare { i64 } @foo()")
    end

    it "returns struct less than 64 bits (for real)" do
      test_c(
        %(
          struct s {
            char x;
            short y;
          };

          struct s foo() {
            struct s a = {1, 2};
            return a;
          }
        ),
        %(
          lib LibFoo
            struct Struct
              x : Int8
              y : Int16
            end

            fun foo : Struct
          end

          str = LibFoo.foo
          str.x.to_i + str.y.to_i
        ), &.to_i.should eq(3))
    end

    it "returns struct between 64 and 128 bits as { i64, i64 }" do
      mod = codegen(%(
        lib LibFoo
          struct Struct
            x : Int64
            y : Int16
          end

          fun foo : Struct
        end

        str = LibFoo.foo
        ))
      str = mod.to_s
      str.should contain("call { i64, i64 } @foo()")
      str.should contain("declare { i64, i64 } @foo()")
    end

    it "returns struct between 64 and 128 bits (for real)" do
      test_c(
        %(
          struct s {
            long x;
            short y;
          };

          struct s foo() {
            struct s a = {1, 2};
            return a;
          }
        ),
        %(
          lib LibFoo
            struct Struct
              x : Int64
              y : Int16
            end

            fun foo : Struct
          end

          str = LibFoo.foo
          (str.x + str.y).to_i32
        ), &.to_i.should eq(3))
    end

    it "returns struct bigger than 128 bits with sret" do
      mod = codegen(%(
        lib LibFoo
          struct Struct
            x : Int64
            y : Int64
            z : Int8
          end

          fun foo(w : Int32) : Struct
        end

        str = LibFoo.foo(1)
        ))
      str = mod.to_s
      str.scan(/sret/).size.should eq(2)
      str.should contain("sret, i32") # sret goes as first argument
    end

    it "returns struct bigger than 128 bits with sret" do
      test_c(
        %(
          struct s {
            long x;
            long y;
            char z;
          };

          struct s foo(int z) {
            struct s a = {1, 2, z};
            return a;
          }
        ),
        %(
          lib LibFoo
            struct Struct
              x : Int64
              y : Int64
              z : Int8
            end

            fun foo(w : Int32) : Struct
          end

          str = LibFoo.foo(3)
          (str.x + str.y + str.z).to_i32
        ), &.to_i.should eq(6))
    end
  end
{% end %}
