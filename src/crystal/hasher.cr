require "crystal/system/random"

# :nodoc:
struct Crystal::Hasher
  # Implementation of a Hasher to compute a fast and safe hash
  # value for primitive and basic Crystal objects. All other
  # hashes are computed based on these.
  #
  # TODO: the implementation is naive and should probably use
  # another algorithm like SipHash or FNV.

  @@seed = uninitialized UInt64
  Crystal::System::Random.random_bytes(Slice.new(pointerof(@@seed).as(UInt8*), 8))

  property result : UInt64 = @@seed

  def nil
    self
  end

  def bool(value)
    (value ? 1 : 0).hash(self)
  end

  def int(value)
    @result = @result * 31 + value.to_u64
    self
  end

  def float(value)
    @result = @result * 31 + value.to_f64.unsafe_as(UInt64)
    self
  end

  def char(value)
    value.ord.hash(self)
  end

  def enum(value)
    value.value.hash(self)
  end

  def symbol(value)
    value.to_i.hash(self)
  end

  def reference(value)
    @result = @result * 31 + value.object_id.to_u64
    self
  end

  def string(value)
    value.to_slice.hash(self)
  end

  def class(value)
    value.crystal_type_id.hash(self)
  end
end
