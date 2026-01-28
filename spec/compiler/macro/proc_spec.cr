require "../../spec_helper"

private def proc_literal(body = nil, args = [] of Arg, return_type : ASTNode? = nil)
  ProcLiteral.new(Def.new("->", body: body, args: args, return_type: return_type))
end

module Crystal
  describe ProcLiteral do
    describe "#call" do
      it "works" do
        # -> { 1 }
        assert_macro %({{ f.call }}), %(1), {f: proc_literal(1.int32)}

        # ->(x, y) { x + y }
        assert_macro %({{ f.call(2, 3) }}), %(5), {f: proc_literal(Call.new("x".var, "+", "y".var), ["x".arg, "y".arg])}
      end

      it "raises on argument count mismatch" do
        assert_macro_error %({{ f.call(1) }}), "wrong number of arguments for macro 'ProcLiteral#call' (given 1, expected 0)", {f: proc_literal()}
        assert_macro_error %({{ f.call }}), "wrong number of arguments for macro 'ProcLiteral#call' (given 0, expected 1)", {f: proc_literal(args: ["x".arg])}
      end

      it "raises if block is supplied" do
        assert_macro_error %({{ f.call { } }}), "macro 'ProcLiteral#call' is not expected to be invoked with a block, but a block was given", {f: proc_literal()}
      end

      it "raises if named arguments are supplied" do
        assert_macro_error %({{ f.call(x: 1) }}), "named arguments are not allowed here", {f: proc_literal()}
      end

      it "works if body has multi-assign and array setter" do
        assert_type(<<-CRYSTAL) { string }
          Foo = -> do
            arr = [1]
            arr[0], _ = "", 'a'
            arr[0]
          end

          {{ (Foo.call; Foo.call) }}
          CRYSTAL
      end

      describe "type checking" do
        it "supports parameter type restrictions and return types" do
          # ->(x : ArrayLiteral, y : NumberLiteral) : StringLiteral { x[y] }
          assert_macro %({{ f.call(%w(abc def ghi jkl), 2) }}), %("ghi"), {f: proc_literal(
            Call.new("x".var, "[]", "y".var),
            ["x".arg(restriction: "ArrayLiteral".path), "y".arg(restriction: "NumberLiteral".path)],
            "StringLiteral".path,
          )}
        end

        it "raises on parameter type mismatch" do
          assert_macro_error %({{ f.call(1) }}), %(expected argument #1 to 'ProcLiteral#call' to be ArrayLiteral, not NumberLiteral),
            {f: proc_literal(args: ["x".arg(restriction: "ArrayLiteral".path)])}

          assert_macro_error %({{ f.call(1, 2, Int32) }}), %(expected argument #3 to 'ProcLiteral#call' to be NilLiteral, not TypeNode),
            {f: proc_literal(args: ["x".arg, "y".arg, "z".arg(restriction: "NilLiteral".path)])}
        end

        it "raises on return type mismatch" do
          assert_macro_error %({{ f.call }}), %(expected ProcLiteral to return ArrayLiteral, not NumberLiteral:\n\n1),
            {f: proc_literal(1.int32, return_type: "ArrayLiteral".path)}
        end

        it "returns a NilLiteral without type checking if return type is NilLiteral" do
          # -> : NilLiteral { 1 }
          assert_macro %({{ f.call }}), %(nil), {f: proc_literal(1.int32, return_type: "NilLiteral".path)}
        end

        it "returns a Nop without type checking if return type is Nop" do
          # -> : Nop { 1 }
          assert_macro %({{ f.call }}), %(), {f: proc_literal(1.int32, return_type: "Nop".path)}
        end
      end

      describe "variable scope" do
        it "creates an isolated scope" do
          # -> { x = 2 }
          assert_macro %({{ (x = 1; f.call; x) }}), %(1), {f: proc_literal(Assign.new("x".var, 2.int32))}
        end

        it "errors if variable is from caller's scope" do
          assert_macro_error %({{ (x = 1; f.call) }}), %(undefined macro variable 'x'), {f: proc_literal("x".var)}
        end

        it "errors if variable inside proc is undefined in caller's scope" do
          assert_macro_error %({{ (f.call; x) }}), %(undefined macro variable 'x'), {f: proc_literal(Assign.new("x".var, 2.int32))}
        end
      end
    end
  end
end
