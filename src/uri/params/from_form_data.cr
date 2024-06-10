def Array.from_form_data(params : URI::Params, name : String)
  params.fetch_all(name).map { |item| T.from_form_data(params, name).as T }
end

def Bool.from_form_data(params : URI::Params, name : String)
  case params[name]?
  when "true", "1", "yes", "on"  then true
  when "false", "0", "no", "off" then false
  end
end

def Number.from_form_data(params : URI::Params, name : String)
  return nil unless value = params[name]?

  new value, whitespace: false
end

def String.from_form_data(params : URI::Params, name : String)
  params[name]?
end

def Enum.from_form_data(params : URI::Params, name : String)
  return nil unless value = params[name]?

  parse value
end

def Time.from_form_data(params : URI::Params, name : String)
  return nil unless value = params[name]?

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

def Nil.from_form_data(params : URI::Params, name : String) : Nil
end
