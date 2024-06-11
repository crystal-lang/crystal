def Object.from_form_data(params : URI::Params, name : String)
  return unless value = params[name]?

  self.from_form_data value
end

def Array.from_form_data(params : URI::Params, name : String)
  name = if params.has_key? name
           name
         elsif params.has_key? "#{name}[]"
           "#{name}[]"
         else
           return
         end

  params.fetch_all(name).map { |item| T.from_form_data(item).as T }
end

def Bool.from_form_data(value : String)
  case value
  when "true", "1", "yes", "on"  then true
  when "false", "0", "no", "off" then false
  end
end

def Number.from_form_data(value : String)
  new value, whitespace: false
end

def String.from_form_data(value : String)
  value
end

def Enum.from_form_data(value : String)
  parse value
end

def Time.from_form_data(value : String)
  Time::Format::ISO_8601_DATE_TIME.parse value
end

def Union.from_form_data(params : URI::Params, name : String)
  # Process non nilable types first as they are more likely to work.
  {% for type in T.sort_by { |t| t.nilable? ? 1 : 0 } %}
    begin
      return {{type}}.from_form_data params, name
    rescue
      # Noop to allow next T to be tried.
    end
  {% end %}
  raise ArgumentError.new "Invalid #{self}: #{params[name]}"
end

def Nil.from_form_data(value : String) : Nil
end
