class Tuple
  include Enumerable(typeof((i = 0; self[i])))
  include Comparable(Tuple)

  def each
    length.times do |i|
      yield self[i]
    end
  end

  def ==(other : self)
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

  def types
    T
  end

  def to_s
    String.build do |str|
      str << "{"
      i = 0
      each do |elem|
        str << ", " if i > 0
        str << elem.inspect
        i += 1
      end
      str << "}"
    end
  end
end

macro make_named_tuple(name, field0)
  "
  struct #{name}
    getter #{field0}

    def initialize(@#{field0})
    end

    def ==(other : self)
      other.#{field0} == #{field0}
    end

    def hash
      hash = 0
      hash = 31 * hash + #{field0}.hash
      hash
    end

    def to_s
      \"#{name}(#{field0} = \#{#{field0}})\"
    end
  end
  "
end

macro make_named_tuple(name, field0, field1)
  "
  struct #{name}
    getter #{field0}
    getter #{field1}

    def initialize(@#{field0}, @#{field1})
    end

    def ==(other : self)
      other.#{field0} == #{field0} && other.#{field1} == #{field1}
    end

    def hash
      hash = 0
      hash = 31 * hash + #{field0}.hash
      hash = 31 * hash + #{field1}.hash
      hash
    end

    def to_s
      \"#{name}(#{field0} = \#{#{field0}}, #{field1} = \#{#{field1}})\"
    end
  end
  "
end

macro make_named_tuple(name, field0, field1, field2)
  "
  struct #{name}
    getter #{field0}
    getter #{field1}
    getter #{field2}

    def initialize(@#{field0}, @#{field1}, @#{field2})
    end

    def ==(other : self)
      other.#{field0} == #{field0} && other.#{field1} == #{field1} && other.#{field2} == #{field2}
    end

    def hash
      hash = 0
      hash = 31 * hash + #{field0}.hash
      hash = 31 * hash + #{field1}.hash
      hash = 31 * hash + #{field2}.hash
      hash
    end

    def to_s
      \"#{name}(#{field0} = \#{#{field0}}, #{field1} = \#{#{field1}}, #{field2} = \#{#{field2}})\"
    end
  end
  "
end
