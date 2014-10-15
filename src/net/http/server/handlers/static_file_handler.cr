require "html/builder"

class HTTP::StaticFileHandler < HTTP::Handler
  def initialize(@publicdir)
  end

  def call(request)
    file_path = @publicdir + request.path
    if Dir.exists?(file_path)
      headers = HTTP::Headers.new
      headers["Content-type"] = "text/html"
      HTTP::Response.new(200, directory_listing(request.path, file_path), headers)
    elsif File.exists?(file_path)
      headers = HTTP::Headers.new
      headers["Content-type"] = mime_type(file_path)
      HTTP::Response.new(200, File.read(file_path), headers)
    else
      call_next(request)
    end
  end

  private def mime_type(path)
    case File.extname(path)
    when ".txt" then "text/plain"
    when ".htm", ".html" then "text/html"
    when ".css" then "text/css"
    when ".js" then "application/javascript"
    else "application/octet-stream"
    end
  end

  private def directory_listing(request_path, path)
    HTML::Builder.new.build do
      html do
        title { text "Directory listing for #{request_path}" }
        body do
          h2 { text "Directory listing for #{request_path}" }
          hr
          ul do
            Dir.list(path) do |entry|
              next if entry == "." || entry == ".."
              li do
                a({href: "#{request_path == "/" ? "" : request_path}/#{entry}"}) { text entry }
              end
            end
          end
        end
      end
    end
  end
end
