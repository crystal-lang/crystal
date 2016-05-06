module YAML
  class Generator
    def initialize(@io : IO)
      @recent_nl = false
      @first = true
      @io << "--- "
    end

    def <<(s)
      @io << s
      @recent_nl = false
      @first = false
    end

    def nl(s = "")
      self << (@indent || "\n") unless @recent_nl
      self << s
      @recent_nl = true
    end

    def indented(indent = "  ")
      old_indent = @indent
      @indent = "#{@indent || "\n"}#{@first ? "" : indent}"
      yield
      @indent = old_indent
    end
  end
end

class Object
  def to_yaml
    String.build do |str|
      to_yaml(str)
    end
  end

  def to_yaml(io : IO)
    to_yaml(YAML::Generator.new(io))
  end
end

class Hash
  def to_yaml(yaml : YAML::Generator)
    yaml.indented do
      each do |k, v|
        yaml.nl
        k.to_yaml(yaml)
        yaml << ": "
        v.to_yaml(yaml)
      end
    end
  end
end

class Array
  def to_yaml(yaml : YAML::Generator)
    yaml.indented do
      each do |v|
        yaml.nl("- ")
        v.to_yaml(yaml)
      end
    end
  end
end

struct Tuple
  def to_yaml(yaml : YAML::Generator)
    yaml.indented do
      {% for i in 0...T.size %}
        yaml.nl("- ")
        self[{{i}}].to_yaml(yaml)
      {% end %}
    end
  end
end

class String
  def to_yaml(yaml : YAML::Generator)
    yaml << self
  end
end

struct Number
  def to_yaml(yaml : YAML::Generator)
    yaml << self
  end
end

struct Nil
  def to_yaml(yaml : YAML::Generator)
    yaml << ""
  end
end

struct Bool
  def to_yaml(yaml : YAML::Generator)
    yaml << to_s
  end
end

struct Set
  def to_yaml(yaml : YAML::Generator)
    yaml.indented do
      each do |v|
        yaml.nl("- ")
        v.to_yaml(yaml)
      end
    end
  end
end

struct Symbol
  def to_yaml(yaml : YAML::Generator)
    yaml << to_s
  end
end

struct Enum
  def to_yaml(yaml : YAML::Generator)
    yaml << value
  end
end

module Time::EpochConverter
  def self.to_yaml(value : Time, io : IO)
    io << value.epoch
  end
end
