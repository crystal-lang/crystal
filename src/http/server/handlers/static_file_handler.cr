require "ecr/macros"
require "html"
require "uri"

# A simple handler that lists directories and serves files under a given public directory.
class HTTP::StaticFileHandler < HTTP::Handler
  # Creates a handler that will serve files in the given *public_dir*, after
  # expanding it (using `File#expand_path`).
  #
  # If *fallthrough* is `false`, this handler dose not call next handler when
  # request method is neither GET or HEAD, then serves `405 Method Not Allowed`.
  # Otherwise, it calls next handler.
  def initialize(public_dir, @fallthrough = true)
    @public_dir = File.expand_path public_dir
  end

  def call(context)
    unless context.request.method == "GET" || context.request.method == "HEAD"
      if @fallthrough
        call_next(context)
      else
        context.response.status_code = 405
        context.response.headers.add("Allow", "GET, HEAD")
      end
      return
    end

    request_path = URI.unescape(context.request.path.not_nil!)

    # File path cannot contains '\0' (NUL) because all filesystem I know
    # don't accept '\0' character as file name.
    if request_path.includes? '\0'
      context.response.status_code = 400
      return
    end

    expanded_path = File.expand_path(request_path, "/")

    file_path = File.join(@public_dir, expanded_path)
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
    def escaped_request_path
      @escaped_request_path ||= begin
        esc_path = request_path.split('/').map { |path| URI.escape path }.join('/')
        esc_path = esc_path[0..-2] if !esc_path.empty? && esc_path[-1] == '/'
        esc_path
      end
    end

    ECR.def_to_s "#{__DIR__}/static_file_handler.html"
  end

  private def directory_listing(io, request_path, path)
    DirectoryListing.new(request_path, path).to_s(io)
  end
end
