module Crystal
  class ASTNode
    def transform(transformer)
      transformer.before_transform self
      node = transformer.transform self
      transformer.after_transform self
      node
    end
  end

  class Transformer
    def before_transform(node)
    end

    def after_transform(node)
    end

    def transform(node : Expressions)
      exps = [] of ASTNode
      node.expressions.each do |exp|
        new_exp = exp.transform(self)
        if new_exp
          if new_exp.is_a?(Expressions)
            exps.concat new_exp.expressions
          else
            exps << new_exp
          end
        end
      end

      if exps.length == 1
        exps[0]
      else
        node.expressions = exps
        node
      end
    end

    def transform(node : Call)
      if node_obj = node.obj
        node.obj = node_obj.transform(self)
      end
      transform_many node.args

      if node_block = node.block
        node.block = node_block.transform(self)
      end

      if node_block_arg = node.block_arg
        node.block_arg = node_block_arg.transform(self)
      end

      node
    end

    def transform(node : And)
      node.left = node.left.transform(self)
      node.right = node.right.transform(self)
      node
    end

    def transform(node : Or)
      node.left = node.left.transform(self)
      node.right = node.right.transform(self)
      node
    end

    def transform(node : StringInterpolation)
      transform_many node.expressions
      node
    end

    def transform(node : ArrayLiteral)
      transform_many node.elements

      if node_of = node.of
        node.of = node_of.transform(self)
      end

      node
    end

    def transform(node : HashLiteral)
      transform_many node.keys
      transform_many node.values

      if of_key = node.of_key
        node.of_key = of_key.transform(self)
      end

      if of_value = node.of_value
        node.of_value = of_value.transform(self)
      end

      node
    end

    def transform(node : If)
      node.cond = node.cond.transform(self)
      node.then = node.then.transform(self)
      node.else = node.else.transform(self)
      node
    end

    def transform(node : Unless)
      node.cond = node.cond.transform(self)
      node.then = node.then.transform(self)
      node.else = node.else.transform(self)
      node
    end

    def transform(node : IfDef)
      node.cond = node.cond.transform(self)
      node.then = node.then.transform(self)
      node.else = node.else.transform(self)
      node
    end

    def transform(node : MultiAssign)
      transform_many node.targets
      transform_many node.values
      node
    end

    def transform(node : SimpleOr)
      node.left = node.left.transform(self)
      node.right = node.right.transform(self)
      node
    end

    def transform(node : Def)
      transform_many node.args
      node.body = node.body.transform(self)

      if receiver = node.receiver
        node.receiver = receiver.transform(self)
      end

      if block_arg = node.block_arg
        node.block_arg = block_arg.transform(self)
      end

      node
    end

    def transform(node : Macro)
      transform_many node.args
      node.body = node.body.transform(self)

      if receiver = node.receiver
        node.receiver = receiver.transform(self)
      end

      if block_arg = node.block_arg
        node.block_arg = block_arg.transform(self)
      end

      node
    end

    def transform(node : PointerOf)
      node.exp = node.exp.transform(self)
      node
    end

    def transform(node : SizeOf)
      node.exp = node.exp.transform(self)
      node
    end

    def transform(node : InstanceSizeOf)
      node.exp = node.exp.transform(self)
      node
    end

    def transform(node : IsA)
      node.obj = node.obj.transform(self)
      node.const = node.const.transform(self)
      node
    end

    def transform(node : RespondsTo)
      node.obj = node.obj.transform(self)
      node
    end

    def transform(node : Case)
      node.cond = node.cond.transform(self)
      transform_many node.whens

      if node_else = node.else
        node.else = node_else.transform(self)
      end

      node
    end

    def transform(node : When)
      transform_many node.conds
      node.body = node.body.transform(self)
      node
    end

    def transform(node : ImplicitObj)
      node
    end

    def transform(node : ClassDef)
      node.body = node.body.transform(self)

      if superclass = node.superclass
        node.superclass = superclass.transform(self)
      end

      node
    end

    def transform(node : ModuleDef)
      node.body = node.body.transform(self)
      node
    end

    def transform(node : While)
      node.cond = node.cond.transform(self)
      node.body = node.body.transform(self)
      node
    end

    def transform(node : Generic)
      node.name = node.name.transform(self)
      transform_many node.type_vars
      node
    end

    def transform(node : ExceptionHandler)
      node.body = node.body.transform(self)
      transform_many node.rescues

      if node_ensure = node.ensure
        node.ensure = node_ensure.transform(self)
      end

      node
    end

    def transform(node : Rescue)
      node.body = node.body.transform(self)
      transform_many node.types
      node
    end

    def transform(node : Union)
      transform_many node.types
      node
    end

    def transform(node : Hierarchy)
      node.name = node.name.transform(self)
      node
    end

    def transform(node : Metaclass)
      node.name = node.name.transform(self)
      node
    end

    def transform(node : Arg)
      if default_value = node.default_value
        node.default_value = default_value.transform(self)
      end

      if restriction = node.restriction
        node.restriction = restriction.transform(self)
      end

      node
    end

    def transform(node : BlockArg)
      node.fun = node.fun.transform(self)
      node
    end

    def transform(node : Fun)
      transform_many node.inputs

      if output = node.output
        node.output = output.transform(self)
      end

      node
    end

    def transform(node : Block)
      node.args.map! { |exp| exp.transform(self) as Var }
      node.body = node.body.transform(self)
      node
    end

    def transform(node : FunLiteral)
      node.def.body = node.def.body.transform(self)
      node
    end

    def transform(node : FunPointer)
      if obj = node.obj
        node.obj = obj.transform(self)
      end
      node
    end

    def transform(node : Return)
      transform_many node.exps
      node
    end

    def transform(node : Break)
      transform_many node.exps
      node
    end

    def transform(node : Next)
      transform_many node.exps
      node
    end

    def transform(node : Yield)
      if scope = node.scope
        node.scope = scope.transform(self)
      end
      transform_many node.exps
      node
    end

    def transform(node : Include)
      node.name = node.name.transform(self)
      node
    end

    def transform(node : Extend)
      node.name = node.name.transform(self)
      node
    end

    def transform(node : RangeLiteral)
      node.from = node.from.transform(self)
      node.to = node.to.transform(self)
      node
    end

    def transform(node : Assign)
      node.target = node.target.transform(self)
      node.value = node.value.transform(self)
      node
    end

    def transform(node : Nop)
      node
    end

    def transform(node : NilLiteral)
      node
    end

    def transform(node : BoolLiteral)
      node
    end

    def transform(node : NumberLiteral)
      node
    end

    def transform(node : CharLiteral)
      node
    end

    def transform(node : StringLiteral)
      node
    end

    def transform(node : SymbolLiteral)
      node
    end

    def transform(node : RegexLiteral)
      node
    end

    def transform(node : Var)
      node
    end

    def transform(node : MetaVar)
      node
    end

    def transform(node : InstanceVar)
      node
    end

    def transform(node : ClassVar)
      node
    end

    def transform(node : Global)
      node
    end

    def transform(node : Require)
      node
    end

    def transform(node : Path)
      node
    end

    def transform(node : Self)
      node
    end

    def transform(node : LibDef)
      node.body = node.body.transform(self)
      node
    end

    def transform(node : FunDef)
      if body = node.body
        node.body = body.transform(self)
      end
      node
    end

    def transform(node : TypeDef)
      node
    end

    def transform(node : StructDef)
      node
    end

    def transform(node : UnionDef)
      node
    end

    def transform(node : EnumDef)
      node
    end

    def transform(node : ExternalVar)
      node
    end

    def transform(node : IndirectRead)
      node.obj = node.obj.transform(self)
      node
    end

    def transform(node : IndirectWrite)
      node.obj = node.obj.transform(self)
      node.value = node.value.transform(self)
      node
    end

    def transform(node : TypeOf)
      transform_many node.expressions
      node
    end

    def transform(node : Primitive)
      node
    end

    def transform(node : Not)
      node
    end

    def transform(node : TypeFilteredNode)
      node
    end

    def transform(node : TupleLiteral)
      transform_many node.exps
      node
    end

    def transform(node : Cast)
      node.obj = node.obj.transform(self)
      node.to = node.to.transform(self)
      node
    end

    def transform(node : DeclareVar)
      node.var = node.var.transform(self)
      node.declared_type = node.declared_type.transform(self)
      node
    end

    def transform(node : Alias)
      node.value = node.value.transform(self)
      node
    end

    def transform(node : TupleIndexer)
      node
    end

    def transform(node : Attribute)
      node
    end

    def transform_many(exps)
      exps.map! { |exp| exp.transform(self) } if exps
    end
  end
end
