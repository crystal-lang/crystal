# :nodoc:
def Object.from_www_form(params : URI::Params, name : String) : Nil | Bool | UInt8 | Int32 | Float64 | String
  return unless value = params[name]?

  self.from_www_form value
end

# :nodoc:
def Array.from_www_form(params : URI::Params, name : String)
  name = if params.has_key? name
           name
         elsif params.has_key? "#{name}[]"
           "#{name}[]"
         else
           return
         end

  params.fetch_all(name).map { |item| T.from_www_form(item).as T }
end

# :nodoc:
def Bool.from_www_form(value : String) : Bool?
  case value
  when "true", "1", "yes", "on"  then true
  when "false", "0", "no", "off" then false
  end
end

# :nodoc:
def Number.from_www_form(value : String) : UInt8 | Int16 | Int32 | Int64 | Float32 | Float64
  new value, whitespace: false
end

# :nodoc:
def String.from_www_form(value : String) : String
  value
end

# :nodoc:
def Enum.from_www_form(value : String)
  parse value
end

# :nodoc:
def Time.from_www_form(value : String) : Time
  Time::Format::ISO_8601_DATE_TIME.parse value
end

# :nodoc:
def Union.from_www_form(params : URI::Params, name : String)
  # Process non nilable types first as they are more likely to work.
  {% for type in T.sort_by { |t| t.nilable? ? 1 : 0 } %}
    begin
      return {{type}}.from_www_form params, name
    rescue
      # Noop to allow next T to be tried.
    end
  {% end %}
  raise ArgumentError.new "Invalid #{self}: '#{params[name]}'."
end

# :nodoc:
def Nil.from_www_form(value : String) : Nil
  return if value.empty?

  raise ArgumentError.new "Invalid Nil value: '#{value}'."
end
