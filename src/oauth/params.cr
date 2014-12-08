struct OAuth::Params
  def initialize
    @params = [] of {String, String}
  end

  def add(key, value)
    if value
      @params << {CGI.escape(key), CGI.escape(value)}
    end
  end

  def add_query(query)
    CGI.parse(query) do |key, value|
      add key, value
    end
  end

  def to_s(io : IO)
    @params.sort_by! &.[0]
    @params.each_with_index do |tuple, i|
      io << "%26" if i > 0
      CGI.escape tuple[0], io
      io << "%3D"
      CGI.escape tuple[1], io
    end
  end
end
