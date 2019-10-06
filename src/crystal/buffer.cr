# :nodoc:
class Crystal::Buffer(T)
  getter capacity : Int32

  protected def initialize(@capacity)
  end

  def self.allocation_size(capacity)
    raise ArgumentError.new("Negative capacity: #{capacity}") if capacity < 0
    sizeof(Buffer(T)).to_u32 + capacity.to_u32 * sizeof(T)
  end

  def self.new(capacity : Int)
    buffer = GC.malloc(allocation_size(capacity)).as(Buffer(T))
    set_crystal_type_id(buffer)
    buffer.initialize(capacity.to_i32)
    GC.add_finalizer(buffer) if buffer.responds_to?(:finalize)
    buffer
  end

  # Returns a buffer that can hold at least *capacity* elements.
  # May return self if capacity is enough.
  def realloc(capacity)
    buffer = Buffer(T).new(capacity)
    self.data.copy_to(buffer.data, self.capacity) if self.capacity > 0
    buffer
  end

  # Returns a buffer that can hold at least *required_capacity* elements.
  # The actual capacity is guaranteed to be a power of 2.
  # May return self if capacity is enough.
  def ensure_capacity(required_capacity)
    if required_capacity > @capacity
      self.realloc(Math.pw2ceil(required_capacity))
    else
      self
    end
  end

  def double_capacity
    realloc(@capacity == 0 ? 3 : (@capacity * 2))
  end

  @[AlwaysInline]
  def data : T*
    Pointer(T).new(object_id + sizeof(Buffer(T)))
  end
end
