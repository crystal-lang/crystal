require "../../spec_helper"

describe "Codegen: extern struct" do
  it "declares extern struct with no constructor" do
    run(%(
      @[Extern]
      struct Foo
        @x = uninitialized Int32

        def x
          @x
        end
      end

      Foo.new.x
      )).to_i.should eq(0)
  end

  it "declares extern struct with no constructor, assigns var" do
    run(%(
      @[Extern]
      struct Foo
        @x = uninitialized Int32

        def x=(@x)
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x = 10
      foo.x
      )).to_i.should eq(10)
  end

  it "declares extern union with no constructor" do
    run(%(
      @[Extern(union: true)]
      struct Foo
        @x = uninitialized Int32
        @y = uninitialized Float32

        def x=(@x)
        end

        def x
          @x
        end

        def y=(@y)
        end
      end

      foo = Foo.new
      foo.x = 1
      foo.y = 1.5_f32
      foo.x
      )).to_i.should eq(1069547520)
  end

  it "declares extern struct, sets and gets instance var" do
    run(%(
      @[Extern]
      struct Foo
        @y = uninitialized Float64
        @x = uninitialized Int32

        def foo
          @x = 42
          @x
        end
      end

      Foo.new.foo
      )).to_i.should eq(42)
  end

  it "declares extern union, sets and gets instance var" do
    run(%(
      @[Extern(union: true)]
      struct Foo
        @x = uninitialized Int32
        @y = uninitialized Float32

        def foo
          @x = 1
          @y = 1.5_f32
          @x
        end
      end

      Foo.new.foo
      )).to_i.should eq(1069547520)
  end

  it "sets callback on extern struct" do
    run(%(
      require "prelude"

      @[Extern]
      struct Foo
        @x = uninitialized -> Int32

        def set
          @x = ->{ 42 }
        end

        def get
          @x.call
        end
      end

      foo = Foo.new
      foo.set
      foo.get
      )).to_i.should eq(42)
  end

  it "sets callback on extern union" do
    run(%(
      require "prelude"

      @[Extern(union: true)]
      struct Foo
        @y = uninitialized Float64
        @x = uninitialized -> Int32

        def set
          @x = ->{ 42 }
        end

        def get
          @x.call
        end
      end

      foo = Foo.new
      foo.set
      foo.get
      )).to_i.should eq(42)
  end

  it "codegens extern proc call twice (#4982)" do
    run(%(
      @[Extern]
      struct Data
        def initialize(@foo : Int32)
        end

        def foo
          @foo
        end
      end

      f = ->(data : Data) { data.foo }

      x = f.call(Data.new(1))
      y = f.call(Data.new(2))

      x + y
      )).to_i.should eq(3)
  end

  # These specs *should* also work for 32 bits, but for now we'll
  # make sure they work in 64 bits (they probably work in 32 bits too,
  # it's just that the specs need to be a bit different)
  {% if flag?(:x86_64) %}
    it "codegens proc that takes an extern struct with C ABI" do
      test_c(
        %(
            struct Struct {
              int x;
              int y;
            };

            void foo(struct Struct (*callback)(struct Struct)) {
              struct Struct s;
              s.x = 1;
              s.y = 2;
              callback(s);
            }
          ),
        %(
            lib LibMylib
              struct Struct
                x : Int32
                y : Int32
              end

              alias Callback = Struct ->

              fun foo(callback : Callback) : LibMylib::Struct
            end

            class Global
              @@x = 0
              @@y = 0

              def self.x=(@@x)
              end

              def self.y=(@@y)
              end

              def self.x
                @@x
              end

              def self.y
                @@y
              end
            end

            LibMylib.foo(->(s) {
              Global.x = s.x
              Global.y = s.y
            })

            Global.x + Global.y
          ), &.to_i.should eq(3))
    end

    it "codegens proc that takes an extern struct with C ABI (2)" do
      test_c(
        %(
            struct Struct {
              int x;
              int y;
            };

            void foo(struct Struct (*callback)(int, struct Struct, int)) {
              struct Struct s;
              s.x = 1;
              s.y = 2;
              callback(10, s, 20);
            }
          ),
        %(
            lib LibMylib
              struct Struct
                x : Int32
                y : Int32
              end

              alias Callback = Int32, Struct, Int32 ->

              fun foo(callback : Callback) : LibMylib::Struct
            end

            class Global
              @@x = 0
              @@y = 0

              def self.x=(@@x)
              end

              def self.y=(@@y)
              end

              def self.x
                @@x
              end

              def self.y
                @@y
              end
            end

            LibMylib.foo(->(x, s, y) {
              Global.x = s.x + x
              Global.y = s.y + y
            })

            Global.x + Global.y
          ), &.to_i.should eq(33))
    end

    it "codegens proc that takes an extern struct with C ABI, callback returns nil" do
      test_c(
        %(
            struct Struct {
              int x;
              int y;
            };

            void foo(void (*callback)(struct Struct)) {
              struct Struct s;
              s.x = 1;
              s.y = 2;
              callback(s);
            }
          ),
        %(
            lib LibMylib
              struct Struct
                x : Int32
                y : Int32
              end

              alias Callback = Struct ->

              fun foo(callback : Callback) : LibMylib::Struct
            end

            class Global
              @@x = 0
              @@y = 0

              def self.x=(@@x)
              end

              def self.y=(@@y)
              end

              def self.x
                @@x
              end

              def self.y
                @@y
              end
            end

            LibMylib.foo(->(s) {
              Global.x = s.x
              Global.y = s.y
              nil
            })

            Global.x + Global.y
          ), &.to_i.should eq(3))
    end

    it "codegens proc that takes and returns an extern struct with C ABI" do
      test_c(
        %(
            struct Struct {
              int x;
              int y;
            };

            struct Struct foo(struct Struct (*callback)(struct Struct)) {
              struct Struct s;
              s.x = 1;
              s.y = 2;
              return callback(s);
            }
          ),
        %(
            lib LibMylib
              struct Struct
                x : Int32
                y : Int32
              end

              alias Callback = Struct -> Struct

              fun foo(callback : Callback) : LibMylib::Struct
            end

            class Global
              @@x = 0
              @@y = 0

              def self.x=(@@x)
              end

              def self.y=(@@y)
              end

              def self.x
                @@x
              end

              def self.y
                @@y
              end
            end

            s2 = LibMylib.foo(->(s) {
              Global.x = s.x
              Global.y = s.y
              s.x = 100
              s.y = 200
              s
            })

            Global.x + Global.y + s2.x + s2.y
          ), &.to_i.should eq(303))
    end

    it "codegens proc that takes and returns an extern struct with C ABI" do
      test_c(
        %(
            struct Struct {
              int x;
              int y;
            };

            struct Struct foo(struct Struct (*callback)(int, int)) {
              return callback(10, 20);
            }
          ),
        %(
            lib LibMylib
              struct Struct
                x : Int32
                y : Int32
              end

              alias Callback = Int32, Int32 -> Struct

              fun foo(callback : Callback) : LibMylib::Struct
            end

            s2 = LibMylib.foo(->(x, y) {
              s = LibMylib::Struct.new
              s.x = x
              s.y = y
              s
            })

            s2.x + s2.y
          ), &.to_i.should eq(30))
    end

    it "codegens proc that takes and returns an extern struct with sret" do
      test_c(
        %(
            struct Struct {
              long x;
              long y;
              long z;
            };

            struct Struct foo(struct Struct (*callback)(struct Struct)) {
              struct Struct s;
              s.x = 1;
              s.y = 2;
              s.z = 3;
              return callback(s);
            }
          ),
        %(
            lib LibMylib
              struct Struct
                x : Int64
                y : Int64
                z : Int64
              end

              alias Callback = Struct -> Struct

              fun foo(callback : Callback) : LibMylib::Struct
            end

            class Global
              @@x = 0

              def self.x=(@@x)
              end

              def self.x
                @@x
              end
            end

            s2 = LibMylib.foo(->(s) {
              Global.x += s.x
              Global.x += s.y
              Global.x += s.z
              s
            })

            Global.x += s2.x
            Global.x += s2.y
            Global.x += s2.z
            Global.x.to_i32
          ), &.to_i.should eq(12))
    end

    it "doesn't crash with proc with extern struct that's a closure" do
      codegen(%(
          lib LibMylib
            struct Struct
              x : Int64
              y : Int64
              z : Int64
            end
          end

          a = 1
          f = ->(s : LibMylib::Struct) {
            a
          }

          s = LibMylib::Struct.new
          f.call(s)
          ))
    end

    it "invokes proc with extern struct" do
      run(%(
          lib LibMylib
            struct Struct
              x : Int32
              y : Int32
            end
          end

          class Global
            @@x = 0

            def self.x=(@@x)
            end

            def self.x
              @@x
            end
          end

          f = ->(s : LibMylib::Struct) {
            Global.x += s.x
            Global.x += s.y
          }

          s = LibMylib::Struct.new
          s.x = 10
          s.y = 20
          f.call(s)

          Global.x
          )).to_i.should eq(30)
    end

    it "invokes proc with extern struct with sret" do
      run(%(
          lib LibMylib
            struct Struct
              x : Int32
              y : Int32
              z : Int32
              w : Int32
              a : Int32
            end
          end

          f = ->{
            s = LibMylib::Struct.new
            s.x = 1
            s.y = 2
            s.z = 3
            s.w = 4
            s.a = 5
            s
          }

          s = f.call
          s.x + s.y + s.z + s.w + s.a
          )).to_i.should eq(15)
    end
  {% end %}
end
