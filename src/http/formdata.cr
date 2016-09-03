module HTTP::FormData
  # Generates a multipart/form-data message, yielding a `FormData::Generator`
  # object to the block which writes to *io* using *boundary*.
  # `Generator#finish` is called on the generator when the block returns.
  #
  # ```
  # io = MemoryIO.new
  # HTTP::FormData.generate(io, "boundary") do |generator|
  #   generator.field("foo", "bar")
  # end
  # io.to_s # => "--boundary\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--boundary--"
  # ```
  #
  # See: `FormData::Generator`
  def self.generate(io, boundary = "--------------------------#{SecureRandom.urlsafe_base64(18)}")
    generator = Generator.new(io, boundary)
    yield generator
    generator.finish
  end

  # Generates a multipart/form-data message, yielding a `FormData::Generator`
  # object to the block which writes to *response* using *boundary.
  # Content-Type is set on *response* and `Generator#finish` is called on the
  # generator when the block returns.
  #
  # ```
  # io = MemoryIO.new
  # response = HTTP::Server::Response.new io
  # HTTP::FormData.generate(response, "boundary") do |generator|
  #   generator.field("foo", "bar")
  # end
  # response.close
  #
  # response.headers["Content-Type"] # => "multipart/form-data; boundary=\"boundary\""
  # io.to_s                          # => "HTTP/1.1 200 OK\r\nContent-Type: multipart/form-data; boundary=\"boundary\"\r\n ...
  # ```
  #
  # See: `FormData::Generator`
  def self.generate(response : HTTP::Server::Response, boundary = "--------------------------#{SecureRandom.urlsafe_base64(18)}")
    generator = Generator.new(response, boundary)
    yield generator
    generator.finish
    response.headers["Content-Type"] = generator.content_type
  end

  # Metadata which may be available for uploaded files.
  record FileMetadata,
    filename : String? = nil,
    creation_time : Time? = nil,
    modification_time : Time? = nil,
    read_time : Time? = nil,
    size : UInt64? = nil
end
