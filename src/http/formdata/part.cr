module HTTP::FormData
  struct Part
    getter name : String
    getter body : IO
    getter headers : HTTP::Headers

    getter filename : String?
    getter creation_time : Time?
    getter modification_time : Time?
    getter read_time : Time?
    getter size : UInt64?

    def initialize(@headers : HTTP::Headers, @body : IO)
      content_disposition = headers.get?("Content-Disposition").try(&.[0])
      raise Error.new("Failed to parse form-data: Content-Disposition not found") unless content_disposition

      @name, content_disposition = FormData.parse_content_disposition(content_disposition)
      @filename = content_disposition.filename
      @creation_time = content_disposition.creation_time
      @modification_time = content_disposition.modification_time
      @read_time = content_disposition.read_time
      @size = content_disposition.size
    end
  end
end
