module Crystal::Doc
  record Main, body : String, program : Type, project_info : ProjectInfo do
    def to_s(io : IO) : Nil
      to_json(io)
    end

    def to_jsonp
      String.build do |io|
        to_jsonp(io)
      end
    end

    def to_jsonp(io : IO)
      io << "crystal_doc_search_index_callback("
      to_json(io)
      io << ')'
    end

    def to_json(builder : JSON::Builder)
      builder.object do
        builder.field "repository_name", project_info.name
        builder.field "body", body
        builder.field "program", program
      end
    end
  end
end
