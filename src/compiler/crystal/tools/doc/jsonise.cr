require "json"
require "json/*"

module Crystal::Doc::JSONise
  macro mapping(src, properties, strict = false)
    JSON.mapping({{properties}}, {{strict}})

    def initialize(src : {{src.id}})
      {% for key, value in properties %}
        {% if value[:wrap] %}
          {% if value[:type].is_a?(Generic) %}
            @{{key.id}} = src.{{(value[:method] || key).id}}.map { |s| {{ value[:wrap].id }}.new(s).as({{ value[:wrap].id }}) }
          {% else %}
            @{{key.id}} =
              {% if value[:nilable] %}
                (%orig = src.{{(value[:method] || key).id}}) ? {{ value[:wrap].id }}.new(%orig) : nil
              {% else %}
                {{ value[:wrap].id }}.new(src.{{(value[:method] || key).id}})
              {% end %}
          {% end %}
        {% else %}
          @{{key.id}} = src.{{(value[:method] || key).id}}
        {% end %}
      {% end %}
    end

    def to_s(io : IO)
      to_json(io)
    end
  end

  macro mapping(src, **properties)
    JSONise.mapping({{src}}, {{properties}})
  end

  record Main, body : String, types : Array(TypeRef), repository_name : String do
    JSON.mapping(
      repository_name: {type: String, nilable: false},
      body: {type: String, nilable: false},
      types: {type: Array(TypeRef), nilable: false}
    )

    def to_s(io : IO)
      to_json(io)
    end
  end

  class Type
    JSONise.mapping(
      Crystal::Doc::Type,
      html_id: {type: String, nilable: false},
      json_path: {type: String, nilable: false},
      kind: {type: Symbol, nilable: true},
      full_name: {type: String, nilable: false},
      name: {type: String, nilable: false},
      abstract: {type: Bool, nilable: false, method: :abstract?},
      superclass: {type: TypeRef, nilable: true, wrap: TypeRef},
      ancestors: {type: Array(TypeRef), nilable: false, wrap: TypeRef},
      locations: {type: Array(RelativeLocation), nilable: false, wrap: RelativeLocation},
      repository_name: {type: String, nilable: false},
      program: {type: Bool, nilable: false, method: :program?},
      enum: {type: Bool, nilable: false, method: :enum?},
      alias: {type: Bool, nilable: false, method: :alias?},
      aliased: {type: String, nilable: true, method: "alias_definition.try(&.to_s)"},
      const: {type: Bool, nilable: false, method: :const?},
      types: {type: Array(TypeRef), nilable: false, wrap: TypeRef},
      constants: {type: Array(Constant), nilable: false, wrap: Constant},
      included_modules: {type: Array(TypeRef), nilable: false, wrap: TypeRef},
      extended_modules: {type: Array(TypeRef), nilable: false, wrap: TypeRef},
      subclasses: {type: Array(TypeRef), nilable: false, wrap: TypeRef},
      including_types: {type: Array(TypeRef), nilable: false, wrap: TypeRef},
      namespace: {type: TypeRef, nilable: true, wrap: TypeRef},
      doc: {type: String, nilable: true},
      class_methods: {type: Array(Method), nilable: false, wrap: Method},
      instance_methods: {type: Array(Method), nilable: false, wrap: Method},
      macros: {type: Array(Macro), nilable: false, wrap: Macro}
    )
  end

  class TypeRef
    JSONise.mapping(
      Crystal::Doc::Type,
      html_id: {type: String, nilable: false},
      json_path: {type: String, nilable: false},
      kind: {type: Symbol, nilable: true},
      full_name: {type: String, nilable: false},
      name: {type: String, nilable: false}
    )
  end

  class Constant
    JSONise.mapping(
      Crystal::Doc::Constant,
      name: {type: String, nilable: false},
      doc: {type: String, nilable: true},
      value: {type: String, nilable: true, method: "value.to_s"}
    )
  end

  class Method
    JSONise.mapping(
      Crystal::Doc::Method,
      id: {type: String, nilable: false},
      html_id: {type: String, nilable: false},
      name: {type: String, nilable: false},
      doc: {type: String, nilable: true},
      abstract: {type: Bool, nilable: false, method: :abstract?},
      args: {type: String, nilable: true, method: :args_to_s},
      source_link: {type: String, nilable: true},
      def: {type: DefAST, nilable: false, wrap: DefAST}
    )
  end

  class Macro
    JSONise.mapping(
      Crystal::Doc::Macro,
      id: {type: String, nilable: false},
      html_id: {type: String, nilable: false},
      name: {type: String, nilable: false},
      doc: {type: String, nilable: true},
      abstract: {type: Bool, nilable: false, method: :abstract?},
      args: {type: String, nilable: true, method: :args_to_s},
      source_link: {type: String, nilable: true},
      def: {type: MacroAST, nilable: false, wrap: MacroAST, method: :macro}
    )
  end

  class DefAST
    JSONise.mapping(
      Crystal::Def,
      name: {type: String, nilable: false},
      args: {type: Array(ArgAST), nilable: false, wrap: ArgAST},
      double_splat: {type: ArgAST, nilable: true, wrap: ArgAST},
      splat_index: {type: Int32, nilable: true},
      yields: {type: Int32, nilable: true},
      block_arg: {type: ArgAST, nilable: true, wrap: ArgAST},
      return_type: {type: String, nilable: true, method: "return_type.try(&.to_s)"},
      visibility: {type: String, nilable: false, method: "visibility.to_s"},
      body: {type: String, nilable: true, method: "body.try(&.to_s)"}
    )
  end

  class MacroAST
    JSONise.mapping(
      Crystal::Macro,
      name: {type: String, nilable: false},
      args: {type: Array(ArgAST), nilable: false, wrap: ArgAST},
      double_splat: {type: ArgAST, nilable: true, wrap: ArgAST},
      splat_index: {type: Int32, nilable: true},
      block_arg: {type: ArgAST, nilable: true, wrap: ArgAST},
      visibility: {type: String, nilable: false, method: "visibility.to_s"},
      body: {type: String, nilable: true, method: "body.try(&.to_s)"}
    )
  end

  class ArgAST
    JSONise.mapping(
      Crystal::Arg,
      name: {type: String, nilable: false},
      doc: {type: String, nilable: true},
      default_value: {type: String, nilable: true, method: "default_value.try(&.to_s)"},
      external_name: {type: String, nilable: false, method: "external_name.try(&.to_s)"},
      restriction: {type: String, nilable: true, method: "restriction.try(&.to_s)"}
    )
  end

  class RelativeLocation
    JSONise.mapping(
      Crystal::Doc::Generator::RelativeLocation,
      filename: {type: String, nilable: false, default: ""},
      line_number: {type: Int32, nilable: false, default: 0},
      url: {type: String, nilable: true}
    )
  end
end
