class Tuple
  include Enumerable(typeof((i = 0; self[i])))
  include Comparable(Tuple)

  def self.new(*args)
    args
  end

  def [](index : Int)
    {% for i in 0 ... @length %}
      return self[{{i}}] if {{i}} == index
    {% end %}
    raise IndexOutOfBounds.new
  end

  def each
    {% for i in 0 ... @length %}
      yield self[{{i}}]
    {% end %}
    self
  end

  def ==(other : self)
    {% for i in 0 ... @length %}
      return false unless self[{{i}}] == other[{{i}}]
    {% end %}
    true
  end

  def ==(other : Tuple)
    return false unless length == other.length

    length.times do |i|
      return false unless self[i] == other[i]
    end
    true
  end

  def ==(other)
    false
  end

  def <=>(other : self)
    {% for i in 0 ... @length %}
      cmp = self[{{i}}] <=> other[{{i}}]
      return cmp unless cmp == 0
    {% end %}
    0
  end

  def <=>(other : Tuple)
    min_length = Math.min(length, other.length)
    min_length.times do |i|
      cmp = self[i] <=> other[i]
      return cmp unless cmp == 0
    end
    length <=> other.length
  end

  def hash
    hash = 31 * length
    {% for i in 0 ... @length %}
      hash = 31 * hash + self[{{i}}].hash
    {% end %}
    hash
  end

  def dup
    self
  end

  def clone
    {% if true %}
      Tuple.new(
        {% for i in 0 ... @length %}
          self[{{i}}].clone,
        {% end %}
      )
    {% end %}
  end

  def empty?
    length == 0
  end

  def size
    length
  end

  def length
    {{@length}}
  end

  def types
    T
  end

  def inspect
    to_s
  end

  def to_s(io)
    io << "{"
    join ", ", io, &.inspect(io)
    io << "}"
  end
end
