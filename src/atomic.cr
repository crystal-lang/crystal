require "llvm/enums/atomic"

# A value that may be updated atomically.
#
# If `T` is a non-union primitive integer type or enum type, all operations are
# supported. If `T` is a reference type, or a union type containing only
# reference types or `Nil`, then only `#compare_and_set`, `#swap`, `#set`,
# `#lazy_set`, `#get`, and `#lazy_get` are available.
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
  enum Ordering
    Relaxed                = LLVM::AtomicOrdering::Monotonic
    Acquire                = LLVM::AtomicOrdering::Acquire
    Release                = LLVM::AtomicOrdering::Release
    AcquireRelease         = LLVM::AtomicOrdering::AcquireRelease
    SequentiallyConsistent = LLVM::AtomicOrdering::SequentiallyConsistent
  end

  # Adds an explicit memory barrier with the specified memory order guarantee.
  #
  # Atomics on weakly-ordered CPUs (e.g. ARM32) may not guarantee memory order
  # of other memory accesses, and an explicit memory barrier is thus required.
  #
  # Notes:
  # - X86 is strongly-ordered and trying to add a fence should be a NOOP;
  # - AArch64 guarantees memory order and doesn't need explicit fences in
  #   addition to the atomics (but may need barriers in other cases).
  macro fence(ordering = :sequentially_consistent)
    ::Atomic::Ops.fence({{ordering}}, false)
  end

  # Creates an Atomic with the given initial value.
  def initialize(@value : T)
    {% if !T.union? && (T == Char || T < Int::Primitive || T < Enum) %}
      # Support integer types, enum types, or char (because it's represented as an integer)
    {% elsif T.union_types.all? { |t| t == Nil || t < Reference } && T != Nil %}
      # Support reference types, or union types with only nil or reference types
    {% else %}
      {% raise "Can only create Atomic with primitive integer types, reference types or nilable reference types, not #{T}" %}
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
    Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :sequentially_consistent, :sequentially_consistent)
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
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :monotonic, :monotonic)
    when {.acquire?, .relaxed?}
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :acquire, :monotonic)
    when {.acquire?, .acquire?}
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :acquire, :acquire)
    when {.release?, .relaxed?}
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :release, :monotonic)
    when {.release?, .acquire?}
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :release, :acquire)
    when {.acquire_release?, .relaxed?}
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :acquire_release, :monotonic)
    when {.acquire_release?, .acquire?}
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :acquire_release, :acquire)
    when {.sequentially_consistent?, .relaxed?}
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :sequentially_consistent, :monotonic)
    when {.sequentially_consistent?, .acquire?}
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :sequentially_consistent, :acquire)
    when {.sequentially_consistent?, .sequentially_consistent?}
      Ops.cmpxchg(pointerof(@value), cmp.as(T), new.as(T), :sequentially_consistent, :sequentially_consistent)
    else
      if failure_ordering.release? || failure_ordering.acquire_release?
        raise ArgumentError.new("Failure ordering cannot include release semantics")
      end
      raise ArgumentError.new("Failure ordering shall be no stronger than success ordering")
    end
  end

  # Performs `atomic_value &+= value`. Returns the old value.
  #
  # `T` cannot contain any reference types.
  #
  # ```
  # atomic = Atomic.new(1)
  # atomic.add(2) # => 1
  # atomic.get    # => 3
  # ```
  def add(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_reference_type
    atomicrmw(:add, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value &-= value`. Returns the old value.
  #
  # `T` cannot contain any reference types.
  #
  # ```
  # atomic = Atomic.new(9)
  # atomic.sub(2) # => 9
  # atomic.get    # => 7
  # ```
  def sub(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_reference_type
    atomicrmw(:sub, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value &= value`. Returns the old value.
  #
  # `T` cannot contain any reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.and(3) # => 5
  # atomic.get    # => 1
  # ```
  def and(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_reference_type
    atomicrmw(:and, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value = ~(atomic_value & value)`. Returns the old value.
  #
  # `T` cannot contain any reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.nand(3) # => 5
  # atomic.get     # => -2
  # ```
  def nand(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_reference_type
    atomicrmw(:nand, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value |= value`. Returns the old value.
  #
  # `T` cannot contain any reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.or(2) # => 5
  # atomic.get   # => 7
  # ```
  def or(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_reference_type
    atomicrmw(:or, pointerof(@value), value, ordering)
  end

  # Performs `atomic_value ^= value`. Returns the old value.
  #
  # `T` cannot contain any reference types.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.xor(3) # => 5
  # atomic.get    # => 6
  # ```
  def xor(value : T, ordering : Ordering = :sequentially_consistent) : T
    check_reference_type
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
    {% if T < Enum %}
      if @value.value.is_a?(Int::Signed)
        atomicrmw(:max, pointerof(@value), value, ordering)
      else
        atomicrmw(:umax, pointerof(@value), value, ordering)
      end
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
    {% if T < Enum %}
      if @value.value.is_a?(Int::Signed)
        atomicrmw(:min, pointerof(@value), value, ordering)
      else
        atomicrmw(:umin, pointerof(@value), value, ordering)
      end
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
    {% if T.union_types.all? { |t| t == Nil || t < Reference } && T != Nil %}
      address = atomicrmw(:xchg, pointerof(@value).as(LibC::SizeT*), LibC::SizeT.new(value.as(Void*).address), ordering)
      Pointer(T).new(address).as(T)
    {% else %}
      atomicrmw(:xchg, pointerof(@value), value, ordering)
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
      Ops.store(pointerof(@value), value.as(T), :monotonic, true)
    in .release?
      Ops.store(pointerof(@value), value.as(T), :release, true)
    in .sequentially_consistent?
      Ops.store(pointerof(@value), value.as(T), :sequentially_consistent, true)
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
      Ops.load(pointerof(@value), :monotonic, true)
    in .acquire?
      Ops.load(pointerof(@value), :acquire, true)
    in .sequentially_consistent?
      Ops.load(pointerof(@value), :sequentially_consistent, true)
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

  private macro check_reference_type
    {% if T.union_types.all? { |t| t == Nil || t < Reference } && T != Nil %}
      {% raise "Cannot call `#{@type}##{@def.name}` as `#{T}` is a reference type" %}
    {% end %}
  end

  private macro atomicrmw(operation, pointer, value, ordering)
    case ordering
    in .relaxed?
      Ops.atomicrmw({{operation}}, {{pointer}}, {{value}}, :monotonic, false)
    in .acquire?
      Ops.atomicrmw({{operation}}, {{pointer}}, {{value}}, :acquire, false)
    in .release?
      Ops.atomicrmw({{operation}}, {{pointer}}, {{value}}, :release, false)
    in .acquire_release?
      Ops.atomicrmw({{operation}}, {{pointer}}, {{value}}, :acquire_release, false)
    in .sequentially_consistent?
      Ops.atomicrmw({{operation}}, {{pointer}}, {{value}}, :sequentially_consistent, false)
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
struct Atomic::Flag
  def initialize
    @value = 0_u8
  end

  # Atomically tries to set the flag. Only succeeds and returns `true` if the
  # flag wasn't previously set; returns `false` otherwise.
  def test_and_set : Bool
    ret = Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :sequentially_consistent, false) == 0_u8
    {% if flag?(:arm) %}
      Atomic::Ops.fence(:sequentially_consistent, false) if ret
    {% end %}
    ret
  end

  # Atomically clears the flag.
  def clear : Nil
    {% if flag?(:arm) %}
      Atomic::Ops.fence(:sequentially_consistent, false)
    {% end %}
    Atomic::Ops.store(pointerof(@value), 0_u8, :sequentially_consistent, true)
  end
end
