module Crystal::Doc
  record Main, body : String, program : Type, repository_name : String do
    def to_s(io : IO)
      to_json(io)
    end

    def to_json(builder : JSON::Builder)
      builder.object do
        builder.field "repository_name", repository_name
        builder.field "body", body
        builder.field "program", program
      end
    end
  end
end
