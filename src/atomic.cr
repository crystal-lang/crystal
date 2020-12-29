# A value that may be updated atomically.
#
# Only primitive integer types, reference types or nilable reference types
# can be used with an Atomic type.
struct Atomic(T)
  # Creates an Atomic with the given initial value.
  def initialize(@value : T)
    {% if !T.union? && (T == Char || T < Int::Primitive || T < Enum) %}
      # Support integer types, enum types, or char (because it's represented as an integer)
    {% elsif T < Reference || (T.union? && T.union_types.all? { |t| t == Nil || t < Reference }) %}
      # Support reference types, or union types with only nil or reference types
    {% else %}
      {{ raise "Can only create Atomic with primitive integer types, reference types or nilable reference types, not #{T}" }}
    {% end %}
  end

  # Compares this atomic's value with *cmp*:
  #
  # * if they are equal, sets the value to *new*, and returns `{old_value, true}`
  # * if they are not equal the value remains the same, and returns `{old_value, false}`
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
    # Check if it's a nilable reference type
    {% if T.union? && T.union_types.all? { |t| t == Nil || t < Reference } %}
      # If so, use addresses because LLVM < 3.9 doesn't support cmpxchg with pointers
      address, success = Ops.cmpxchg(pointerof(@value).as(LibC::SizeT*), LibC::SizeT.new(cmp.as(T).object_id), LibC::SizeT.new(new.as(T).object_id), :sequentially_consistent, :sequentially_consistent)
      {address == 0 ? nil : Pointer(T).new(address).as(T), success}
      # Check if it's a reference type
    {% elsif T < Reference %}
      # Use addresses again (but this can't return nil)
      address, success = Ops.cmpxchg(pointerof(@value).as(LibC::SizeT*), LibC::SizeT.new(cmp.as(T).object_id), LibC::SizeT.new(new.as(T).object_id), :sequentially_consistent, :sequentially_consistent)
      {Pointer(T).new(address).as(T), success}
    {% else %}
      # Otherwise, this is an integer type
      Ops.cmpxchg(pointerof(@value), cmp, new, :sequentially_consistent, :sequentially_consistent)
    {% end %}
  end

  # Performs `atomic_value += value`. Returns the old value.
  #
  # ```
  # atomic = Atomic.new(1)
  # atomic.add(2) # => 1
  # atomic.get    # => 3
  # ```
  def add(value : T)
    Ops.atomicrmw(:add, pointerof(@value), value, :sequentially_consistent, false)
  end

  # Performs `atomic_value -= value`. Returns the old value.
  #
  # ```
  # atomic = Atomic.new(9)
  # atomic.sub(2) # => 9
  # atomic.get    # => 7
  # ```
  def sub(value : T)
    Ops.atomicrmw(:sub, pointerof(@value), value, :sequentially_consistent, false)
  end

  # Performs `atomic_value &= value`. Returns the old value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.and(3) # => 5
  # atomic.get    # => 1
  # ```
  def and(value : T)
    Ops.atomicrmw(:and, pointerof(@value), value, :sequentially_consistent, false)
  end

  # Performs `atomic_value = ~(atomic_value & value)`. Returns the old value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.nand(3) # => 5
  # atomic.get     # => -2
  # ```
  def nand(value : T)
    Ops.atomicrmw(:nand, pointerof(@value), value, :sequentially_consistent, false)
  end

  # Performs `atomic_value |= value`. Returns the old value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.or(2) # => 5
  # atomic.get   # => 7
  # ```
  def or(value : T)
    Ops.atomicrmw(:or, pointerof(@value), value, :sequentially_consistent, false)
  end

  # Performs `atomic_value ^= value`. Returns the old value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.xor(3) # => 5
  # atomic.get    # => 6
  # ```
  def xor(value : T)
    Ops.atomicrmw(:xor, pointerof(@value), value, :sequentially_consistent, false)
  end

  # Performs `atomic_value = max(atomic_value, value)`. Returns the old value.
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
  def max(value : T)
    {% if T < Int::Signed %}
      Ops.atomicrmw(:max, pointerof(@value), value, :sequentially_consistent, false)
    {% else %}
      Ops.atomicrmw(:umax, pointerof(@value), value, :sequentially_consistent, false)
    {% end %}
  end

  # Performs `atomic_value = min(atomic_value, value)`. Returns the old value.
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
  def min(value : T)
    {% if T < Int::Signed %}
      Ops.atomicrmw(:min, pointerof(@value), value, :sequentially_consistent, false)
    {% else %}
      Ops.atomicrmw(:umin, pointerof(@value), value, :sequentially_consistent, false)
    {% end %}
  end

  # Atomically sets this atomic's value to *value*. Returns the **old** value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.swap(10) # => 5
  # atomic.get      # => 10
  # ```
  def swap(value : T)
    {% if T.union? && T.union_types.all? { |t| t == Nil || t < Reference } || T < Reference %}
      address = Ops.atomicrmw(:xchg, pointerof(@value).as(LibC::SizeT*), LibC::SizeT.new(value.as(T).object_id), :sequentially_consistent, false)
      Pointer(T).new(address).as(T)
    {% else %}
      Ops.atomicrmw(:xchg, pointerof(@value), value, :sequentially_consistent, false)
    {% end %}
  end

  # Atomically sets this atomic's value to *value*. Returns the **new** value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.set(10) # => 10
  # atomic.get     # => 10
  # ```
  def set(value : T)
    Ops.store(pointerof(@value), value.as(T), :sequentially_consistent, true)
    value
  end

  # **Non-atomically** sets this atomic's value to *value*. Returns the **new** value.
  #
  # ```
  # atomic = Atomic.new(5)
  # atomic.lazy_set(10) # => 10
  # atomic.get          # => 10
  # ```
  def lazy_set(@value : T)
  end

  # Atomically returns this atomic's value.
  def get
    Ops.load(pointerof(@value), :sequentially_consistent, true)
  end

  # **Non-atomically** returns this atomic's value.
  def lazy_get
    @value
  end

  # :nodoc:
  module Ops
    # Defines methods that directly map to LLVM instructions related to atomic operations.

    @[Primitive(:cmpxchg)]
    def self.cmpxchg(ptr : T*, cmp : T, new : T, success_ordering : Symbol, failure_ordering : Symbol) : {T, Bool} forall T
    end

    @[Primitive(:atomicrmw)]
    def self.atomicrmw(op : Symbol, ptr : T*, val : T, ordering : Symbol, singlethread : Bool) : T forall T
    end

    @[Primitive(:fence)]
    def self.fence(ordering : Symbol, singlethread : Bool) : Nil
    end

    @[Primitive(:load_atomic)]
    def self.load(ptr : T*, ordering : Symbol, volatile : Bool) : T forall T
    end

    @[Primitive(:store_atomic)]
    def self.store(ptr : T*, value : T, ordering : Symbol, volatile : Bool) : Nil forall T
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
    Atomic::Ops.atomicrmw(:xchg, pointerof(@value), 1_u8, :sequentially_consistent, false) == 0_u8
  end

  # Atomically clears the flag.
  def clear : Nil
    Atomic::Ops.store(pointerof(@value), 0_u8, :sequentially_consistent, true)
  end
end
