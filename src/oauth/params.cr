# :nodoc:
struct OAuth::Params
  def initialize
    @params = [] of {String, String}
  end

  def add(key, value)
    if value
      @params << {URI.escape(key), URI.escape(value)}
    end
  end

  def add_query(query)
    HTTP::Params.parse(query) do |key, value|
      add key, value
    end
  end

  def to_s(io : IO)
    @params.sort_by! &.[0]
    @params.each_with_index do |(key, value), i|
      io << "%26" if i > 0
      URI.escape key, io
      io << "%3D"
      URI.escape value, io
    end
  end
end
