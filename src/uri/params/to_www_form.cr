class Object
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
