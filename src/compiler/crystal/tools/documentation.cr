require "../syntax/ast"
require "../compiler"
require "../semantic/*"
require "./typed_def_processor"
require "json"

module Crystal
  class DocumentationResult
    include JSON::Serializable

    property status : String
    property message : String

    property documentations : Array({String, String})?

    def initialize(@status, @message)
    end

    def to_text(io : IO)
      io.puts message
      documentations.try &.each do |doc, loc|
        io.puts "#{loc}\n#{doc}\n"
      end
    end
  end

  class DocumentationVisitor < Visitor
    include TypedDefProcessor

    getter documentations : Array({String, Location})

    def initialize(@target_location : Location)
      @documentations = [] of {String, Location}
    end

    def process(result : Compiler::Result)
      process_result result

      result.node.accept(self)

      if @documentations.empty?
        DocumentationResult.new("failed", "no doc comment or method call found")
      else
        res = DocumentationResult.new("ok", "#{@documentations.size} doc comment#{@documentations.size > 1 ? "s" : ""} found")
        res.documentations = @documentations.map { |doc, loc| {doc, location_to_s(loc)} }
        res
      end
    end

    def visit(node : Call)
      return contains_target(node) unless node.location && @target_location.between?(node.name_location, node.name_end_location)

      node.target_defs.try &.each do |target_def|
        if doc = target_def.doc
          @documentations << {doc, target_def.location.not_nil!}
        end
      end
      false
    end

    def visit(node : Path)
      return contains_target(node) unless (loc = node.location) && (end_loc = node.end_location) && @target_location.between?(loc, end_loc)

      target = node.target_const || node.target_type
      target.try &.locations.try &.each do |loc|
        if doc = target.try(&.doc)
          @documentations << {doc, loc}
        end
      end

      false
    end

    def visit(node)
      contains_target(node)
    end

    private def location_to_s(loc : Location)
      f = loc.filename
      case f
      when String
        line = loc.line_number
        column = loc.column_number
        filename = f
      when VirtualFile
        macro_location = f.macro.location.not_nil!
        filename = macro_location.filename.to_s
        line = macro_location.line_number + loc.line_number
        column = loc.column_number
      else
        raise "not implemented"
      end

      "#{filename}:#{line}:#{column}"
    end
  end
end
