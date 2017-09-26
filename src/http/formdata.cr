require "./formdata/**"

# Contains utilities for parsing `multipart/form-data` messages, which are
# commonly used for encoding HTML form data.
#
# ### Examples
#
# Commonly, you'll want to parse a from response from a HTTP request, and
# process it. An example server which performs this task is shown below.
#
# ```
# require "http"
# require "tempfile"
#
# server = HTTP::Server.new(8085) do |context|
#   name = nil
#   file = nil
#   HTTP::FormData.parse(context.request) do |part|
#     case part.name
#     when "name"
#       name = part.body.gets_to_end
#     when "file"
#       file = Tempfile.open("upload") do |file|
#         IO.copy(part.body, file)
#       end
#     end
#   end
#
#   unless name && file
#     context.response.status_code = 400
#     next
#   end
#
#   context.response << file.path
# end
#
# server.listen
# ```
#
# To test the server, use the curl command below.
#
# ```
# $ curl http://localhost:8085/ -F name=foo -F file=@/path/to/test.file
# /tmp/upload.Yxn7cc
# ```
#
# Another common case is sending formdata to a server using HTTP::Client. Here
# is an example showing how to upload a file to the server above in crystal.
#
# ```
# require "http"
#
# IO.pipe do |reader, writer|
#   channel = Channel(String).new(1)
#
#   spawn do
#     HTTP::FormData.build(writer) do |formdata|
#       channel.send(formdata.content_type)
#
#       formdata.field("name", "foo")
#       File.open("foo.png") do |file|
#         metadata = HTTP::FormData::FileMetadata.new(filename: "foo.png")
#         headers = HTTP::Headers{"Content-Type" => "image/png"}
#         formdata.file("file", file, metadata, headers)
#       end
#     end
#
#     writer.close
#   end
#
#   headers = HTTP::Headers{"Content-Type" => channel.receive}
#   response = HTTP::Client.post("http://localhost:8085/", body: reader, headers: headers)
#
#   puts "Response code #{response.status_code}"
#   puts "File path: #{response.body}"
# end
# ```
module HTTP::FormData
  # Parses a multipart/form-data message, yielding a `FormData::Parser`.
  #
  # ```
  # form_data = "--aA40\r\nContent-Disposition: form-data; name=\"field1\"\r\n\r\nfield data\r\n--aA40--"
  # HTTP::FormData.parse(IO::Memory.new(form_data), "aA40") do |part|
  #   part.name             # => "field1"
  #   part.body.gets_to_end # => "field data"
  # end
  # ```
  #
  # See: `FormData::Parser`
  def self.parse(io, boundary)
    parser = Parser.new(io, boundary)
    while parser.has_next?
      parser.next { |part| yield part }
    end
  end

  # Parses a multipart/form-data message, yielding a `FormData::Parser`.
  #
  # ```
  # headers = HTTP::Headers{"Content-Type" => "multipart/form-data; boundary=aA40"}
  # body = "--aA40\r\nContent-Disposition: form-data; name=\"field1\"\r\n\r\nfield data\r\n--aA40--"
  # request = HTTP::Request.new("POST", "/", headers, body)
  #
  # HTTP::FormData.parse(request) do |part|
  #   part.name             # => "field1"
  #   part.body.gets_to_end # => "field data"
  # end
  # ```
  #
  # See: `FormData::Parser`
  def self.parse(request : HTTP::Request)
    body = request.body
    raise Error.new "Cannot extract form-data from HTTP request: body is empty" unless body

    boundary = request.headers["Content-Type"]?.try { |header| Multipart.parse_boundary(header) }
    raise Error.new "Cannot extract form-data from HTTP request: could not find boundary in Content-Type" unless boundary

    parse(body, boundary) { |part| yield part }
  end

  # Parses a `Content-Disposition` header string into a field name and
  # `FileMetadata`. Please note that the `Content-Disposition` header for
  # `multipart/form-data` is not compatible with the original definition in
  # [RFC 2183](https://tools.ietf.org/html/rfc2183), but are instead specified
  # in [RFC 2388](https://tools.ietf.org/html/rfc2388).
  def self.parse_content_disposition(content_disposition) : {String, FileMetadata}
    filename = nil
    creation_time = nil
    modification_time = nil
    read_time = nil
    size = nil
    name = nil

    parts = content_disposition.split(';')
    type = parts[0]
    raise Error.new("Invalid Content-Disposition: not form-data") unless type == "form-data"
    (1...parts.size).each do |i|
      part = parts[i]

      key, value = part.split('=', 2)
      key = key.strip
      value = value.strip
      if value[0] == '"'
        value = HTTP.dequote_string(value[1...-1])
      end

      case key
      when "filename"
        filename = value
      when "creation-date"
        creation_time = HTTP.parse_time value
      when "modification-date"
        modification_time = HTTP.parse_time value
      when "read-date"
        read_time = HTTP.parse_time value
      when "size"
        size = value.to_u64
      when "name"
        name = value
      end
    end

    raise Error.new("Invalid Content-Disposition: no name field") unless name
    {name, FileMetadata.new(filename, creation_time, modification_time, read_time, size)}
  end

  # Builds a multipart/form-data message, yielding a `FormData::Builder`
  # object to the block which writes to *io* using *boundary*.
  # `Builder#finish` is called on the builder when the block returns.
  #
  # ```
  # io = IO::Memory.new
  # HTTP::FormData.build(io, "boundary") do |builder|
  #   builder.field("foo", "bar")
  # end
  # io.to_s # => "--boundary\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--boundary--"
  # ```
  #
  # See: `FormData::Builder`
  def self.build(io, boundary = Multipart.generate_boundary)
    builder = Builder.new(io, boundary)
    yield builder
    builder.finish
  end

  # Builds a multipart/form-data message, yielding a `FormData::Builder`
  # object to the block which writes to *response* using *boundary.
  # Content-Type is set on *response* and `Builder#finish` is called on the
  # builder when the block returns.
  #
  # ```
  # io = IO::Memory.new
  # response = HTTP::Server::Response.new io
  # HTTP::FormData.build(response, "boundary") do |builder|
  #   builder.field("foo", "bar")
  # end
  # response.close
  #
  # response.headers["Content-Type"] # => "multipart/form-data; boundary=\"boundary\""
  # io.to_s                          # => "HTTP/1.1 200 OK\r\nContent-Type: multipart/form-data; boundary=\"boundary\"\r\n ...
  # ```
  #
  # See: `FormData::Builder`
  def self.build(response : HTTP::Server::Response, boundary = Multipart.generate_boundary)
    builder = Builder.new(response, boundary)
    yield builder
    builder.finish
    response.headers["Content-Type"] = builder.content_type
  end

  # Metadata which may be available for uploaded files.
  record FileMetadata,
    filename : String? = nil,
    creation_time : Time? = nil,
    modification_time : Time? = nil,
    read_time : Time? = nil,
    size : UInt64? = nil

  class Error < Exception
  end
end
