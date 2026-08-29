# Methods defined here are primitives because they either:
# * can't be expressed in Crystal (need to be expressed in LLVM). For example unary
#   and binary math operators fall into this category.
# * should always be inlined with an LLVM instruction for performance reasons, even
#   in non-release builds. An example of this is `Char#ord`, which could be implemented
#   in Crystal by assigning `self` to a variable and casting a pointer to it to `Int32`,
#   and then reading back the value.

class Object
  # Returns the **runtime** `Class` of an object.
  #
  # ```
  # 1.class       # => Int32
  # "hello".class # => String
  # ```
  #
  # Compare it with `typeof`, which returns the **compile-time** type of an object:
  #
  # ```
  # random_value = rand # => 0.627423
  # value = random_value < 0.5 ? 1 : "hello"
  # value         # => "hello"
  # value.class   # => String
  # typeof(value) # => Int32 | String
  # ```
  @[Primitive(:class)]
  def class
  end

  # :nodoc:
  @[Primitive(:object_crystal_type_id)]
  def crystal_type_id : Int32
  end
end

class Reference
  # Returns a `UInt64` that uniquely identifies this object.
  #
  # The returned value is the memory address of this object.
  #
  # ```
  # string = "hello"
  # string.object_id # => 4460249568
  #
  # pointer = Pointer(String).new(string.object_id)
  # string2 = pointer.as(String)
  # string2.object_id == string.object_id # => true
  # ```
  @[Primitive(:object_id)]
  def object_id : UInt64
  end

  # Performs basic initialization so that the given *address* is ready for use
  # as an object's instance data. Returns *address* cast to `self`'s type.
  #
  # More specifically, this is the part of object initialization that occurs
  # after memory allocation and before calling one of the `#initialize`
  # overloads. It zeroes the memory, sets up the type ID (necessary for dynamic
  # dispatch), and then runs all inline instance variable initializers.
  #
  # *address* must point to a buffer of at least `instance_sizeof(self)` bytes
  # with an alignment of `instance_alignof(self)` or above. `ReferenceStorage`
  # fulfils both requirements.
  #
  # WARNING: The caller is responsible for managing the memory at the given
  # *address*, in particular if the memory is not garbage-collectable.
  #
  # ```
  # class Foo
  #   getter i : Int64
  #   getter str = "abc"
  #
  #   def initialize(@i)
  #   end
  #
  #   def self.alloc_with_libc(i : Int64)
  #     foo_buffer = LibC.malloc(instance_sizeof(Foo))
  #     foo = Foo.pre_initialize(foo_buffer)
  #     foo.i                  # => 0
  #     foo.str                # => "abc"
  #     (foo || "").is_a?(Foo) # => true
  #
  #     foo.initialize(i) # okay
  #     foo
  #   end
  # end
  #
  # foo = Foo.alloc_with_libc(123_i64)
  # foo.i # => 123
  # ```
  #
  # See also: `Reference.unsafe_construct`, `Struct.pre_initialize`.
  @[Experimental("This API is still under development. Join the discussion about custom reference allocation at [#13481](https://github.com/crystal-lang/crystal/issues/13481).")]
  @[Primitive(:pre_initialize)]
  {% if compare_versions(Crystal::VERSION, "1.2.0") >= 0 %}
    def self.pre_initialize(address : Pointer)
      # This ensures `.pre_initialize` is instantiated for every subclass,
      # otherwise all calls will refer to the sole instantiation in
      # `Reference.class`. This is necessary when the receiver is a virtual
      # metaclass type. Apparently this works even for primitives
      \{% @type %}
    end
  {% else %}
    # Primitives cannot have a body until 1.2.0 (#11147)
    def self.pre_initialize(address : Pointer)
    end
  {% end %}
end

struct Struct
  # Performs basic initialization so that the given *address* is ready for use
  # as an object's instance data.
  #
  # More specifically, this is the part of object initialization that occurs
  # after memory allocation and before calling one of the `#initialize`
  # overloads. It zeroes the memory, and then runs all inline instance variable
  # initializers.
  #
  # *address* must point to a buffer of at least `sizeof(self)` bytes with an
  # alignment of `alignof(self)` or above. This can for example be a pointer to
  # an uninitialized instance.
  #
  # This method only works for non-virtual constructions. Neither the struct
  # type nor *address*'s pointee type can be an abstract struct.
  #
  # ```
  # struct Foo
  #   getter i : Int64
  #   getter str = "abc"
  #
  #   def initialize(@i)
  #   end
  # end
  #
  # foo = uninitialized Foo
  # pointerof(foo).to_slice(1).to_unsafe_bytes.fill(0xFF)
  # Foo.pre_initialize(pointerof(foo))
  # foo # => Foo(@i=0, @str="abc")
  # ```
  #
  # See also: `Reference.pre_initialize`.
  @[Experimental("This API is still under development. Join the discussion about custom reference allocation at [#13481](https://github.com/crystal-lang/crystal/issues/13481).")]
  @[Primitive(:pre_initialize)]
  {% if compare_versions(Crystal::VERSION, "1.2.0") >= 0 %}
    def self.pre_initialize(address : Pointer) : Nil
      \{% @type %}
    end
  {% else %}
    def self.pre_initialize(address : Pointer) : Nil
    end
  {% end %}
end

class Class
  # :nodoc:
  @[Primitive(:class_crystal_instance_type_id)]
  def crystal_instance_type_id : Int32
  end
end

struct Bool
  # Returns `true` if `self` is equal to *other*.
  @[Primitive(:binary)]
  def ==(other : Bool) : Bool
  end

  # Returns `true` if `self` is not equal to *other*.
  @[Primitive(:binary)]
  def !=(other : Bool) : Bool
  end
end

struct Char
  # Returns the codepoint of this char.
  #
  # The codepoint is the integer representation.
  # The Universal Coded Character Set (UCS) standard, commonly known as Unicode,
  # assigns names and meanings to numbers, these numbers are called codepoints.
  #
  # For values below and including 127 this matches the ASCII codes
  # and thus its byte representation.
  #
  # ```
  # 'a'.ord      # => 97
  # '\0'.ord     # => 0
  # '\u007f'.ord # => 127
  # '☃'.ord      # => 9731
  # ```
  @[Primitive(:convert)]
  def ord : Int32
  end

  {% for op, desc in {
                       "==" => "equal to",
                       "!=" => "not equal to",
                       "<"  => "less than",
                       "<=" => "less than or equal to",
                       ">"  => "greater than",
                       ">=" => "greater than or equal to",
                     } %}
    # Returns `true` if `self`'s codepoint is {{ desc.id }} *other*'s codepoint.
    @[Primitive(:binary)]
    def {{ op.id }}(other : Char) : Bool
    end
  {% end %}
end

struct Symbol
  # Returns `true` if `self` is equal to *other*.
  @[Primitive(:binary)]
  def ==(other : Symbol) : Bool
  end

  # Returns `true` if `self` is not equal to *other*.
  @[Primitive(:binary)]
  def !=(other : Symbol) : Bool
  end

  # Returns a unique number for this symbol.
  @[Primitive(:convert)]
  def to_i : Int32
  end

  # Returns the symbol's name as a String.
  #
  # ```
  # :foo.to_s           # => "foo"
  # :"hello world".to_s # => "hello world"
  # ```
  @[Primitive(:symbol_to_s)]
  def to_s : String
  end
end

struct Pointer(T)
  # Allocates `size * sizeof(T)` bytes from the system's heap initialized
  # to zero and returns a pointer to the first byte from that memory.
  # The memory is allocated by the `GC`, so when there are
  # no pointers to this memory, it will be automatically freed.
  #
  # ```
  # # Allocate memory for an Int32: 4 bytes
  # ptr = Pointer(Int32).malloc(1_u64)
  # ptr.value # => 0
  #
  # # Allocate memory for 10 Int32: 40 bytes
  # ptr = Pointer(Int32).malloc(10_u64)
  # ptr[0] # => 0
  # # ...
  # ptr[9] # => 0
  # ```
  #
  # The implementation uses `GC.malloc` if the compiler is aware that the
  # allocated type contains inner address pointers. See
  # `Crystal::Macros::TypeNode#has_inner_pointers?` for details.
  #
  # To override this implicit behaviour, `GC.malloc` and `GC.malloc_atomic`
  # can be used directly instead.
  @[Primitive(:pointer_malloc)]
  def self.malloc(size : UInt64)
  end

  # Returns a pointer that points to the given memory address.
  # This doesn't allocate memory.
  #
  # ```
  # ptr = Pointer(Int32).new(5678_u64)
  # ptr.address # => 5678
  # ```
  @[Primitive(:pointer_new)]
  def self.new(address : UInt64)
  end

  # Gets the value pointed by this pointer.
  #
  # ```
  # ptr = Pointer(Int32).malloc(4)
  # ptr.value = 42
  # ptr.value # => 42
  # ```
  #
  # WARNING: The pointer must be appropriately aligned, i.e. `address` must be
  # a multiple of `alignof(T)`. It is undefined behavior to load from a
  # misaligned pointer. Such reads should instead be done via a cast to
  # `Pointer(UInt8)`, which is guaranteed to have byte alignment:
  #
  # ```
  # # raises SIGSEGV on X86 if `ptr` is misaligned
  # x = ptr.as(UInt128*).value
  #
  # # okay, `ptr` can have any alignment
  # x = uninitialized UInt128
  # ptr.as(UInt8*).copy_to(pointerof(x).as(UInt8*), sizeof(typeof(x)))
  # ```
  @[Primitive(:pointer_get)]
  def value : T
  end

  # Sets the value pointed by this pointer.
  #
  # ```
  # ptr = Pointer(Int32).malloc(4)
  # ptr.value = 42
  # ptr.value # => 42
  # ```
  #
  # WARNING: The pointer must be appropriately aligned, i.e. `address` must be
  # a multiple of `alignof(T)`. It is undefined behavior to store to a
  # misaligned pointer. Such writes should instead be done via a cast to
  # `Pointer(UInt8)`, which is guaranteed to have byte alignment:
  #
  # ```
  # # raises SIGSEGV on X86 if `ptr` is misaligned
  # x = 123_u128
  # ptr.as(UInt128*).value = x
  #
  # # okay, `ptr` can have any alignment
  # ptr.as(UInt8*).copy_from(pointerof(x).as(UInt8*), sizeof(typeof(x)))
  # ```
  @[Primitive(:pointer_set)]
  def value=(value : T)
  end

  # Returns the address of this pointer.
  #
  # ```
  # ptr = Pointer(Int32).new(1234)
  # ptr.address # => 1234
  # ```
  @[Primitive(:pointer_address)]
  def address : UInt64
  end

  # Tries to change the size of the allocation pointed to by this pointer to *size*,
  # and returns that pointer.
  #
  # Since the space after the end of the block may be in use, realloc may find it
  # necessary to copy the block to a new address where more free space is available.
  # The value of realloc is the new address of the block.
  # If the block needs to be moved, realloc copies the old contents.
  #
  # Remember to always assign the value of realloc.
  #
  # ```
  # ptr = Pointer.malloc(4) { |i| i + 1 } # [1, 2, 3, 4]
  # ptr = ptr.realloc(8_u8)
  # ptr # [1, 2, 3, 4, 0, 0, 0, 0]
  # ```
  @[Primitive(:pointer_realloc)]
  def realloc(size : UInt64) : self
  end

  # Returns a new pointer whose address is this pointer's address
  # incremented by `offset * sizeof(T)`.
  #
  # ```
  # ptr = Pointer(Int32).new(1234)
  # ptr.address # => 1234
  #
  # # An Int32 occupies four bytes
  # ptr2 = ptr + 1_u64
  # ptr2.address # => 1238
  # ```
  @[Primitive(:pointer_add)]
  def +(offset : Int64) : self
  end

  # Returns how many T elements are there between this pointer and *other*.
  # That is, this is `(self.address - other.address) / sizeof(T)`.
  #
  # ```
  # ptr1 = Pointer(Int32).malloc(4)
  # ptr2 = ptr1 + 2
  # ptr2 - ptr1 # => 2
  # ```
  @[Primitive(:pointer_diff)]
  def -(other : self) : Int64
  end
end

struct Slice(T)
  # Constructs a read-only `Slice` constant from the given *args*. The slice
  # contents are stored in the program's read-only data section.
  #
  # If `T` is specified, it must be one of the `Number::Primitive` types and
  # cannot be a union. The *args* must all be number literals that fit into
  # `T`'s range, as if they are autocasted into `T`.
  #
  # If `T` is not specified, it is inferred from *args*, which must all be
  # number literals of the same type, and cannot be empty.
  #
  # ```
  # x = Slice(UInt8).literal(0, 1, 4, 9, 16, 25)
  # x            # => Slice[0, 1, 4, 9, 16, 25]
  # x.read_only? # => true
  #
  # Slice.literal(1_u8, 2_u8, 3_u8) # => Bytes[1, 2, 3]
  # ```
  @[Experimental("Slice literals are still under development. Join the discussion at [#2886](https://github.com/crystal-lang/crystal/issues/2886).")]
  @[Primitive(:slice_literal)]
  def self.literal(*args)
  end
end

struct Proc
  # Invokes this `Proc` and returns the result.
  #
  # ```
  # add = ->(x : Int32, y : Int32) { x + y }
  # add.call(1, 2) # => 3
  # ```
  @[Primitive(:proc_call)]
  @[Raises]
  def call(*args : *T) : R
  end
end

# All `Number` methods are defined on concrete structs (for example `Int32`, `UInt8`, etc.),
# never on `Number`, `Int` or `Float` because we don't want to handle a primitive for
# other types that could extend these types (for example `BigInt`): if we do that
# a compiler crash will happen.
#
# A similar logic is applied to method arguments: they are always concrete, to avoid
# unintentionally handling a `BigInt` and have a crash. We also can't have an argument
# be a union, because the codegen primitives always consider primitive types, never
# unions.

{% begin %}
  {% ints = %w(Int8 Int16 Int32 Int64 Int128 UInt8 UInt16 UInt32 UInt64 UInt128) %}
  {% floats = %w(Float32 Float64) %}
  {% nums = %w(Int8 Int16 Int32 Int64 Int128 UInt8 UInt16 UInt32 UInt64 UInt128 Float32 Float64) %}
  {% binaries = {"+" => "adding", "-" => "subtracting", "*" => "multiplying"} %}

  {% for num in nums %}
    struct {{ num.id }}
      {% for name, type in {
                             to_i: Int32, to_u: UInt32, to_f: Float64,
                             to_i8: Int8, to_i16: Int16, to_i32: Int32, to_i64: Int64, to_i128: Int128,
                             to_u8: UInt8, to_u16: UInt16, to_u32: UInt32, to_u64: UInt64, to_u128: UInt128,
                             to_f32: Float32, to_f64: Float64,
                           } %}
        # Returns `self` converted to `{{ type }}`.
        # Raises `OverflowError` in case of overflow.
        @[::Primitive(:convert)]
        @[Raises]
        def {{ name.id }} : {{ type }}
        end

        # Returns `self` converted to `{{ type }}`.
        # In case of overflow
        # {% if ints.includes?(num) %} a wrapping is performed.
        # {% elsif type < Int %} the result is undefined.
        # {% else %} infinity is returned.
        # {% end %}
        @[::Primitive(:unchecked_convert)]
        def {{ name.id }}! : {{ type }}
        end
      {% end %}

      {% for num2 in nums %}
        {% for op, desc in {
                             "==" => "equal to",
                             "!=" => "not equal to",
                             "<"  => "less than",
                             "<=" => "less than or equal to",
                             ">"  => "greater than",
                             ">=" => "greater than or equal to",
                           } %}
          # Returns `true` if `self` is {{ desc.id }} *other*{% if op == "!=" && (!ints.includes?(num) || !ints.includes?(num2)) %}
          # or if `self` and *other* are unordered{% end %}.
          @[::Primitive(:binary)]
          def {{ op.id }}(other : {{ num2.id }}) : Bool
          end
        {% end %}
      {% end %}
    end
  {% end %}

  {% for int in ints %}
    struct {{ int.id }}
      # Returns a `Char` that has the unicode codepoint of `self`,
      # without checking if this integer is in the range valid for
      # chars (`0..0xd7ff` and `0xe000..0x10ffff`). In case of overflow
      # a wrapping is performed.
      #
      # You should never use this method unless `chr` turns out to
      # be a bottleneck.
      #
      # ```
      # 97.unsafe_chr # => 'a'
      # ```
      @[::Primitive(:unchecked_convert)]
      def unsafe_chr : Char
      end

      {% for int2 in ints %}
        {% for op, desc in binaries %}
          # Returns the result of {{ desc.id }} `self` and *other*.
          # Raises `OverflowError` in case of overflow.
          @[::Primitive(:binary)]
          @[Raises]
          def {{ op.id }}(other : {{ int2.id }}) : self
          end

          # Returns the result of {{ desc.id }} `self` and *other*.
          # In case of overflow a wrapping is performed.
          @[::Primitive(:binary)]
          def &{{ op.id }}(other : {{ int2.id }}) : self
          end
        {% end %}

        # Returns the result of performing a bitwise OR of `self`'s and *other*'s bits.
        @[::Primitive(:binary)]
        def |(other : {{ int2.id }}) : self
        end

        # Returns the result of performing a bitwise AND of `self`'s and *other*'s bits.
        @[::Primitive(:binary)]
        def &(other : {{ int2.id }}) : self
        end

        # Returns the result of performing a bitwise XOR of `self`'s and *other*'s bits.
        @[::Primitive(:binary)]
        def ^(other : {{ int2.id }}) : self
        end

        # :nodoc:
        @[::Primitive(:binary)]
        def unsafe_shl(other : {{ int2.id }}) : self
        end

        # :nodoc:
        @[::Primitive(:binary)]
        def unsafe_shr(other : {{ int2.id }}) : self
        end

        # :nodoc:
        @[::Primitive(:binary)]
        def unsafe_div(other : {{ int2.id }}) : self
        end

        # :nodoc:
        @[::Primitive(:binary)]
        def unsafe_mod(other : {{ int2.id }}) : self
        end
      {% end %}

      {% for float in floats %}
        {% for op, desc in binaries %}
          # Returns the result of {{ desc.id }} `self` and *other*.
          @[::Primitive(:binary)]
          def {{ op.id }}(other : {{ float.id }}) : {{ float.id }}
          end
        {% end %}
      {% end %}
    end
  {% end %}

  {% for float in floats %}
    struct {{ float.id }}
      {% for num in nums %}
        {% for op, desc in binaries %}
          # Returns the result of {{ desc.id }} `self` and *other*.
          @[::Primitive(:binary)]
          def {{ op.id }}(other : {{ num.id }}) : self
          end
        {% end %}

        # Returns the float division of `self` and *other*.
        @[::Primitive(:binary)]
        def fdiv(other : {{ num.id }}) : self
        end
      {% end %}

      # Returns the result of division `self` and *other*.
      @[::Primitive(:binary)]
      def /(other : {{ float.id }}) : {{ float.id }}
      end
    end
  {% end %}
{% end %}
