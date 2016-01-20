require "ecr/macros"
require "html"
require "uri"

class HTTP::StaticFileHandler < HTTP::Handler
  def initialize(publicdir)
    @publicdir = File.expand_path publicdir
  end

  def call(request)
    request_path = URI.unescape(request.path.not_nil!)

    # File path cannot contains '\0' (NUL) because all filesystem I know
    # don't accept '\0' character as file name.
    return HTTP::Response.new(400) if request_path.includes? '\0'

    expanded_path = File.expand_path(request_path, "/")

    file_path = File.join(@publicdir, expanded_path)
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
    def escaped_request_path
      @escaped_request_path ||= begin
        esc_path = request_path.split('/').map { |path| URI.escape path }.join('/')
        esc_path = esc_path[0..-2] if !esc_path.empty? && esc_path[-1] == '/'
        esc_path
      end
    end

    ecr_file "#{__DIR__}/static_file_handler.html"
  end

  private def directory_listing(request_path, path)
    DirectoryListing.new(request_path, path).to_s
  end
end
