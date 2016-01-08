require "ecr/macros"

class HTTP::StaticFileHandler < HTTP::Handler
  def initialize(@publicdir)
  end

  def call(context)
    request_path = context.request.path.not_nil!
    file_path = @publicdir + request_path
    if Dir.exists?(file_path)
      context.response.content_type = "text/html"
      directory_listing(context.response, request_path, file_path)
    elsif File.exists?(file_path)
      context.response.content_type = mime_type(file_path)
      context.response.content_length = File.size(file_path)
      File.open(file_path) do |file|
        IO.copy(file, context.response)
      end
    else
      call_next(context)
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

  private def directory_listing(io, request_path, path)
    DirectoryListing.new(request_path, path).to_s(io)
  end
end
