require "ecr/macros"
require "html"
require "uri"

# A simple handler that lists directories and serves files under a given public directory.
class HTTP::StaticFileHandler
  include HTTP::Handler

  @public_dir : String

  # Creates a handler that will serve files in the given *public_dir*, after
  # expanding it (using `File#expand_path`).
  #
  # If *fallthrough* is `false`, this handler does not call next handler when
  # request method is neither GET or HEAD, then serves `405 Method Not Allowed`.
  # Otherwise, it calls next handler.
  #
  # If *directory_listing* is `false`, directory listing is disabled. This means that
  # paths matching directories are ignored and next handler is called.
  def initialize(public_dir : String, fallthrough = true, directory_listing = true)
    @public_dir = File.expand_path public_dir
    @fallthrough = !!fallthrough
    @directory_listing = !!directory_listing
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

    original_path = context.request.path.not_nil!
    is_dir_path = original_path.ends_with? "/"
    request_path = self.request_path(URI.unescape(original_path))

    # File path cannot contains '\0' (NUL) because all filesystem I know
    # don't accept '\0' character as file name.
    if request_path.includes? '\0'
      context.response.status_code = 400
      return
    end

    expanded_path = File.expand_path(request_path, "/")
    if is_dir_path && !expanded_path.ends_with? "/"
      expanded_path = "#{expanded_path}/"
    end
    is_dir_path = expanded_path.ends_with? "/"

    file_path = File.join(@public_dir, expanded_path)
    is_dir = Dir.exists? file_path
    is_file = !is_dir && File.exists?(file_path)

    if request_path != expanded_path || is_dir && !is_dir_path
      redirect_to context, "#{expanded_path}#{is_dir && !is_dir_path ? "/" : ""}"
      return
    end

    if @directory_listing && is_dir
      context.response.content_type = "text/html"
      directory_listing(context.response, request_path, file_path)
    elsif is_file
      last_modified = File.stat(file_path).mtime
      context.response.headers["Last-Modified"] = HTTP.rfc1123_date(last_modified)

      if if_modified_since = context.request.headers["If-Modified-Since"]?
        # TODO: Use a more generalized time format parser for better compatibility to RFC 7232
        header_time = Time.parse(if_modified_since, "%a, %d %b %Y %H:%M:%S GMT")

        # File mtime probably has a higher resolution than the header value.
        # An exact comparison might be slightly off, so we add 1s padding.
        # Static files should generally not be modified in subsecond intervals, so this is perfectly safe.
        # This might replaced by a more sophisticated time comparison when it becomes available.
        if last_modified <= header_time + 1.second
          context.response.status_code = 304
          return
        end
      end

      context.response.content_type = mime_type(file_path)
      context.response.content_length = File.size(file_path)
      File.open(file_path) do |file|
        IO.copy(file, context.response)
      end
    else
      call_next(context)
    end
  end

  # given a full path of the request, returns the path
  # of the file that should be expanded at the public_dir
  protected def request_path(path : String) : String
    path
  end

  private def redirect_to(context, url)
    context.response.status_code = 302

    url = URI.escape(url) { |b| URI.unreserved?(b) || b != '/' }
    context.response.headers.add "Location", url
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

  record DirectoryListing, request_path : String, path : String do
    @escaped_request_path : String?

    def escaped_request_path
      @escaped_request_path ||= begin
        esc_path = URI.escape(request_path) { |b| URI.unreserved?(b) || b != '/' }
        esc_path = esc_path.chomp('/')
        esc_path
      end
    end

    ECR.def_to_s "#{__DIR__}/static_file_handler.html"
  end

  private def directory_listing(io, request_path, path)
    DirectoryListing.new(request_path, path).to_s(io)
  end
end
