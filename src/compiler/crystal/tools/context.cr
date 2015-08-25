require "../syntax/ast"
require "../compiler"
require "./table_print"
require "json"

module Crystal
  class Type
    def to_json(io)
      self.to_s.to_json(io)
    end
  end

  class ContextResult
    json_mapping({
      status:           {type: String},
      message:          {type: String},
      contexts:         {type: Array(Hash(String, Type)), nilable: true},
    })

    def initialize(@status, @message)
    end

    def to_text(io)
      io.puts message

      if (ctxs = contexts) && ctxs.length > 0
        exprs = ctxs.first.keys

        io.puts
        TablePrint.new(io).build do
          row do
            cell "Expr"
            cell "Type", colspan: ctxs.length
          end
          separator

          exprs.each do |expr|
            row do
              cell expr
              ctxs.each do |ctx|
                cell ctx[expr].to_s, align: :center
              end
            end
          end
        end
        io.puts

      end
    end
  end

  class RechableVisitor < Visitor
    def initialize(@context_visitor)
    end

    def visit(node : Call)
      return false if node.obj.nil? && node.name == "raise"
      node.target_defs.try do |defs|
        defs.each do |typed_def|
          typed_def.accept(self)
          next unless @context_visitor.def_with_yield.not_nil!.location == typed_def.location
          typed_def.accept(@context_visitor)
        end
      end
      true
    end

    def visit(node)
      true
    end
  end

  class ContextVisitor < Visitor
    getter contexts
    getter def_with_yield

    def initialize(@target_location)
      @contexts = Array(Hash(String, Type)).new
      @context = Hash(String, Type).new
      @def_with_yield = nil
    end

    def process(result : Compiler::Result)
      result.program.def_instances.each_value do |typed_def|
        visit_and_append_context typed_def
      end

      result.program.types.values.each do |type|
        if type.is_a?(DefInstanceContainer)
          type.def_instances.values.try do |typed_defs|
            typed_defs.each do |typed_def|
              if loc = typed_def.location
                if loc.filename == typed_def.end_location.try(&.filename) && contains_target(typed_def)
                  visit_and_append_context(typed_def) do
                    add_context "self", type
                    if type.is_a?(InstanceVarContainer)
                      type.instance_vars.values.each do |ivar|
                        add_context ivar.name, ivar.type
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      if @contexts.empty?
        @context = Hash(String, Type).new
        result.program.vars.each do |name, var|
          add_context name, var.type
        end
        result.node.accept(self)

        if @def_with_yield
          @context = Hash(String, Type).new
          result.node.accept(RechableVisitor.new(self))
        end

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

    def visit_and_append_context(node)
      visit_and_append_context(node) { }
    end

    def visit_and_append_context(node, &block)
      @context = Hash(String, Type).new
      yield
      node.accept(self)
      @contexts << @context unless @context.empty?
    end

    def visit(node : Def)
      if contains_target(node)

        if @def_with_yield.nil? && !node.yields.nil?
          @def_with_yield = node
          return false
        end

        node.args.each do |arg|
          add_context arg.name, arg.type
        end
        node.vars.try do |vars|
          vars.each do |name, meta_var|
            add_context name, meta_var.type
          end
        end
        return true
      end
    end

    def visit(node : Block)
      if contains_target(node)
        node.args.each do |arg|
          add_context arg.name, arg.type
        end
        node.vars.try do |vars|
          vars.each do |_,var|
            add_context var.name, var.type
          end
        end
        return true
      end
    end

    def visit(node : Call)
      if node.location && @target_location.between?(node.name_location, node.name_end_location)
        add_context node.to_s, node.type
      end

      contains_target(node)
    end

    def visit(node)
      contains_target(node)
    end

    private def add_context(name, type)
      return if name.starts_with?("__temp_") # ignore temp vars
      return if name == "self" && type.to_s == "<Program>"

      @context[name] = type
    end

    private def contains_target(node)
      if loc_start = node.location
        loc_end = node.end_location || loc_start
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
