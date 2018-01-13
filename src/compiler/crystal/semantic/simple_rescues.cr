require "set"
require "../program"
require "../syntax/transformer"

module Crystal
  class SimpleRescues < Transformer
    @i = 0

    def transform(node : ExceptionHandler)
      ensure_body = node.ensure
      rescues = node.rescues

      if ensure_body
        # if there is an ensure wrap it in another begin/rescue
        # add the original ensure at the end of the outer rescue and
        # also following the outer rescue
        node.ensure = nil
        var_name = next_var

        ensure_body = ensure_body.transform(self)

        body = if rescues || node.else
                 node
               else
                 node.body
               end
        new_handler = ExceptionHandler.new(
          body.transform(self),
          [Rescue.new(Expressions.from([
            ensure_body,
            Call.global("raise", Var.new(var_name)),
          ] of ASTNode), nil, var_name)])
        tap_block = Block.new(@args = [] of Var, ensure_body.clone)
        return Expressions.from [Call.new(new_handler, "tap", [] of ASTNode, tap_block)] of ASTNode
      end

      if rescues
        if rescues.size > 1
          var_name = next_var
          rescue_body = Call.global("raise", Var.new(var_name))

          rescues.reverse_each do |rescue_node|
            typed_var_name, restriction_type, body = split_rescue rescue_node

            if restriction_type
              rescue_body = type_restricted_rescue_body(var_name,
                typed_var_name, restriction_type, body, rescue_body)
            else
              rescue_body = Expressions.from [
                Assign.new(Var.new(typed_var_name), Var.new(var_name)),
                body,
              ] of ASTNode
            end
          end
        else
          typed_var_name, restriction_type, body = split_rescue rescues.first
          var_name = typed_var_name
          if restriction_type
            rescue_body = If.new(
              IsA.new(Var.new(typed_var_name), restriction_type),
              body, Call.global("raise", Var.new(var_name)))
          else
            rescue_body = body
          end
        end

        node.body = node.body.transform(self)
        node.rescues = [Rescue.new(rescue_body.transform(self), nil, var_name)]
      end

      node
    end

    private def split_rescue(node : Rescue)
      types = node.types

      if types
        restriction_type = types.size == 1 ? types[0] : Union.new(types)
      else
        restriction_type = nil
      end

      {node.name || next_var, restriction_type, node.body}
    end

    private def type_restricted_rescue_body(var_name : String,
                                            typed_var_name : String, restriction_type : ASTNode,
                                            body : ASTNode, cont : ASTNode)
      If.new(
        And.new(Assign.new(Var.new(typed_var_name), Var.new(var_name)),
          IsA.new(Var.new(typed_var_name), restriction_type)),
        body, cont)
    end

    private def next_var
      @i += 1
      "___e#{@i}"
    end
  end
end
