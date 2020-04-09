# Base visitor for semantic analysis. It traveses the whole
# ASTNode tree, keeping a `current_type` in context, which corresponds
# to the type being visited according to class/module/lib definitions.
abstract class Crystal::SemanticVisitor < Crystal::Visitor
  getter program : Program

  # At every point there's a current type.
  # In the beginning this is the `Program` (top-level), but when
  # a class definition is visited this changes to that type, and so on.
  property current_type : ModuleType

  property! scope : Type
  setter scope

  @path_lookup : Type?
  @untyped_def : Def?
  @typed_def : Def?
  @block : Block?

  def initialize(@program, @vars = MetaVars.new)
    @current_type = @program
    @exp_nest = 0
    @in_lib = false
    @in_c_struct_or_union = false
    @in_is_a = false
  end

  # Transform require to its source code.
  # The source code can be a Nop if the file was already required.
  def visit(node : Require)
    if expanded = node.expanded
      expanded.accept self
      return false
    end

    if inside_exp?
      node.raise "can't require dynamically"
    end

    location = node.location
    filename = node.string
    relative_to = location.try &.original_filename

    # Remember that the program depends on this require
    @program.record_require(filename, relative_to)

    filenames = @program.find_in_path(filename, relative_to)
    if filenames
      nodes = Array(ASTNode).new(filenames.size)
      filenames.each do |filename|
        if @program.add_to_requires(filename)
          parser = Parser.new File.read(filename), @program.string_pool
          parser.filename = filename
          parser.wants_doc = @program.wants_doc?
          parsed_nodes = parser.parse
          parsed_nodes = @program.normalize(parsed_nodes, inside_exp: inside_exp?)
          # We must type the node immediately, in case a file requires another
          # *before* one of the files in `filenames`
          parsed_nodes.accept self
          nodes << FileNode.new(parsed_nodes, filename)
        end
      end
      expanded = Expressions.from(nodes)
    else
      expanded = Nop.new
    end

    node.expanded = expanded
    node.bind_to(expanded)
    false
  rescue ex : Crystal::Exception
    node.raise "while requiring \"#{node.string}\"", ex
  rescue ex
    raise ::Exception.new("while requiring \"#{node.string}\"", ex)
  end

  def visit(node : ClassDef)
    check_outside_exp node, "declare class"
    pushing_type(node.resolved_type) do
      node.hook_expansions.try &.each &.accept self
      node.body.accept self
    end
    node.set_type(@program.nil)
    false
  end

  def visit(node : ModuleDef)
    check_outside_exp node, "declare module"
    pushing_type(node.resolved_type) do
      node.body.accept self
    end
    node.set_type(@program.nil)
    false
  end

  def visit(node : AnnotationDef)
    check_outside_exp node, "declare annotation"
    node.set_type(@program.nil)
    false
  end

  def visit(node : EnumDef)
    check_outside_exp node, "declare enum"
    pushing_type(node.resolved_type) do
      node.members.each &.accept self
    end
    node.set_type(@program.nil)
    false
  end

  def visit(node : LibDef)
    check_outside_exp node, "declare lib"
    node.set_type(@program.nil)
    false
  end

  def visit(node : Include)
    check_outside_exp node, "include"
    node.hook_expansions.try &.each &.accept self
    node.set_type(@program.nil)
    false
  end

  def visit(node : Extend)
    check_outside_exp node, "extend"
    node.hook_expansions.try &.each &.accept self
    node.set_type(@program.nil)
    false
  end

  def visit(node : Alias)
    check_outside_exp node, "declare alias"
    node.set_type(@program.nil)
    false
  end

  def visit(node : Def)
    check_outside_exp node, "declare def"
    node.hook_expansions.try &.each &.accept self
    node.set_type(@program.nil)
    false
  end

  def visit(node : Macro)
    check_outside_exp node, "declare macro"
    node.set_type(@program.nil)
    false
  end

  def visit(node : Annotation)
    annotations = @annotations ||= [] of Annotation
    annotations << node
    false
  end

  def visit(node : Call)
    !expand_macro(node, raise_on_missing_const: false)
  end

  def visit(node : MacroExpression)
    expand_inline_macro node
    false
  end

  def visit(node : MacroIf)
    expand_inline_macro node
    false
  end

  def visit(node : MacroFor)
    expand_inline_macro node
    false
  end

  def visit(node : MacroVerbatim)
    expansion = MacroIf.new(BoolLiteral.new(true), node)
    expand_inline_macro expansion

    node.expanded = expansion
    node.bind_to expansion

    false
  end

  def visit(node : ExternalVar | Path | Generic | ProcNotation | Union | Metaclass | Self | TypeOf)
    false
  end

  def visit(node : ASTNode)
    true
  end

  def visit_any(node)
    @exp_nest += 1 if nesting_exp?(node)

    true
  end

  def end_visit_any(node)
    @exp_nest -= 1 if nesting_exp?(node)

    if @annotations
      case node
      when Expressions
        # Nothing, will be taken care in individual expressions
      when Annotation
        # Nothing
      when Nop
        # Nothing (might happen as a result of an evaulated macro if)
      when Call
        # Don't clear annotations if these were generated by a macro
        unless node.expanded
          @annotations = nil
        end
      when MacroExpression, MacroIf, MacroFor
        # Don't clear annotations if these were generated by a macro
      else
        @annotations = nil
      end
    end
  end

  # Returns free variables
  def free_vars : Hash(String, TypeVar)?
    nil
  end

  def nesting_exp?(node)
    case node
    when Expressions, LibDef, CStructOrUnionDef, ClassDef, ModuleDef, FunDef, Def, Macro,
         Alias, Include, Extend, EnumDef, VisibilityModifier, MacroFor, MacroIf, MacroExpression,
         FileNode, TypeDeclaration, Require, AnnotationDef
      false
    else
      true
    end
  end

  def lookup_type(node : ASTNode,
                  free_vars = nil,
                  find_root_generic_type_parameters = true)
    current_type.lookup_type(
      node,
      free_vars: free_vars,
      allow_typeof: false,
      find_root_generic_type_parameters: find_root_generic_type_parameters
    )
  end

  def check_outside_exp(node, op)
    node.raise "can't #{op} dynamically" if inside_exp?
  end

  def expand_macro(node, raise_on_missing_const = true, first_pass = false)
    if expanded = node.expanded
      @exp_nest -= 1
      eval_macro(node) do
        expanded.accept self
      end
      @exp_nest += 1
      return true
    end

    obj = node.obj
    case obj
    when Path
      base_type = @path_lookup || @scope || @current_type
      macro_scope = base_type.lookup_type_var?(obj, free_vars: free_vars, raise: raise_on_missing_const)
      return false unless macro_scope.is_a?(Type)

      macro_scope = macro_scope.remove_alias

      the_macro = macro_scope.metaclass.lookup_macro(node.name, node.args, node.named_args)
      node.raise "private macro '#{node.name}' called for #{obj}" if the_macro.is_a?(Macro) && the_macro.visibility.private?
    when Nil
      return false if node.name == "super" || node.name == "previous_def"
      the_macro = node.lookup_macro
    else
      return false
    end

    return false unless the_macro.is_a?(Macro)

    # If we find a macro outside a def/block and this is not the first pass it means that the
    # macro was defined before we first found this call, so it's an error
    # (we must analyze the macro expansion in all passes)
    if !@typed_def && !@block && !first_pass
      node.raise "macro '#{node.name}' must be defined before this point but is defined later"
    end

    expansion_scope = (macro_scope || @scope || current_type)

    args = expand_macro_arguments(node, expansion_scope)

    @exp_nest -= 1
    generated_nodes = expand_macro(the_macro, node, visibility: node.visibility) do
      old_args = node.args
      node.args = args
      expanded_macro, macro_expansion_pragmas = @program.expand_macro the_macro, node, expansion_scope, expansion_scope, @untyped_def
      node.args = old_args
      {expanded_macro, macro_expansion_pragmas}
    end
    @exp_nest += 1

    node.expanded = generated_nodes
    node.expanded_macro = the_macro
    node.bind_to generated_nodes

    true
  end

  def expand_macro(the_macro, node, mode = nil, *, visibility : Visibility)
    expanded_macro, macro_expansion_pragmas =
      eval_macro(node) do
        yield
      end

    mode ||= if @in_c_struct_or_union
               Parser::ParseMode::LibStructOrUnion
             elsif @in_lib
               Parser::ParseMode::Lib
             else
               Parser::ParseMode::Normal
             end

    # We could do Set.new(@vars.keys) but that creates an intermediate array
    local_vars = Set(String).new(initial_capacity: @vars.size)
    @vars.each_key { |key| local_vars << key }

    generated_nodes = @program.parse_macro_source(expanded_macro, macro_expansion_pragmas, the_macro, node, local_vars,
      current_def: @typed_def,
      inside_type: !current_type.is_a?(Program),
      inside_exp: @exp_nest > 0,
      mode: mode,
      visibility: visibility,
    )

    if node_doc = node.doc
      generated_nodes.accept PropagateDocVisitor.new(node_doc)
    end

    generated_nodes.accept self
    generated_nodes
  end

  class PropagateDocVisitor < Visitor
    @doc : String

    def initialize(@doc)
    end

    def visit(node : ClassDef | ModuleDef | EnumDef | Def | FunDef | Alias | Assign | Call)
      node.doc ||= @doc
      false
    end

    def visit(node : ASTNode)
      true
    end
  end

  def expand_macro_arguments(node, expansion_scope)
    # If any argument is a MacroExpression, solve it first and
    # replace Path with Const/TypeNode if it denotes such thing
    args = node.args
    if args.any? &.is_a?(MacroExpression)
      @exp_nest -= 1
      args = args.map do |arg|
        if arg.is_a?(MacroExpression)
          arg.accept self
          expanded = arg.expanded.not_nil!
          if expanded.is_a?(Path)
            expanded_type = expansion_scope.lookup_path(expanded)
            case expanded_type
            when Const
              expanded = expanded_type.value
            when Type
              expanded = TypeNode.new(expanded_type)
            else
              # go on
            end
          end
          expanded
        else
          arg
        end
      end
      @exp_nest += 1
    end
    args
  end

  def expand_inline_macro(node, mode = nil)
    if expanded = node.expanded
      eval_macro(node) do
        expanded.accept self
      end
      return expanded
    end

    the_macro = Macro.new("macro_#{node.object_id}", [] of Arg, node).at(node.location)

    skip_macro_exception = nil

    generated_nodes = expand_macro(the_macro, node, mode: mode, visibility: :public) do
      begin
        @program.expand_macro node, (@scope || current_type), @path_lookup, free_vars, @untyped_def
      rescue ex : SkipMacroException
        skip_macro_exception = ex
        {ex.expanded_before_skip, ex.macro_expansion_pragmas}
      end
    end

    node.expanded = generated_nodes
    node.bind_to generated_nodes

    raise skip_macro_exception if skip_macro_exception

    generated_nodes
  end

  def eval_macro(node)
    yield
  rescue ex : MacroRaiseException
    node.raise ex.message, exception_type: MacroRaiseException
  rescue ex : Crystal::Exception
    node.raise "expanding macro", ex
  end

  def process_annotations(annotations)
    annotations.try &.each do |ann|
      yield lookup_annotation(ann), ann
    end
  end

  def lookup_annotation(ann)
    # TODO: Since there's `Int::Primitive`, and now we'll have
    # `::Primitive`, but there's no way to specify ::Primitive
    # just yet in annotations, we temporarily hardcode
    # that `Primitive` inside annotations means the top
    # level primitive.
    # We also have the same problem with File::Flags, which
    # is an enum marked with Flags annotation.
    if ann.path.single?("Primitive")
      type = @program.primitive_annotation
    elsif ann.path.single?("Flags")
      type = @program.flags_annotation
    else
      type = lookup_type(ann.path)
    end

    unless type.is_a?(AnnotationType)
      ann.raise "#{ann.path} is not an annotation, it's a #{type.type_desc}"
    end

    type
  end

  def check_class_var_annotations
    thread_local = false
    process_annotations(@annotations) do |annotation_type, ann|
      if annotation_type == @program.thread_local_annotation
        thread_local = true
      else
        ann.raise "class variables can only be annotated with ThreadLocal"
      end
    end
    thread_local
  end

  def check_allowed_in_lib(node, type = node.type.instance_type)
    unless type.allowed_in_lib?
      msg = String.build do |msg|
        msg << "only primitive types, pointers, structs, unions, enums and tuples are allowed in lib declarations, not #{type}"
        msg << " (did you mean LibC::Int?)" if type == @program.int
        msg << " (did you mean LibC::Float?)" if type == @program.float
      end
      node.raise msg
    end

    if type.is_a?(TypeDefType) && type.typedef.proc?
      type = type.typedef
    end

    type
  end

  def check_declare_var_type(node, declared_type, variable_kind)
    type = declared_type.instance_type

    if type.is_a?(GenericClassType)
      node.raise "can't declare variable of generic non-instantiated type #{type}"
    end

    Crystal.check_type_can_be_stored(node, type, "can't use #{type} as the type of #{variable_kind}")

    declared_type
  end

  def class_var_owner(node)
    scope = (@scope || current_type).class_var_owner

    if scope.is_a?(Program)
      node.raise "can't use class variables at the top level"
    end

    scope.as(ClassVarContainer)
  end

  def interpret_enum_value(node : ASTNode, target_type : IntegerType? = nil)
    MathInterpreter
      .new(current_type, self, target_type)
      .interpret(node)
  end

  def inside_exp?
    @exp_nest > 0
  end

  def pushing_type(type : ModuleType)
    old_type = @current_type
    @current_type = type
    yield
    @current_type = old_type
  end
end
