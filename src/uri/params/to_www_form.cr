class Object
  def to_www_form(builder : URI::Params::Builder, name : String) : Nil
    builder.add name, to_s
  end
end

class Array
  def to_www_form(builder : URI::Params::Builder, name : String) : Nil
    each { |v| builder.add name, v.to_s }
  end
end
