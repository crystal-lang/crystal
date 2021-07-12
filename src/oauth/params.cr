# :nodoc:
struct OAuth::Params
  def initialize
    @params = [] of {String, String}
  end

  def add(key, value) : Nil
    if value
      @params << {URI.encode_www_form(key, space_to_plus: false), URI.encode_www_form(value, space_to_plus: false)}
    end
  end

  def add_query(query) : Nil
    URI::Params.parse(query) do |key, value|
      add key, value
    end
  end

  def to_s(io : IO) : Nil
    @params.sort_by! &.[0]
    @params.each_with_index do |(key, value), i|
      io << "%26" if i > 0
      URI.encode_www_form key, io, space_to_plus: false
      io << "%3D"
      URI.encode_www_form value, io, space_to_plus: false
    end
  end
end
