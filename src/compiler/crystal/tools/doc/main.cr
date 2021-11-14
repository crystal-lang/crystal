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
      JSON.build(io) { |json| to_json_search json }
      io << ')'
    end

    def to_json(builder : JSON::Builder)
      builder.object do
        builder.field "repository_name", project_info.name
        builder.field "body", body
        builder.field "program", program
      end
    end

    def to_json_search(builder : JSON::Builder)
      builder.object do
        builder.field "repository_name", project_info.name
        builder.field "body", body
        builder.field "program" { program.to_json_search builder }
      end
    end

    def to_json_search
      JSON.build { |json| to_json_search json }
    end
  end
end
