require "../semantic"

class Crystal::FixMissingTypes < Crystal::Visitor
  @program : Program
  @fixed : Set(Def)

  def initialize(mod)
    @program = mod
    @fixed = Set(Def).new.compare_by_identity
  end

  def visit(node : Def)
    node.hook_expansions.try &.each &.accept self
    false
  end

  def visit(node : ClassDef)
    node.hook_expansions.try &.each &.accept self
    true
  end

  def visit(node : Include)
    node.hook_expansions.try &.each &.accept self
    false
  end

  def visit(node : Extend)
    node.hook_expansions.try &.each &.accept self
    false
  end

  def visit(node : Macro)
    false
  end

  def visit(node : ProcLiteral)
    node.def.body.accept self
    unless node.def.type?
      node.def.type = @program.no_return
    end
    false
  end

  def visit(node : ProcPointer)
    if expanded = node.expanded
      expanded.accept(self)
    else
      node.call?.try &.accept self
    end
    false
  end

  def end_visit(node : ProcPointer)
    if !node.type? && node.call?
      arg_types = node.call.args.map &.type
      arg_types.push @program.no_return
      node.type = node.call.type = @program.proc_of(arg_types)
    end
  end

  def visit(node : ExpandableNode)
    node.expanded.try &.accept self
    false
  end

  def end_visit(node : Call)
    if expanded = node.expanded
      expanded.accept self
    end

    # If the block doesn't have a type, it's a no-return.
    block = node.block
    if block && !block.type?
      block.type = @program.no_return
    end

    node.target_defs.try &.each do |target_def|
      if @fixed.add?(target_def)
        target_def.type = @program.no_return unless target_def.type?
        target_def.accept_children self
      end
    end
  end

  def visit(node : ASTNode)
    true
  end
end
