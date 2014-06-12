class HTTP::StaticFileHandler < HTTP::Handler
  def initialize(@publicdir)
  end

  def call(request)
    file_path = @publicdir + request.path
    if File.exists?(file_path)
      HTTP::Response.new("HTTP/1.1", 200, "OK", {"Content-Type" => mime_type(file_path)}, File.read(file_path))
    else
      call_next(request)
    end
  end

  def mime_type(path)
    case File.extname(path)
    when ".txt" then "text/plain"
    else "application/octet-stream"
    end
  end
end
