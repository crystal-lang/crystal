require "ecr/macros"
require "html"
require "uri"
require "mime"

# A handler that lists directories and serves files under a given public directory.
#
# This handler can send precompressed content, if the client accepts it, and a file
# with the same name and `.gz` extension appended is found in the same directory.
# Precompressed files are only served if they are newer than the original file.
class HTTP::StaticFileHandler
  include HTTP::Handler

  @public_dir : Path

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
    @public_dir = Path.new(public_dir).expand
    @fallthrough = !!fallthrough
    @directory_listing = !!directory_listing
  end

  def call(context)
    unless context.request.method.in?("GET", "HEAD")
      if @fallthrough
        call_next(context)
      else
        context.response.status = :method_not_allowed
        context.response.headers.add("Allow", "GET, HEAD")
      end
      return
    end

    original_path = context.request.path.not_nil!
    is_dir_path = original_path.ends_with?("/")
    request_path = self.request_path(URI.decode(original_path))

    # File path cannot contains '\0' (NUL) because all filesystem I know
    # don't accept '\0' character as file name.
    if request_path.includes? '\0'
      context.response.respond_with_status(:bad_request)
      return
    end

    request_path = Path.posix(request_path)
    expanded_path = request_path.expand("/")

    file_path = @public_dir.join(expanded_path.to_kind(Path::Kind.native))
    is_dir = Dir.exists? file_path
    is_file = !is_dir && File.exists?(file_path)

    if request_path != expanded_path || is_dir && !is_dir_path
      redirect_path = expanded_path
      if is_dir && !is_dir_path
        # Append / to path if missing
        redirect_path = expanded_path.join("")
      end
      redirect_to context, redirect_path
      return
    end

    if @directory_listing && is_dir
      context.response.content_type = "text/html"
      directory_listing(context.response, request_path, file_path)
    elsif is_file
      last_modified = modification_time(file_path)
      add_cache_headers(context.response.headers, last_modified)

      if cache_request?(context, last_modified)
        context.response.status = :not_modified
        return
      end

      context.response.content_type = MIME.from_filename(file_path.to_s, "application/octet-stream")

      # Checks if pre-gzipped file can be served
      if context.request.headers.includes_word?("Accept-Encoding", "gzip")
        gz_file_path = "#{file_path}.gz"

        if File.exists?(gz_file_path) &&
           # Allow small time drift. In some file systems, using `gz --keep` to
           # compress the file will keep the modification time of the original file
           # but truncating some decimals
           last_modified - modification_time(gz_file_path) < 1.millisecond
          file_path = gz_file_path
          context.response.headers["Content-Encoding"] = "gzip"
        end
      end

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
    context.response.status = :found

    url = URI.encode(url.to_s)
    context.response.headers.add "Location", url
  end

  private def add_cache_headers(response_headers : HTTP::Headers, last_modified : Time) : Nil
    response_headers["Etag"] = etag(last_modified)
    response_headers["Last-Modified"] = HTTP.format_time(last_modified)
  end

  private def cache_request?(context : HTTP::Server::Context, last_modified : Time) : Bool
    # According to RFC 7232:
    # A recipient must ignore If-Modified-Since if the request contains an If-None-Match header field
    if if_none_match = context.request.if_none_match
      match = {"*", context.response.headers["Etag"]}
      if_none_match.any? { |etag| match.includes?(etag) }
    elsif if_modified_since = context.request.headers["If-Modified-Since"]?
      header_time = HTTP.parse_time(if_modified_since)
      # File mtime probably has a higher resolution than the header value.
      # An exact comparison might be slightly off, so we add 1s padding.
      # Static files should generally not be modified in subsecond intervals, so this is perfectly safe.
      # This might be replaced by a more sophisticated time comparison when it becomes available.
      !!(header_time && last_modified <= header_time + 1.second)
    else
      false
    end
  end

  private def etag(modification_time)
    %{W/"#{modification_time.to_unix}"}
  end

  private def modification_time(file_path)
    File.info(file_path).modification_time
  end

  record DirectoryListing, request_path : String, path : String do
    def each_entry
      Dir.each_child(path) do |entry|
        yield entry
      end
    end

    ECR.def_to_s "#{__DIR__}/static_file_handler.html"
  end

  private def directory_listing(io, request_path, path)
    DirectoryListing.new(request_path.to_s, path.to_s).to_s(io)
  end
end
