class Tuple
  include Enumerable(typeof((i = 0; self[i])))
  include Comparable(Tuple)

  def each
    length.times do |i|
      yield self[i]
    end
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
    each do |elem|
      hash = 31 * hash + elem.hash
    end
    hash
  end

  def empty?
    length == 0
  end

  def size
    length
  end

  def types
    T
  end

  def inspect
    to_s
  end

  def to_s(io)
    io << "{"
    i = 0
    each do |elem|
      io << ", " if i > 0
      io << elem.inspect
      i += 1
    end
    io << "}"
  end
end

macro make_named_tuple(name, fields)
  struct {{name.id}}
    {% for field in fields %}
      getter :{{field.id}}
    {% end %}

    def initialize({{ (fields.map { |field| "@#{field.id}" }.join ", ").id }})
    end

    {{yield}}
  end
end
