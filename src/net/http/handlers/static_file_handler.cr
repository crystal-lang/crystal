class HTTP::StaticFileHandler < HTTP::Handler
  def initialize(@publicdir)
  end

  def call(request)
    file_path = @publicdir + request.path
    if Dir.exists?(file_path)
      HTTP::Response.new("HTTP/1.1", 200, "OK", {"Content-Type" => "text/html"}, directory_listing(request.path, file_path))
    elsif File.exists?(file_path)
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

  def directory_listing(request_path, path)
    Html::Builder.new.build do
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
