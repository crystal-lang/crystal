require "../syntax/ast"
require "../compiler"
require "./table_print"
require "json"

module Crystal
  class PrettyTypeNameJsonConverter
    def self.to_json(hash, json : JSON::Builder)
      json.object do
        hash.each do |key, value|
          json.field key, pretty_type_name(value)
        end
      end
    end

    def self.pretty_type_name(type)
      String.build do |io|
        type.to_s_with_options(io, true)
      end
    end

    def self.pretty_type_name(type, io)
      type.to_s_with_options(io, true)
    end
  end

  class HashStringType < Hash(String, Type)
    def to_json(json : JSON::Builder)
      PrettyTypeNameJsonConverter.to_json(self, json)
    end
  end

  class ContextResult
    JSON.mapping({
      status:   {type: String},
      message:  {type: String},
      contexts: {type: Array(HashStringType), nilable: true},
    })

    def initialize(@status, @message)
    end

    def to_text(io)
      io.puts message

      if (ctxs = contexts) && ctxs.size > 0
        exprs = ctxs.first.keys

        io.puts
        TablePrint.new(io).build do
          row do
            cell "Expr"
            cell "Type", colspan: ctxs.size
          end
          separator

          exprs.each do |expr|
            row do
              cell expr
              ctxs.each do |ctx|
                cell align: :center do |io|
                  PrettyTypeNameJsonConverter.pretty_type_name(ctx[expr], io)
                end
              end
            end
          end
        end
        io.puts
      end
    end
  end

  class RechableVisitor < Visitor
    def initialize(@context_visitor : Crystal::ContextVisitor)
      @visited_typed_defs = Set(UInt64).new
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

    def visit(node : Def)
      should_visit = !@visited_typed_defs.includes?(node.object_id)
      @visited_typed_defs << node.object_id if should_visit
      return should_visit
    end

    def visit(node)
      true
    end
  end

  class ContextVisitor < Visitor
    getter contexts : Array(HashStringType)
    getter def_with_yield : Def?

    def initialize(@target_location : Location)
      @contexts = Array(HashStringType).new
      @context = HashStringType.new
      @def_with_yield = nil
    end

    def process_instance_defs(type)
      if type.is_a?(DefInstanceContainer)
        type.def_instances.values.try do |typed_defs|
          typed_defs.each do |typed_def|
            if loc = typed_def.location
              if loc.filename == typed_def.end_location.try(&.filename) && contains_target(typed_def)
                visit_and_append_context(typed_def) do
                  yield
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

    def process_type(type)
      process_type(type) { }
    end

    def process_type(type, &block)
      if type.is_a?(NamedType)
        type.types?.try &.values.each do |inner_type|
          process_type(inner_type)
        end
      end

      if type.is_a?(GenericType)
        type_vars = type.type_vars
        type.generic_types.each do |type_vars_args, instanced_types|
          process_type(instanced_types) do
            type_vars.each.zip(type_vars_args.each).each do |e|
              generic_arg_name, generic_arg_type = e
              # TODO handle generic_arg_type that are not types but ASTNode
              add_context generic_arg_name, generic_arg_type if generic_arg_type.is_a?(Type)
            end
          end
        end
      else
        process_instance_defs type.metaclass, &block
        process_instance_defs type, &block
      end
    end

    def process(result : Compiler::Result)
      result.program.def_instances.each_value do |typed_def|
        visit_and_append_context typed_def
      end

      result.program.types?.try &.values.each do |type|
        process_type type
      end

      if @contexts.empty?
        @context = HashStringType.new
        result.program.vars.each do |name, var|
          add_context name, var.type
        end
        result.node.accept(self)

        if @def_with_yield
          @context = HashStringType.new
          result.node.accept(RechableVisitor.new(self))
        end

        # TODO should apply only if user is really in some of the nodes of the main expressions
        @contexts << @context unless @context.empty?
      end

      if @contexts.empty?
        return ContextResult.new("failed", "no context information found")
      else
        res = ContextResult.new("ok", "#{@contexts.size} possible context#{@contexts.size > 1 ? "s" : ""} found")
        res.contexts = @contexts
        return res
      end
    end

    def visit_and_append_context(node)
      visit_and_append_context(node) { }
    end

    def visit_and_append_context(node, &block)
      @context = HashStringType.new
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
          vars.each do |_, var|
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

    # TODO handle type filters of case statements

    def visit(node : If)
      if contains_target(node)
        # TODO handle conditions in expressions
        case cond = node.cond
        when Var
          filters = TypeFilters.truthy(cond)
        when IsA
          if (obj = cond.obj).is_a?(Var)
            filters = TypeFilters.new(obj, SimpleTypeFilter.new(cond.const.type))
          end
        end

        if filters
          # make a copy of the current context
          current_context = {} of String => MetaVar
          @context.each do |name, type|
            current_context[name] = MetaVar.new(name, type)
          end

          # restrict the whole context
          filters.each do |name, filter|
            filtered_var = current_context[name]
            filtered_var.bind_to(current_context[name].filtered_by(filter))
            add_context name, filtered_var.type
          end
        end

        return true
      end
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
