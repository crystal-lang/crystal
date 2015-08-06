require "../syntax/ast"
require "../compiler"
require "json"

module Crystal
  class ContextResult
    json_mapping({
      status:           {type: String},
      message:          {type: String},
      contexts:         {type: Array(Hash(String, Type)), nilable: true},
    })

    def initialize(@status, @message)
    end
  end

  class ContextVisitor < Visitor
    getter contexts

    def initialize(@target_location)
      @contexts = Array(Hash(String, Type)).new
      @context = Hash(String, Type).new
    end

    def process(result : Compiler::Result)
      result.program.def_instances.each_value do |typed_def|
        @context = Hash(String, Type).new
        typed_def.accept(self)
        @contexts << @context unless @context.empty?
      end

      if @contexts.empty?
        @context = Hash(String, Type).new
        result.program.vars.each do |name, var|
          # TODO ignore temp vars
          @context[name] = var.type
        end
        result.node.accept(self)
        # TODO should apply only if user is really in some of the nodes of the main expressions
        @contexts << @context unless @context.empty?
      end

      if @contexts.empty?
        return ContextResult.new("failed", "no context information found")
      else
        res = ContextResult.new("ok", "#{@contexts.count} possible context#{@contexts.count > 1 ? "s" : ""} found")
        res.contexts = @contexts
        return res
      end
    end

    def visit(node : Def)
      if contains_target(node) && (vars = node.vars)
        vars.each do |name, meta_var|
          @context[name] = meta_var.type
        end
        return true
      end
    end

    def visit(node : Block)
      if contains_target(node)
        node.args.each do |arg|
          @context[arg.name] = arg.type
        end
        return true
      end
    end

    def visit(node)
      contains_target(node)
    end

    private def contains_target(node)
      if loc_start = node.location
        loc_end = node.end_location.not_nil!
        # if it is not between, it could be the case that node is the top level Expressions
        # in which the (start) location might be in one file and the end location in another.
        @target_location.between?(loc_start, loc_end) || loc_start.filename != loc_end.filename
      else
        # if node has no location, assume they may contain the target.
        # for example with the main expressions ast node this matters
        true
      end
    end
  end
end
