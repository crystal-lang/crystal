require "random/secure"

# TODO: use flag?(:bits64) for Crystal > 0.23.1
{% if flag?(:x86_64) || flag?(:aarch64) %}
  require "digest/siphash"
{% else %}
  require "digest/halfsiphash"
{% end %}

# :nodoc:
struct Crystal::Hasher
  # Implementation of a Hasher to compute a fast and safe hash
  # value for primitive and basic Crystal objects. All other
  # hashes are computed based on these.
  #
  # Relies on the SipHash family of pseudo random functions. Since we never
  # disclose the result of the hashes, we don't need the cryptographically
  # verified siphash-2-4, but can use the faster siphash-1-3 alternative.
  #
  # On 32-bit systems, we prefer the halfsiphash-1-3 alternative (32-bit hashes)
  # that should perform better than siphash-1-3 (64-bit hashes).

  # TODO: use flag?(:bits64) for Crystal > 0.23.1
  {% if flag?(:x86_64) || flag?(:aarch64) %}
    alias SipHash = Digest::SipHash
  {% else %}
    alias SipHash = Digest::HalfSipHash
  {% end %}

  @@seed = uninitialized SipHash::Key
  Random::Secure.random_bytes(@@seed.to_slice)

  def initialize
    @siphash = SipHash(1, 3).new(@@seed)
  end

  def result : UInt64
    @siphash.result
  end

  def nil
    self
  end

  def bool(value)
    (value ? 1 : 0).hash(self)
  end

  def int(value)
    # FIXME: 128-bit integers
    v = value.to_u64
    @siphash.update Bytes.new(pointerof(v).as(UInt8*), 8)
    self
  end

  def float(value)
    v = value.to_f64.unsafe_as(UInt64)
    @siphash.update Bytes.new(pointerof(v).as(UInt8*), 8)
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
    value.object_id.to_u64.hash(self)
  end

  def string(value)
    @siphash.update(value)
    self
  end

  def class(value)
    value.crystal_type_id.hash(self)
  end
end
