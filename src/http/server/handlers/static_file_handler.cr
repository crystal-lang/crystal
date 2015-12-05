require "ecr/macros"

class HTTP::StaticFileHandler < HTTP::Handler
  def initialize(@publicdir)
  end

  def call(request)
    request_path = request.path.not_nil!
    file_path = @publicdir + request_path
    if Dir.exists?(file_path)
      HTTP::Response.new(200, directory_listing(request_path, file_path), HTTP::Headers{"Content-Type": "text/html"})
    elsif File.exists?(file_path)
      HTTP::Response.new(200, File.read(file_path), HTTP::Headers{"Content-Type": mime_type(file_path)})
    else
      call_next(request)
    end
  end

  private def mime_type(path)
    case File.extname(path)
    when ".txt"          then "text/plain"
    when ".htm", ".html" then "text/html"
    when ".css"          then "text/css"
    when ".js"           then "application/javascript"
    else                      "application/octet-stream"
    end
  end

  record DirectoryListing, request_path, path do
    ecr_file "#{__DIR__}/static_file_handler.html"
  end

  private def directory_listing(request_path, path)
    DirectoryListing.new(request_path, path).to_s
  end
end
