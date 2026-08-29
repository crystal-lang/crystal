require "llvm/enums/atomic"

# A value that may be updated atomically.
#
# * If `T` is a reference type, or a union type containing only
#   reference types or `Nil`, then only `#compare_and_set`, `#swap`, `#set`,
#   `#lazy_set`, `#get`, and `#lazy_get` are available.
# * If `T` is a pointer type, then the above methods plus `#max` and `#min` are
#   available.
# * If `T` is a non-union primitive integer type or enum type, then all
#   operations are supported.
struct Atomic(T)
  # Specifies how memory accesses, including non atomic, are to be reordered
  # around atomics. Follows the C/C++ semantics:
  # <https://en.cppreference.com/w/c/atomic/memory_order>.
  #
  # By default atomics use the sequentially consistent ordering, which has the
  # strongest guarantees. If all you need is to increment a counter, a relaxed
  # ordering may be enough. If you need to synchronize access to other memory
  # (e.g. locks) you may try the acquire/release semantics that may be faster on
  # some architectures (e.g. X86) but remember that an acquire must be paired
  # with a release for the ordering to be guaranteed.
  #
  # The code generation always enforces the selected memory order, even on
  # weak CPU architectures (e.g. ARM32), with the exception of the Relaxed
  # memory order where only the operation itself is atomic.
  enum Ordering
    Relaxed                = LLVM::AtomicOrdering::Monotonic
    Acquire                = LLVM::AtomicOrdering::Acquire
    Release                = LLVM::AtomicOrdering::Release
    AcquireRelease         = LLVM::AtomicOrdering::AcquireRelease
    SequentiallyConsistent = LLVM::AtomicOrdering::SequentiallyConsistent
  end

  # Adds an explicit memory barrier with the specified memory order guarantee.
  macro fence(ordering = :sequentially_consistent)
    ::Atomic::Ops.fence({{ ordering }}, false)
  end

  # Creates an Atomic with the given initial value.
  def initialize(@value : T)
    {% if !T.union? && (T == Bool || T == Char || T < Int::Primitive || T < Enum) %}
      # Support integer types, enum types, bool or char (because it's represented as an integer)
    {% elsif T < Pointer %}
      # Support pointer types
    {% elsif T.union_types.all? { |t| t == Nil || t < Reference } && T != Nil %}
      # Support reference types, or union types with only nil or reference types
    {% else %}
      {% raise "Can only create Atomic with primitive integer types, pointer types, reference types or nilable reference types, not #{T}" %}
    {% end %}
  end

  # Compares this atomic's value with *cmp*:
  #
  # * if they are equal, sets the value to *new*, and returns `{old_value, true}`
  # * if they are not equal the value remains the same, and returns `{old_value, false}`
  #
  # Reference types are compared by `#same?`, not `#==`.
  #
  # ```
  # atomic = Atomic.new(1)
  #
  # atomic.compare_and_set(2, 3) # => {1, false}
  # atomic.get                   # => 1
  #
  # atomic.compare_and_set(1, 3) # => {1, true}
  # atomic.get                   # => 3
  # ```
  def compare_and_set(cmp : T, new : T) : {T, Bool}
    cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :sequentially_consistent, :sequentially_consistent)
  end

  # Compares this atomic's value with *cmp* using explicit memory orderings:
  #
  # * if they are equal, sets the value to *new*, and returns `{old_value, true}`
  # * if they are not equal the value remains the same, and returns `{old_value, false}`
  #
  # Reference types are compared by `#same?`, not `#==`.
  #
  # ```
  # atomic = Atomic.new(0_u32)
  #
  # value = atomic.get(:acquire)
  # loop do
  #   value, success = atomic.compare_and_set(value, value &+ 1, :acquire_release, :acquire)
  #   break if success
  # end
  # ```
  def compare_and_set(cmp : T, new : T, success_ordering : Ordering, failure_ordering : Ordering) : {T, Bool}
    case {success_ordering, failure_ordering}
    when {.relaxed?, .relaxed?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :monotonic, :monotonic)
    when {.acquire?, .relaxed?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :acquire, :monotonic)
    when {.acquire?, .acquire?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :acquire, :acquire)
    when {.release?, .relaxed?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :release, :monotonic)
    when {.release?, .acquire?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :release, :acquire)
    when {.acquire_release?, .relaxed?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :acquire_release, :monotonic)
    when {.acquire_release?, .acquire?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :acquire_release, :acquire)
    when {.sequentially_consistent?, .relaxed?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :sequentially_consistent, :monotonic)
    when {.sequentially_consistent?, .acquire?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :sequentially_consistent, :acquire)
    when {.sequentially_consistent?, .sequentially_consistent?}
      cast_from Ops.cmpxchg(as_pointer, cast_to(cmp), cast_to(new), :sequentially_consistent, :sequentially_consistent)
    else
      if failure_ordering.release? || failure_ordering.acquire_release?
        raise ArgumentError.new("Failure ordering cannot include release semantics")
      end
      raise ArgumentError.new("Failure ordering shall be no stronger than success ordering")
    end
  end

  # Performs `atomic_value &+= value`. Returns the old value.
  #
  # `T` cannot contain any pointer or reference types.
  #
  # ```
  # atomic = Atomic.new(1)
  # atomic.add(2) # => 1
  # atomic.get    # => 3
  # ```
  def add(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_pointer_type
    check_reference_type
    check_bool_type
    atomicrmw(:add, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value &-= value`. Returns the old value.
  #
  # `T` cannot contain any pointer or reference types.
  #
  # ```
  # atomic = Atomic.new(9)
  # atomic.sub(2) # => 9
  # atomic.get    # => 7
  # ```
  def sub(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_pointer_type
    check_reference_type
    check_bool_type
    atomicrmw(:sub, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value &= value`. Returns the old value.
  #
  # `T` cannot contain any pointer or reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.and(3) # => 5
  # atomic.get    # => 1
  # ```
  def and(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_pointer_type
    check_reference_type
    check_bool_type
    atomicrmw(:and, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value = ~(atomic_value & value)`. Returns the old value.
  #
  # `T` cannot contain any pointer or reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.nand(3) # => 5
  # atomic.get     # => -2
  # ```
  def nand(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_pointer_type
    check_reference_type
    check_bool_type
    atomicrmw(:nand, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value |= value`. Returns the old value.
  #
  # `T` cannot contain any pointer or reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.or(2) # => 5
  # atomic.get   # => 7
  # ```
  def or(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_pointer_type
    check_reference_type
    check_bool_type
    atomicrmw(:or, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value ^= value`. Returns the old value.
  #
  # `T` cannot contain any pointer or reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.xor(3) # => 5
  # atomic.get    # => 6
  # ```
  def xor(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_pointer_type
    check_reference_type
    check_bool_type
    atomicrmw(:xor, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value = {atomic_value, value}.max`. Returns the old value.
  #
  # `T` cannot contain any reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  #
  # atomic.max(3) # => 5
  # atomic.get    # => 5
  #
  # atomic.max(10) # => 5
  # atomic.get     # => 10
  # ```
  def max(value : T, ordering : Ordering = :sequentially_consistent)
    check_reference_type
    check_bool_type
    {% if T < Enum %}
      if @value.value.is_a?(Int::Signed)
        atomicrmw(:max, pointerof(@value), value, ordering)
      else
        atomicrmw(:umax, pointerof(@value), value, ordering)
      end
    {% elsif T < Pointer %}
      T.new(atomicrmw(:umax, pointerof(@value).as(LibC::SizeT*), LibC::SizeT.new!(value.address), ordering))
    {% elsif T < Int::Signed %}
      atomicrmw(:max, pointerof(@value), value, ordering)
    {% else %}
      atomicrmw(:umax, pointerof(@value), value, ordering)
    {% end %}
  end

  # Performs `atomic_value = {atomic_value, value}.min`. Returns the old value.
  #
  # `T` cannot contain any reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  #
  # atomic.min(10) # => 5
  # atomic.get     # => 5
  #
  # atomic.min(3) # => 5
  # atomic.get    # => 3
  # ```
  def min(value : T, ordering : Ordering = :sequentially_consistent)
    check_reference_type
    check_bool_type
    {% if T < Enum %}
      if @value.value.is_a?(Int::Signed)
        atomicrmw(:min, pointerof(@value), value, ordering)
      else
        atomicrmw(:umin, pointerof(@value), value, ordering)
      end
    {% elsif T < Pointer %}
      T.new(atomicrmw(:umin, pointerof(@value).as(LibC::SizeT*), LibC::SizeT.new!(value.address), ordering))
    {% elsif T < Int::Signed %}
      atomicrmw(:min, pointerof(@value), value, ordering)
    {% else %}
      atomicrmw(:umin, pointerof(@value), value, ordering)
    {% end %}
  end

  # Atomically sets this atomic's value to *value*. Returns the **old** value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.swap(10) # => 5
  # atomic.get      # => 10
  # ```
  def swap(value : T, ordering : Ordering = :sequentially_consistent)
    {% if T < Pointer %}
      T.new(atomicrmw(:xchg, pointerof(@value).as(LibC::SizeT*), LibC::SizeT.new!(value.address), ordering))
    {% elsif T.union_types.all? { |t| t == Nil || t < Reference } && T != Nil %}
      address = atomicrmw(:xchg, pointerof(@value).as(LibC::SizeT*), LibC::SizeT.new(value.as(Void*).address), ordering)
      Pointer(T).new(address).as(T)
    {% else %}
      cast_from atomicrmw(:xchg, as_pointer, cast_to(value), ordering)
    {% end %}
  end

  # Atomically sets this atomic's value to *value*. Returns the **new** value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.set(10) # => 10
  # atomic.get     # => 10
  # ```
  def set(value : T, ordering : Ordering = :sequentially_consistent) : T
    case ordering
    in .relaxed?
      Ops.store(as_pointer, cast_to(value), :monotonic, true)
    in .release?
      Ops.store(as_pointer, cast_to(value), :release, true)
    in .sequentially_consistent?
      Ops.store(as_pointer, cast_to(value), :sequentially_consistent, true)
    in .acquire?, .acquire_release?
      raise ArgumentError.new("Atomic store cannot have acquire semantic")
    end
    value
  end

  # **Non-atomically** sets this atomic's value to *value*. Returns the **new** value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.lazy_set(10) # => 10
  # atomic.get          # => 10
  # ```
  #
  # NOTE: use with caution, this may break atomic guarantees.
  def lazy_set(@value : T) : T
  end

  # Atomically returns this atomic's value.
  def get(ordering : Ordering = :sequentially_consistent) : T
    case ordering
    in .relaxed?
      cast_from Ops.load(as_pointer, :monotonic, true)
    in .acquire?
      cast_from Ops.load(as_pointer, :acquire, true)
    in .sequentially_consistent?
      cast_from Ops.load(as_pointer, :sequentially_consistent, true)
    in .release?, .acquire_release?
      raise ArgumentError.new("Atomic load cannot have release semantic")
    end
  end

  # **Non-atomically** returns this atomic's value.
  #
  # NOTE: use with caution, this may break atomic guarantees.
  def lazy_get
    @value
  end

  private macro check_bool_type
    {% if T == Bool %}
      {% raise "Cannot call `#{@type}##{@def.name}` for `#{T}` type" %}
    {% end %}
  end

  private macro check_pointer_type
    {% if T < Pointer %}
      {% raise "Cannot call `#{@type}##{@def.name}` as `#{T}` is a pointer type" %}
    {% end %}
  end

  private macro check_reference_type
    {% if T.union_types.all? { |t| t == Nil || t < Reference } && T != Nil %}
      {% raise "Cannot call `#{@type}##{@def.name}` as `#{T}` is a reference type" %}
    {% end %}
  end

  private macro atomicrmw(operation, pointer, value, ordering)
    case ordering
    in .relaxed?
      Ops.atomicrmw({{ operation }}, {{ pointer }}, {{ value }}, :monotonic, false)
    in .acquire?
      Ops.atomicrmw({{ operation }}, {{ pointer }}, {{ value }}, :acquire, false)
    in .release?
      Ops.atomicrmw({{ operation }}, {{ pointer }}, {{ value }}, :release, false)
    in .acquire_release?
      Ops.atomicrmw({{ operation }}, {{ pointer }}, {{ value }}, :acquire_release, false)
    in .sequentially_consistent?
      Ops.atomicrmw({{ operation }}, {{ pointer }}, {{ value }}, :sequentially_consistent, false)
    end
  end

  # :nodoc:
  module Ops
    # Defines methods that directly map to LLVM instructions related to atomic operations.

    @[Primitive(:cmpxchg)]
    def self.cmpxchg(ptr : T*, cmp : T, new : T, success_ordering : LLVM::AtomicOrdering, failure_ordering : LLVM::AtomicOrdering) : {T, Bool} forall T
    end

    @[Primitive(:atomicrmw)]
    def self.atomicrmw(op : LLVM::AtomicRMWBinOp, ptr : T*, val : T, ordering : LLVM::AtomicOrdering, singlethread : Bool) : T forall T
    end

    @[Primitive(:fence)]
    def self.fence(ordering : LLVM::AtomicOrdering, singlethread : Bool) : Nil
    end

    @[Primitive(:load_atomic)]
    def self.load(ptr : T*, ordering : LLVM::AtomicOrdering, volatile : Bool) : T forall T
    end

    @[Primitive(:store_atomic)]
    def self.store(ptr : T*, value : T, ordering : LLVM::AtomicOrdering, volatile : Bool) : Nil forall T
    end
  end

  @[AlwaysInline]
  private def as_pointer
    {% if T == Bool %}
      # assumes that a bool sizeof/alignof is 1 byte (and that a struct wrapping
      # a single boolean ivar has a sizeof/alignof of at least 1 byte, too) so
      # there is enough padding, and we can safely cast the int1 representation
      # of a bool as an int8
      pointerof(@value).as(Int8*)
    {% else %}
      pointerof(@value)
    {% end %}
  end

  @[AlwaysInline]
  private def cast_to(value)
    {% if T == Bool %}
      value.unsafe_as(Int8)
    {% else %}
      value.as(T)
    {% end %}
  end

  @[AlwaysInline]
  private def cast_from(value : Tuple)
    {% if T == Bool %}
      {value[0].unsafe_as(Bool), value[1]}
    {% else %}
      value
    {% end %}
  end

  @[AlwaysInline]
  private def cast_from(value)
    {% if T == Bool %}
      value.unsafe_as(Bool)
    {% else %}
      value
    {% end %}
  end
end

# An atomic flag, that can be set or not.
#
# Concurrency safe. If many fibers try to set the atomic in parallel, only one
# will succeed.
#
# Example:
# ```
# flag = Atomic::Flag.new
# flag.test_and_set # => true
# flag.test_and_set # => false
# flag.clear
# flag.test_and_set # => true
# ```
@[Deprecated("Use Atomic(Bool) instead.")]
struct Atomic::Flag
  def initialize
    @value = Atomic(Bool).new(false)
  end

  # Atomically tries to set the flag. Only succeeds and returns `true` if the
  # flag wasn't previously set; returns `false` otherwise.
  def test_and_set : Bool
    @value.swap(true, :sequentially_consistent) == false
  end

  # Atomically clears the flag.
  def clear : Nil
    @value.set(false, :sequentially_consistent)
  end
end
