struct Enum
  include Comparable(self)

  macro def to_s(io : IO) : Nil
    {% if @enum_flags %}
      if value == 0
        io << "None"
      else
        found = false
        {% for member in @constants %}
          {% if member.stringify != "All" %}
            if {{member}}.value != 0 && (value & {{member}}.value) == {{member}}.value
              io << ", " if found
              io << {{member.stringify}}
              found = true
            end
          {% end %}
        {% end %}
        io << value unless found
      end
    {% else %}
      io << to_s
    {% end %}
    nil
  end

  macro def to_s : String
    {% if @enum_flags %}
      String.build { |io| to_s(io) }
    {% else %}
      case value
      {% for member in @constants %}
      when {{member}}.value
        {{member.stringify}}
      {% end %}
      else
        value.to_s
      end
    {% end %}
  end

  def to_i
    value.to_i32
  end

  def +(other : Int)
    self.class.new(value + other)
  end

  def -(other : Int)
    self.class.new(value - other)
  end

  def |(other : self)
    self.class.new(value | other.value)
  end

  def &(other : self)
    self.class.new(value & other.value)
  end

  def ^(other : self)
    self.class.new(value ^ other.value)
  end

  def ~(other : self)
    self.class.new(value ~ other.value)
  end

  def <=>(other : self)
    value <=> other.value
  end

  def includes?(other : self)
    (value & other.value) != 0
  end

  def ==(other : self)
    value == other.value
  end

  def hash
    value.hash
  end

  macro def self.names : Array(String)
    {% if @enum_flags %}
      {{ @constants.select { |e| e.stringify != "None" && e.stringify != "All" }.map &.stringify }}
    {% else %}
      {{ @constants.map &.stringify }}
    {% end %}
  end

  macro def self.values : Array(self)
    {% if @enum_flags %}
      {{ @constants.select { |e| e.stringify != "None" && e.stringify != "All" } }}
    {% else %}
      {{ @constants }}
    {% end %}
  end

  # macro def self.to_h : Hash(String, self)
  #   {
  #     {% for member in @constants %}
  #       {{member.stringify}} => {{member}},
  #     {% end %}
  #   }
  # end

  def self.parse(string)
    value = parse?(string)
    if value
      value
    else
      raise "Unknown enum #{self} value: #{string}"
    end
  end

  macro def self.parse?(string) : self ?
    case string.downcase
    {% for member in @constants %}
      when {{member.stringify.downcase}}
        {{member}}
    {% end %}
    else
      nil
    end
  end

  # def self.each
  #   to_h.each do |key, value|
  #     yield key, value
  #   end
  # end
end
