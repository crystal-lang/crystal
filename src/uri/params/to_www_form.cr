struct Bool
  # :nodoc:
  def to_www_form(builder : URI::Params::Builder, name : String) : Nil
    builder.add name, to_s
  end
end

class Array
  # :nodoc:
  def to_www_form(builder : URI::Params::Builder, name : String) : Nil
    each &.to_www_form builder, name
  end
end

class String
  # :nodoc:
  def to_www_form(builder : URI::Params::Builder, name : String) : Nil
    builder.add name, self
  end
end

struct Number
  # :nodoc:
  def to_www_form(builder : URI::Params::Builder, name : String) : Nil
    builder.add name, to_s
  end
end

struct Nil
  # :nodoc:
  def to_www_form(builder : URI::Params::Builder, name : String) : Nil
    builder.add name, self
  end
end

struct Enum
  # :nodoc:
  def to_www_form(builder : URI::Params::Builder, name : String) : Nil
    builder.add name, to_s.underscore
  end
end

struct Time
  # :nodoc:
  def to_www_form(builder : URI::Params::Builder, name : String) : Nil
    builder.add name, to_rfc3339
  end
end
