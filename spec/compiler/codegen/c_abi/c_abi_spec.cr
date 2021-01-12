require "../../../spec_helper"

describe "Code gen: C ABI" do
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

  it "passes struct between 64 and 128 bits (for real)" do
    test_c(
      %(
        struct s {
          long long x;
          short y;
        };

        long long foo(struct s a) {
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

  it "passes struct bigger than 128 bits (for real)" do
    test_c(
      %(
        struct s {
          long long x;
          long long y;
          char z;
        };

        long long foo(struct s a) {
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

  {% if flag?(:x86_64) && !flag?(:win32) %}
    pending "passes struct after many other args (for real) (#9519)"
  {% else %}
    it "passes struct after many other args (for real)" do
      test_c(
        %(
          struct s {
            long long x, y;
          };

          long long foo(long long a, long long b, long long c, long long d, long long e, struct s v) {
            return a + b + c + d + e + v.x + v.y;
          }
        ),
        %(
          lib LibFoo
            struct S
              x : Int64
              y : Int64
            end

            fun foo(a : Int64, b : Int64, c : Int64, d : Int64, e : Int64, v : S) : Int64
          end

          v = LibFoo::S.new(x: 6, y: 7)
          LibFoo.foo(1, 2, 3, 4, 5, v)
        ), &.to_string.should eq("28"))
    end
  {% end %}

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

  it "returns struct between 64 and 128 bits (for real)" do
    test_c(
      %(
        struct s {
          long long x;
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
    test_c(
      %(
        struct s {
          long long x;
          long long y;
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

  {% if flag?(:win32) || flag?(:aarch64) %}
    pending "accepts large struct in a callback (for real) (#9533)"
  {% else %}
    it "accepts large struct in a callback (for real)" do
      test_c(
        %(
          struct s {
              long long x, y, z;
          };

          void ccaller(void (*func)(struct s)) {
              struct s v = {1, 2, 3};
              func(v);
          }
        ),
        %(
          lib LibFoo
            struct S
              x : Int64
              y : Int64
              z : Int64
            end

            fun ccaller(func : (S) ->)
          end

          module Global
            class_property x = 0i64
          end

          fun callback(v : LibFoo::S)
            Global.x = v.x &+ v.y &+ v.z
          end

          LibFoo.ccaller(->callback)

          Global.x
        ), &.to_string.should eq("6"))
    end
  {% end %}

  it "promotes variadic args (float to double)" do
    test_c(
      %(
        #include <stdarg.h>

        double foo(int n, ...) {
          va_list args;
          va_start(args, n);
          return va_arg(args, double);
        }
      ),
      %(
        lib LibFoo
          fun foo(n : Int32, ...) : Float64
        end

        LibFoo.foo(1, 1.0_f32)
      ), &.to_f64.should eq(1.0))
  end

  [{"i8", -123},
   {"u8", 255},
   {"i16", -123},
   {"u16", 65535},
  ].each do |int_kind, int_value|
    it "promotes variadic args (#{int_kind} to i32) (#9742)" do
      test_c(
        %(
          #include <stdarg.h>

          int foo(int n, ...) {
            va_list args;
            va_start(args, n);
            return va_arg(args, int);
          }
        ),
        %(
          lib LibFoo
            fun foo(n : Int32, ...) : Int32
          end

          LibFoo.foo(1, #{int_value}_#{int_kind})
        ), &.to_i.should eq(int_value))
    end
  end
end
