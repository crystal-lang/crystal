require "../../spec_helper"

private def declare_class_var(container : ClassVarContainer, name, var_type : Type, annotations = nil)
  var = MetaTypeVar.new(name)
  var.owner = container
  var.type = var_type
  var.annotations = annotations
  var.bind_to var
  var.freeze_type = var_type
  container.class_vars[name] = var
end

module Crystal
  describe "macro methods" do
    describe "node methods" do
      describe "location" do
        location = Location.new("foo.cr", 1, 2)

        it "filename" do
          assert_macro "x", "{{x.filename}}", ["hello".string.tap { |n| n.location = location }] of ASTNode, %("foo.cr")
        end

        it "line_number" do
          assert_macro "x", "{{x.line_number}}", ["hello".string.tap { |n| n.location = location }] of ASTNode, %(1)
        end

        it "column number" do
          assert_macro "x", "{{x.column_number}}", ["hello".string.tap { |n| n.location = location }] of ASTNode, %(2)
        end

        it "end line_number" do
          assert_macro "x", "{{x.end_line_number}}", ["hello".string.tap { |n| n.end_location = location }] of ASTNode, %(1)
        end

        it "end column number" do
          assert_macro "x", "{{x.end_column_number}}", ["hello".string.tap { |n| n.end_location = location }] of ASTNode, %(2)
        end
      end

      describe "stringify" do
        it "expands macro with stringify call on string" do
          assert_macro "x", "{{x.stringify}}", ["hello".string] of ASTNode, "\"\\\"hello\\\"\""
        end

        it "expands macro with stringify call on symbol" do
          assert_macro "x", "{{x.stringify}}", ["hello".symbol] of ASTNode, %(":hello")
        end

        it "expands macro with stringify call on call" do
          assert_macro "x", "{{x.stringify}}", ["hello".call] of ASTNode, %("hello")
        end

        it "expands macro with stringify call on number" do
          assert_macro "x", "{{x.stringify}}", [1.int32] of ASTNode, %("1")
        end
      end

      describe "symbolize" do
        it "expands macro with symbolize call on string" do
          assert_macro "x", "{{x.symbolize}}", ["hello".string] of ASTNode, ":\"\\\"hello\\\"\""
        end

        it "expands macro with symbolize call on symbol" do
          assert_macro "x", "{{x.symbolize}}", ["hello".symbol] of ASTNode, ":\":hello\""
        end

        it "expands macro with symbolize call on id" do
          assert_macro "x", "{{x.id.symbolize}}", ["hello".string] of ASTNode, ":hello"
        end
      end

      describe "id" do
        it "expands macro with id call on string" do
          assert_macro "x", "{{x.id}}", ["hello".string] of ASTNode, "hello"
        end

        it "expands macro with id call on symbol" do
          assert_macro "x", "{{x.id}}", ["hello".symbol] of ASTNode, "hello"
        end

        it "expands macro with id call on char" do
          assert_macro "x", "{{x.id}}", [CharLiteral.new('є')] of ASTNode, "є"
        end

        it "expands macro with id call on call" do
          assert_macro "x", "{{x.id}}", ["hello".call] of ASTNode, "hello"
        end

        it "expands macro with id call on number" do
          assert_macro "x", "{{x.id}}", [1.int32] of ASTNode, %(1)
        end
      end

      it "executes == on numbers (true)" do
        assert_macro "", "{%if 1 == 1%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
      end

      it "executes == on numbers (false)" do
        assert_macro "", "{%if 1 == 2%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
      end

      it "executes != on numbers (true)" do
        assert_macro "", "{%if 1 != 2%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
      end

      it "executes != on numbers (false)" do
        assert_macro "", "{%if 1 != 1%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
      end

      it "executes == on symbols (true) (#240)" do
        assert_macro "", "{{:foo == :foo}}", [] of ASTNode, "true"
      end

      it "executes == on symbols (false) (#240)" do
        assert_macro "", "{{:foo == :bar}}", [] of ASTNode, "false"
      end

      describe "class_name" do
        it "executes class_name" do
          assert_macro "", "{{:foo.class_name}}", [] of ASTNode, "\"SymbolLiteral\""
        end

        it "executes class_name" do
          assert_macro "x", "{{x.class_name}}", [MacroId.new("hello")] of ASTNode, "\"MacroId\""
        end

        it "executes class_name" do
          assert_macro "x", "{{x.class_name}}", ["hello".string] of ASTNode, "\"StringLiteral\""
        end

        it "executes class_name" do
          assert_macro "x", "{{x.class_name}}", ["hello".symbol] of ASTNode, "\"SymbolLiteral\""
        end

        it "executes class_name" do
          assert_macro "x", "{{x.class_name}}", [1.int32] of ASTNode, "\"NumberLiteral\""
        end

        it "executes class_name" do
          assert_macro "x", "{{x.class_name}}", [ArrayLiteral.new([Path.new("Foo"), Path.new("Bar")] of ASTNode)] of ASTNode, "\"ArrayLiteral\""
        end
      end
    end

    describe "number methods" do
      it "executes > (true)" do
        assert_macro "", "{%if 2 > 1%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
      end

      it "executes > (false)" do
        assert_macro "", "{%if 2 > 3%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
      end

      it "executes >= (true)" do
        assert_macro "", "{%if 1 >= 1%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
      end

      it "executes >= (false)" do
        assert_macro "", "{%if 2 >= 3%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
      end

      it "executes < (true)" do
        assert_macro "", "{%if 1 < 2%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
      end

      it "executes < (false)" do
        assert_macro "", "{%if 3 < 2%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
      end

      it "executes <= (true)" do
        assert_macro "", "{%if 1 <= 1%}hello{%else%}bye{%end%}", [] of ASTNode, "hello"
      end

      it "executes <= (false)" do
        assert_macro "", "{%if 3 <= 2%}hello{%else%}bye{%end%}", [] of ASTNode, "bye"
      end

      it "executes <=>" do
        assert_macro "", "{{1 <=> -1}}", [] of ASTNode, "1"
      end

      it "executes <=> (returns nil)" do
        assert_macro "", "{{0.0/0.0 <=> -1}}", [] of ASTNode, "nil"
      end

      it "executes +" do
        assert_macro "", "{{1 + 2}}", [] of ASTNode, "3"
      end

      it "executes + and preserves type" do
        assert_macro "", "{{1_u64 + 2_u64}}", [] of ASTNode, "3_u64"
      end

      it "executes -" do
        assert_macro "", "{{1 - 2}}", [] of ASTNode, "-1"
      end

      it "executes *" do
        assert_macro "", "{{2 * 3}}", [] of ASTNode, "6"
      end

      # MathInterpreter only works with Integer and left / right : Float
      #
      # it "executes /" do
      #   assert_macro "", "{{5 / 3}}", [] of ASTNode, "1"
      # end

      it "executes //" do
        assert_macro "", "{{5 // 3}}", [] of ASTNode, "1"
      end

      it "executes %" do
        assert_macro "", "{{5 % 3}}", [] of ASTNode, "2"
      end

      it "executes &" do
        assert_macro "", "{{5 & 3}}", [] of ASTNode, "1"
      end

      it "executes |" do
        assert_macro "", "{{5 | 3}}", [] of ASTNode, "7"
      end

      it "executes ^" do
        assert_macro "", "{{5 ^ 3}}", [] of ASTNode, "6"
      end

      it "executes **" do
        assert_macro "", "{{2 ** 3}}", [] of ASTNode, "8"
      end

      it "executes <<" do
        assert_macro "", "{{1 << 2}}", [] of ASTNode, "4"
      end

      it "executes >>" do
        assert_macro "", "{{4 >> 2}}", [] of ASTNode, "1"
      end

      it "executes + with float" do
        assert_macro "", "{{1.5 + 2.6}}", [] of ASTNode, "4.1"
      end

      it "executes unary +" do
        assert_macro "", "{{+3}}", [] of ASTNode, "+3"
      end

      it "executes unary -" do
        assert_macro "", "{{-(3)}}", [] of ASTNode, "-3"
      end

      it "executes unary ~" do
        assert_macro "", "{{~1}}", [] of ASTNode, "-2"
      end

      it "exetutes kind" do
        assert_macro "", "{{-128i8.kind}}", [] of ASTNode, ":i8"
        assert_macro "", "{{1e-123_f32.kind}}", [] of ASTNode, ":f32"
        assert_macro "", "{{1.0.kind}}", [] of ASTNode, ":f64"
        assert_macro "", "{{0xde7ec7ab1e_u64.kind}}", [] of ASTNode, ":u64"
      end
    end

    describe "string methods" do
      it "executes string == string" do
        assert_macro "", %({{"foo" == "foo"}}), [] of ASTNode, %(true)
        assert_macro "", %({{"foo" == "bar"}}), [] of ASTNode, %(false)
      end

      it "executes string != string" do
        assert_macro "", %({{"foo" != "foo"}}), [] of ASTNode, %(false)
        assert_macro "", %({{"foo" != "bar"}}), [] of ASTNode, %(true)
      end

      it "executes split without arguments" do
        assert_macro "", %({{"1 2 3".split}}), [] of ASTNode, %(["1", "2", "3"] of ::String)
      end

      it "executes split with argument" do
        assert_macro "", %({{"1-2-3".split('-')}}), [] of ASTNode, %(["1", "2", "3"] of ::String)
      end

      it "executes split with char argument" do
        assert_macro "", %({{"1-2-3".split('-')}}), [] of ASTNode, %(["1", "2", "3"] of ::String)
      end

      it "executes strip" do
        assert_macro "", %({{"  hello   ".strip}}), [] of ASTNode, %("hello")
      end

      it "executes downcase" do
        assert_macro "", %({{"HELLO".downcase}}), [] of ASTNode, %("hello")
      end

      it "executes upcase" do
        assert_macro "", %({{"hello".upcase}}), [] of ASTNode, %("HELLO")
      end

      it "executes capitalize" do
        assert_macro "", %({{"hello".capitalize}}), [] of ASTNode, %("Hello")
      end

      it "executes chars" do
        assert_macro "x", %({{x.chars}}), [StringLiteral.new("123")] of ASTNode, %(['1', '2', '3'] of ::Char)
      end

      it "executes lines" do
        assert_macro "x", %({{x.lines}}), [StringLiteral.new("1\n2\n3")] of ASTNode, %(["1", "2", "3"] of ::String)
      end

      it "executes size" do
        assert_macro "", %({{"hello".size}}), [] of ASTNode, "5"
      end

      it "executes count" do
        assert_macro "", %({{"aabbcc".count('a')}}), [] of ASTNode, "2"
      end

      it "executes empty" do
        assert_macro "", %({{"hello".empty?}}), [] of ASTNode, "false"
      end

      it "executes string [Range] inclusive" do
        assert_macro "", %({{"hello"[1..-2]}}), [] of ASTNode, %("ell")
      end

      it "executes string [Range] exclusive" do
        assert_macro "", %({{"hello"[1...-2]}}), [] of ASTNode, %("el")
      end

      it "executes string [Range] inclusive (computed)" do
        assert_macro "", %({{"hello"[[1].size..-2]}}), [] of ASTNode, %("ell")
      end

      it "executes string chomp" do
        assert_macro "", %({{"hello\n".chomp}}), [] of ASTNode, %("hello")
      end

      it "executes string starts_with? char (true)" do
        assert_macro "", %({{"hello".starts_with?('h')}}), [] of ASTNode, %(true)
      end

      it "executes string starts_with? char (false)" do
        assert_macro "", %({{"hello".starts_with?('e')}}), [] of ASTNode, %(false)
      end

      it "executes string starts_with? string (true)" do
        assert_macro "", %({{"hello".starts_with?("hel")}}), [] of ASTNode, %(true)
      end

      it "executes string starts_with? string (false)" do
        assert_macro "", %({{"hello".starts_with?("hi")}}), [] of ASTNode, %(false)
      end

      it "executes string ends_with? char (true)" do
        assert_macro "", %({{"hello".ends_with?('o')}}), [] of ASTNode, %(true)
      end

      it "executes string ends_with? char (false)" do
        assert_macro "", %({{"hello".ends_with?('e')}}), [] of ASTNode, %(false)
      end

      it "executes string ends_with? string (true)" do
        assert_macro "", %({{"hello".ends_with?("llo")}}), [] of ASTNode, %(true)
      end

      it "executes string ends_with? string (false)" do
        assert_macro "", %({{"hello".ends_with?("tro")}}), [] of ASTNode, %(false)
      end

      it "executes string + string" do
        assert_macro "", %({{"hello" + " world"}}), [] of ASTNode, %("hello world")
      end

      it "executes string + char" do
        assert_macro "", %({{"hello" + 'w'}}), [] of ASTNode, %("hellow")
      end

      it "executes string =~ (false)" do
        assert_macro "", %({{"hello" =~ /hei/}}), [] of ASTNode, %(false)
      end

      it "executes string =~ (true)" do
        assert_macro "", %({{"hello" =~ /ell/}}), [] of ASTNode, %(true)
      end

      it "executes string > string" do
        assert_macro "", %({{"fooa" > "foo"}}), [] of ASTNode, %(true)
        assert_macro "", %({{"foo" > "fooa"}}), [] of ASTNode, %(false)
      end

      it "executes string > macroid" do
        assert_macro "", %({{"fooa" > "foo".id}}), [] of ASTNode, %(true)
        assert_macro "", %({{"foo" > "fooa".id}}), [] of ASTNode, %(false)
      end

      it "executes string < string" do
        assert_macro "", %({{"fooa" < "foo"}}), [] of ASTNode, %(false)
        assert_macro "", %({{"foo" < "fooa"}}), [] of ASTNode, %(true)
      end

      it "executes string < macroid" do
        assert_macro "", %({{"fooa" < "foo".id}}), [] of ASTNode, %(false)
        assert_macro "", %({{"foo" < "fooa".id}}), [] of ASTNode, %(true)
      end

      it "executes tr" do
        assert_macro "", %({{"hello".tr("e", "o")}}), [] of ASTNode, %("hollo")
      end

      it "executes gsub" do
        assert_macro "", %({{"hello".gsub(/e|o/, "a")}}), [] of ASTNode, %("halla")
      end

      it "executes camelcase" do
        assert_macro "", %({{"foo_bar".camelcase}}), [] of ASTNode, %("FooBar")
      end

      it "executes camelcase with lower" do
        assert_macro "", %({{"foo_bar".camelcase(lower: true)}}), [] of ASTNode, %("fooBar")
      end

      it "executes camelcase with invalid lower arg type" do
        expect_raises(Crystal::TypeException, "named argument 'lower' to StringLiteral#camelcase must be a bool, not NumberLiteral") do
          assert_macro "", %({{"foo_bar".camelcase(lower: 99)}}), [] of ASTNode, ""
        end
      end

      it "executes underscore" do
        assert_macro "", %({{"FooBar".underscore}}), [] of ASTNode, %("foo_bar")
      end

      it "executes to_i" do
        assert_macro "", %({{"1234".to_i}}), [] of ASTNode, %(1234)
      end

      it "executes to_i(base)" do
        assert_macro "", %({{"1234".to_i(16)}}), [] of ASTNode, %(4660)
      end

      it "executes string includes? char (true)" do
        assert_macro "", %({{"spice".includes?('s')}}), [] of ASTNode, %(true)
        assert_macro "", %({{"spice".includes?('p')}}), [] of ASTNode, %(true)
        assert_macro "", %({{"spice".includes?('i')}}), [] of ASTNode, %(true)
        assert_macro "", %({{"spice".includes?('c')}}), [] of ASTNode, %(true)
        assert_macro "", %({{"spice".includes?('e')}}), [] of ASTNode, %(true)
      end

      it "executes string includes? char (false)" do
        assert_macro "", %({{"spice".includes?('S')}}), [] of ASTNode, %(false)
        assert_macro "", %({{"spice".includes?(' ')}}), [] of ASTNode, %(false)
        assert_macro "", %({{"spice".includes?('!')}}), [] of ASTNode, %(false)
        assert_macro "", %({{"spice".includes?('b')}}), [] of ASTNode, %(false)
      end

      it "executes string includes? string (true)" do
        assert_macro "", %({{"spice".includes?("s")}}), [] of ASTNode, %(true)
        assert_macro "", %({{"spice".includes?("e")}}), [] of ASTNode, %(true)
        assert_macro "", %({{"spice".includes?("sp")}}), [] of ASTNode, %(true)
        assert_macro "", %({{"spice".includes?("ce")}}), [] of ASTNode, %(true)
        assert_macro "", %({{"spice".includes?("pic")}}), [] of ASTNode, %(true)
      end

      it "executes string includes? string (false)" do
        assert_macro "", %({{"spice".includes?("Spi")}}), [] of ASTNode, %(false)
        assert_macro "", %({{"spice".includes?(" spi")}}), [] of ASTNode, %(false)
        assert_macro "", %({{"spice".includes?("ce ")}}), [] of ASTNode, %(false)
        assert_macro "", %({{"spice".includes?("b")}}), [] of ASTNode, %(false)
        assert_macro "", %({{"spice".includes?("spice ")}}), [] of ASTNode, %(false)
      end
    end

    describe "macro id methods" do
      it "forwards methods to string" do
        assert_macro "x", %({{x.ends_with?("llo")}}), [MacroId.new("hello")] of ASTNode, %(true)
        assert_macro "x", %({{x.ends_with?("tro")}}), [MacroId.new("hello")] of ASTNode, %(false)
        assert_macro "x", %({{x.starts_with?("hel")}}), [MacroId.new("hello")] of ASTNode, %(true)
        assert_macro "x", %({{x.chomp}}), [MacroId.new("hello\n")] of ASTNode, %(hello)
        assert_macro "x", %({{x.upcase}}), [MacroId.new("hello")] of ASTNode, %(HELLO)
        assert_macro "x", %({{x.includes?("el")}}), [MacroId.new("hello")] of ASTNode, %(true)
        assert_macro "x", %({{x.includes?("he")}}), [MacroId.new("hello")] of ASTNode, %(true)
        assert_macro "x", %({{x.includes?("EL")}}), [MacroId.new("hello")] of ASTNode, %(false)
        assert_macro "x", %({{x.includes?("cat")}}), [MacroId.new("hello")] of ASTNode, %(false)
      end

      it "compares with string" do
        assert_macro "x", %({{x == "foo"}}), [MacroId.new("foo")] of ASTNode, %(true)
        assert_macro "x", %({{"foo" == x}}), [MacroId.new("foo")] of ASTNode, %(true)

        assert_macro "x", %({{x == "bar"}}), [MacroId.new("foo")] of ASTNode, %(false)
        assert_macro "x", %({{"bar" == x}}), [MacroId.new("foo")] of ASTNode, %(false)

        assert_macro "x", %({{x != "foo"}}), [MacroId.new("foo")] of ASTNode, %(false)
        assert_macro "x", %({{"foo" != x}}), [MacroId.new("foo")] of ASTNode, %(false)

        assert_macro "x", %({{x != "bar"}}), [MacroId.new("foo")] of ASTNode, %(true)
        assert_macro "x", %({{"bar" != x}}), [MacroId.new("foo")] of ASTNode, %(true)
      end

      it "compares with symbol" do
        assert_macro "x", %({{x == :foo}}), [MacroId.new("foo")] of ASTNode, %(true)
        assert_macro "x", %({{:foo == x}}), [MacroId.new("foo")] of ASTNode, %(true)

        assert_macro "x", %({{x == :bar}}), [MacroId.new("foo")] of ASTNode, %(false)
        assert_macro "x", %({{:bar == x}}), [MacroId.new("foo")] of ASTNode, %(false)

        assert_macro "x", %({{x != :foo}}), [MacroId.new("foo")] of ASTNode, %(false)
        assert_macro "x", %({{:foo != x}}), [MacroId.new("foo")] of ASTNode, %(false)

        assert_macro "x", %({{x != :bar}}), [MacroId.new("foo")] of ASTNode, %(true)
        assert_macro "x", %({{:bar != x}}), [MacroId.new("foo")] of ASTNode, %(true)
      end
    end

    describe "symbol methods" do
      it "forwards methods to string" do
        assert_macro "x", %({{x.ends_with?("llo")}}), ["hello".symbol] of ASTNode, %(true)
        assert_macro "x", %({{x.ends_with?("tro")}}), ["hello".symbol] of ASTNode, %(false)
        assert_macro "x", %({{x.starts_with?("hel")}}), ["hello".symbol] of ASTNode, %(true)
        assert_macro "x", %({{x.chomp}}), [SymbolLiteral.new("hello\n")] of ASTNode, %(:hello)
        assert_macro "x", %({{x.upcase}}), ["hello".symbol] of ASTNode, %(:HELLO)
        assert_macro "x", %({{x.includes?("el")}}), ["hello".symbol] of ASTNode, %(true)
        assert_macro "x", %({{x.includes?("he")}}), ["hello".symbol] of ASTNode, %(true)
        assert_macro "x", %({{x.includes?("EL")}}), ["hello".symbol] of ASTNode, %(false)
        assert_macro "x", %({{x.includes?("cat")}}), ["hello".symbol] of ASTNode, %(false)
      end

      it "executes symbol == symbol" do
        assert_macro "", %({{:foo == :foo}}), [] of ASTNode, %(true)
        assert_macro "", %({{:foo == :bar}}), [] of ASTNode, %(false)
      end

      it "executes symbol != symbol" do
        assert_macro "", %({{:foo != :foo}}), [] of ASTNode, %(false)
        assert_macro "", %({{:foo != :bar}}), [] of ASTNode, %(true)
      end
    end

    describe "and methods" do
      it "executes left" do
        assert_macro "x", %({{x.left}}), [And.new(1.int32, 2.int32)] of ASTNode, %(1)
      end

      it "executes right" do
        assert_macro "x", %({{x.right}}), [And.new(1.int32, 2.int32)] of ASTNode, %(2)
      end
    end

    describe "or methods" do
      it "executes left" do
        assert_macro "x", %({{x.left}}), [Or.new(1.int32, 2.int32)] of ASTNode, %(1)
      end

      it "executes right" do
        assert_macro "x", %({{x.right}}), [Or.new(1.int32, 2.int32)] of ASTNode, %(2)
      end
    end

    describe "array methods" do
      it "executes index 0" do
        assert_macro "", %({{[1, 2, 3][0]}}), [] of ASTNode, "1"
      end

      it "executes index 1" do
        assert_macro "", %({{[1, 2, 3][1]}}), [] of ASTNode, "2"
      end

      it "executes index out of bounds" do
        assert_macro "", %({{[1, 2, 3][3]}}), [] of ASTNode, "nil"
      end

      it "executes size" do
        assert_macro "", %({{[1, 2, 3].size}}), [] of ASTNode, "3"
      end

      it "executes empty?" do
        assert_macro "", %({{[1, 2, 3].empty?}}), [] of ASTNode, "false"
      end

      it "executes identify" do
        assert_macro "", %({{"A::B".identify}}), [] of ASTNode, "\"A__B\""
        assert_macro "", %({{"A".identify}}), [] of ASTNode, "\"A\""
      end

      it "executes join" do
        assert_macro "", %({{[1, 2, 3].join ", "}}), [] of ASTNode, %("1, 2, 3")
      end

      it "executes join with strings" do
        assert_macro "", %({{["a", "b"].join ", "}}), [] of ASTNode, %("a, b")
      end

      it "executes map" do
        assert_macro "", %({{[1, 2, 3].map { |e| e == 2 }}}), [] of ASTNode, "[false, true, false]"
      end

      it "executes reduce with no initial value" do
        assert_macro "", %({{[1, 2, 3].reduce { |acc, val| acc * val }}}), [] of ASTNode, "6"
      end

      it "executes reduce with initial value" do
        assert_macro "", %({{[1, 2, 3].reduce(4) { |acc, val| acc * val }}}), [] of ASTNode, "24"
        assert_macro "", %({{[1, 2, 3].reduce([] of NumberLiteral) { |acc, val| acc = [val]+acc }}}), [] of ASTNode, "[3, 2, 1]"
      end

      it "executes map with constants" do
        assert_macro "x", %({{x.map { |e| e.id }}}), [ArrayLiteral.new([Path.new("Foo"), Path.new("Bar")] of ASTNode)] of ASTNode, "[Foo, Bar]"
      end

      it "executes map with arg" do
        assert_macro "x", %({{x.map { |e| e.id }}}), [ArrayLiteral.new(["hello".call] of ASTNode)] of ASTNode, "[hello]"
      end

      describe "#map_with_index" do
        context "with both arguments" do
          it "returns the resulting array" do
            assert_macro "", %({{[1, 2, 3].map_with_index { |e, idx| e == 2 || idx <= 1 }}}), [] of ASTNode, %([true, true, false])
          end
        end

        context "without the index argument" do
          it "returns the resulting array" do
            assert_macro "", %({{[1, 2, 3].map_with_index { |e| e }}}), [] of ASTNode, %([1, 2, 3])
          end
        end

        context "without the element argument" do
          it "returns the resulting array" do
            assert_macro "", %({{[1, 2, 3].map_with_index { |_, idx| idx }}}), [] of ASTNode, %([0, 1, 2])
          end
        end

        context "without either argument" do
          it "returns the resulting array" do
            assert_macro "", %({{[1, 2, 3].map_with_index { 7 }}}), [] of ASTNode, %([7, 7, 7])
          end
        end
      end

      it "executes select" do
        assert_macro "", %({{[1, 2, 3].select { |e| e == 1 }}}), [] of ASTNode, "[1]"
      end

      it "executes reject" do
        assert_macro "", %({{[1, 2, 3].reject { |e| e == 1 }}}), [] of ASTNode, "[2, 3]"
      end

      it "executes find (finds)" do
        assert_macro "", %({{[1, 2, 3].find { |e| e == 2 }}}), [] of ASTNode, "2"
      end

      it "executes find (doesn't find)" do
        assert_macro "", %({{[1, 2, 3].find { |e| e == 4 }}}), [] of ASTNode, "nil"
      end

      it "executes any? (true)" do
        assert_macro "", %({{[1, 2, 3].any? { |e| e == 1 }}}), [] of ASTNode, "true"
      end

      it "executes any? (false)" do
        assert_macro "", %({{[1, 2, 3].any? { |e| e == 4 }}}), [] of ASTNode, "false"
      end

      it "executes all? (true)" do
        assert_macro "", %({{[1, 1, 1].all? { |e| e == 1 }}}), [] of ASTNode, "true"
      end

      it "executes all? (false)" do
        assert_macro "", %({{[1, 2, 1].all? { |e| e == 1 }}}), [] of ASTNode, "false"
      end

      it "executes first" do
        assert_macro "", %({{[1, 2, 3].first}}), [] of ASTNode, "1"
      end

      it "executes last" do
        assert_macro "", %({{[1, 2, 3].last}}), [] of ASTNode, "3"
      end

      it "executes splat" do
        assert_macro "", %({{[1, 2, 3].splat}}), [] of ASTNode, "1, 2, 3"
      end

      it "executes splat with symbols and strings" do
        assert_macro "", %({{[:foo, "hello", 3].splat}}), [] of ASTNode, %(:foo, "hello", 3)
      end

      it "executes splat with splat" do
        assert_macro "", %({{*[1, 2, 3]}}), [] of ASTNode, "1, 2, 3"
      end

      it "executes is_a?" do
        assert_macro "", %({{[1, 2, 3].is_a?(ArrayLiteral)}}), [] of ASTNode, "true"
        assert_macro "", %({{[1, 2, 3].is_a?(NumberLiteral)}}), [] of ASTNode, "false"
      end

      it "creates an array literal with a var" do
        assert_macro "x", %({% a = [x] %}{{a[0]}}), [1.int32] of ASTNode, "1"
      end

      it "executes sort with numbers" do
        assert_macro "", %({{[3, 2, 1].sort}}), [] of ASTNode, "[1, 2, 3]"
      end

      it "executes sort with strings" do
        assert_macro "", %({{["c", "b", "a"].sort}}), [] of ASTNode, %(["a", "b", "c"])
      end

      it "executes sort with ids" do
        assert_macro "", %({{["c".id, "b".id, "a".id].sort}}), [] of ASTNode, %([a, b, c])
      end

      it "executes sort with ids and strings" do
        assert_macro "", %({{["c".id, "b", "a".id].sort}}), [] of ASTNode, %([a, "b", c])
      end

      it "executes uniq" do
        assert_macro "", %({{[1, 1, 1, 2, 3, 1, 2, 3, 4].uniq}}), [] of ASTNode, %([1, 2, 3, 4])
      end

      it "executes unshift" do
        assert_macro "", %({% x = [1]; x.unshift(2); %}{{x}}), [] of ASTNode, %([2, 1])
      end

      it "executes push" do
        assert_macro "", %({% x = [1]; x.push(2); x << 3 %}{{x}}), [] of ASTNode, %([1, 2, 3])
      end

      it "executes includes?" do
        assert_macro "", %({{ [1, 2, 3].includes?(1) }}), [] of ASTNode, %(true)
        assert_macro "", %({{ [1, 2, 3].includes?(4) }}), [] of ASTNode, %(false)
      end

      it "executes +" do
        assert_macro "", %({{ [1, 2] + [3, 4, 5] }}), [] of ASTNode, %([1, 2, 3, 4, 5])
      end

      it "executes [] with range" do
        assert_macro "", %({{ [1, 2, 3, 4][1...-1] }}), [] of ASTNode, %([2, 3])
      end

      it "executes [] with computed range" do
        assert_macro "", %({{ [1, 2, 3, 4][[1].size...-1] }}), [] of ASTNode, %([2, 3])
      end

      it "executes [] with two numbers" do
        assert_macro "", %({{ [1, 2, 3, 4, 5][1, 3] }}), [] of ASTNode, %([2, 3, 4])
      end

      it "executes []=" do
        assert_macro "", %({% a = [0]; a[0] = 2 %}{{a[0]}}), [] of ASTNode, "2"
      end

      it "executes of" do
        assert_macro "x", %({{ x.of }}), [ArrayLiteral.new([] of ASTNode, of: Path.new(["Int64"]))] of ASTNode, %(Int64)
      end

      it "executes of (nop)" do
        assert_macro "", %({{ [1, 2, 3].of }}), [] of ASTNode, %()
      end

      it "executes type" do
        assert_macro "x", %({{ x.type }}), [ArrayLiteral.new([] of ASTNode, name: Path.new(["Deque"]))] of ASTNode, %(Deque)
      end

      it "executes type (nop)" do
        assert_macro "", %({{ [1, 2, 3].type }}), [] of ASTNode, %()
      end
    end

    describe "hash methods" do
      it "executes size" do
        assert_macro "", %({{{:a => 1, :b => 3}.size}}), [] of ASTNode, "2"
      end

      it "executes sort_by" do
        assert_macro "", %({{["abc", "a", "ab"].sort_by { |x| x.size }}}), [] of ASTNode, %(["a", "ab", "abc"])
      end

      it "executes empty?" do
        assert_macro "", %({{{:a => 1}.empty?}}), [] of ASTNode, "false"
      end

      it "executes []" do
        assert_macro "", %({{{:a => 1}[:a]}}), [] of ASTNode, "1"
      end

      it "executes [] not found" do
        assert_macro "", %({{{:a => 1}[:b]}}), [] of ASTNode, "nil"
      end

      it "executes keys" do
        assert_macro "", %({{{:a => 1, :b => 2}.keys}}), [] of ASTNode, "[:a, :b]"
      end

      it "executes values" do
        assert_macro "", %({{{:a => 1, :b => 2}.values}}), [] of ASTNode, "[1, 2]"
      end

      it "executes map" do
        assert_macro "", %({{{:a => 1, :b => 2}.map {|k, v| k == :a && v == 1}}}), [] of ASTNode, "[true, false]"
      end

      it "executes is_a?" do
        assert_macro "", %({{{:a => 1}.is_a?(HashLiteral)}}), [] of ASTNode, "true"
        assert_macro "", %({{{:a => 1}.is_a?(RangeLiteral)}}), [] of ASTNode, "false"
      end

      it "executes []=" do
        assert_macro "", %({% a = {} of Nil => Nil; a[1] = 2 %}{{a[1]}}), [] of ASTNode, "2"
      end

      it "creates a hash literal with a var" do
        assert_macro "x", %({% a = {:a => x} %}{{a[:a]}}), [1.int32] of ASTNode, "1"
      end

      it "executes to_a" do
        assert_macro "", %({{{:a => 1, :b => 3}.to_a}}), [] of ASTNode, "[{:a, 1}, {:b, 3}]"
      end

      it "executes of_key" do
        of = HashLiteral::Entry.new(Path.new(["String"]), Path.new(["UInt8"]))
        assert_macro "x", %({{ x.of_key }}), [HashLiteral.new([] of HashLiteral::Entry, of: of)] of ASTNode, %(String)
      end

      it "executes of_key (nop)" do
        assert_macro "", %({{ {'z' => 6, 'a' => 9}.of_key }}), [] of ASTNode, %()
      end

      it "executes of_value" do
        of = HashLiteral::Entry.new(Path.new(["String"]), Path.new(["UInt8"]))
        assert_macro "x", %({{ x.of_value }}), [HashLiteral.new([] of HashLiteral::Entry, of: of)] of ASTNode, %(UInt8)
      end

      it "executes of_value (nop)" do
        assert_macro "", %({{ {'z' => 6, 'a' => 9}.of_value }}), [] of ASTNode, %()
      end

      it "executes type" do
        assert_macro "x", %({{ x.type }}), [HashLiteral.new([] of HashLiteral::Entry, name: Path.new(["Headers"]))] of ASTNode, %(Headers)
      end

      it "executes type (nop)" do
        assert_macro "", %({{ {'z' => 6, 'a' => 9}.type }}), [] of ASTNode, %()
      end

      it "executes double splat" do
        assert_macro "", %({{**{1 => 2, 3 => 4}}}), [] of ASTNode, "1 => 2, 3 => 4"
      end

      it "executes double splat" do
        assert_macro "", %({{{1 => 2, 3 => 4}.double_splat}}), [] of ASTNode, "1 => 2, 3 => 4"
      end

      it "executes double splat with arg" do
        assert_macro "", %({{{1 => 2, 3 => 4}.double_splat(", ")}}), [] of ASTNode, "1 => 2, 3 => 4, "
      end
    end

    describe "named tuple literal methods" do
      it "executes size" do
        assert_macro "", %({{{a: 1, b: 3}.size}}), [] of ASTNode, "2"
      end

      it "executes empty?" do
        assert_macro "", %({{{a: 1}.empty?}}), [] of ASTNode, "false"
      end

      it "executes []" do
        assert_macro "", %({{{a: 1}[:a]}}), [] of ASTNode, "1"
        assert_macro "", %({{{a: 1}["a"]}}), [] of ASTNode, "1"
      end

      it "executes [] not found" do
        assert_macro "", %({{{a: 1}[:b]}}), [] of ASTNode, "nil"
        assert_macro "", %({{{a: 1}["b"]}}), [] of ASTNode, "nil"
      end

      it "executes [] with invalid key type" do
        expect_raises(Crystal::TypeException, "argument to [] must be a symbol or string, not BoolLiteral") do
          assert_macro "", %({{{a: 1}[true]}}), [] of ASTNode, ""
        end
      end

      it "executes keys" do
        assert_macro "", %({{{a: 1, b: 2}.keys}}), [] of ASTNode, "[a, b]"
      end

      it "executes values" do
        assert_macro "", %({{{a: 1, b: 2}.values}}), [] of ASTNode, "[1, 2]"
      end

      it "executes map" do
        assert_macro "", %({{{a: 1, b: 2}.map {|k, v| k.stringify == "a" && v == 1}}}), [] of ASTNode, "[true, false]"
      end

      it "executes is_a?" do
        assert_macro "", %({{{a: 1}.is_a?(NamedTupleLiteral)}}), [] of ASTNode, "true"
        assert_macro "", %({{{a: 1}.is_a?(RangeLiteral)}}), [] of ASTNode, "false"
      end

      it "executes []=" do
        assert_macro "", %({% a = {a: 1}; a[:a] = 2 %}{{a[:a]}}), [] of ASTNode, "2"
        assert_macro "", %({% a = {a: 1}; a["a"] = 2 %}{{a["a"]}}), [] of ASTNode, "2"
      end

      it "creates a named tuple literal with a var" do
        assert_macro "x", %({% a = {a: x} %}{{a[:a]}}), [1.int32] of ASTNode, "1"
      end

      it "executes to_a" do
        assert_macro "", %({{{a: 1, b: 3}.to_a}}), [] of ASTNode, "[{a, 1}, {b, 3}]"
      end

      it "executes double splat" do
        assert_macro "", %({{**{a: 1, "foo bar": 2}}}), [] of ASTNode, %(a: 1, "foo bar": 2)
      end

      it "executes double splat" do
        assert_macro "", %({{{a: 1, "foo bar": 2}.double_splat}}), [] of ASTNode, %(a: 1, "foo bar": 2)
      end

      it "executes double splat with arg" do
        assert_macro "", %({{{a: 1, "foo bar": 2}.double_splat(", ")}}), [] of ASTNode, %(a: 1, "foo bar": 2, )
      end
    end

    describe "tuple methods" do
      it "executes index 0" do
        assert_macro "", %({{ {1, 2, 3}[0] }}), [] of ASTNode, "1"
      end

      it "executes index 1" do
        assert_macro "", %({{ {1, 2, 3}[1] }}), [] of ASTNode, "2"
      end

      it "executes index out of bounds" do
        assert_macro "", %({{ {1, 2, 3}[3] }}), [] of ASTNode, "nil"
      end

      it "executes size" do
        assert_macro "", %({{ {1, 2, 3}.size }}), [] of ASTNode, "3"
      end

      it "executes empty?" do
        assert_macro "", %({{ {1, 2, 3}.empty? }}), [] of ASTNode, "false"
      end

      it "executes join" do
        assert_macro "", %({{ {1, 2, 3}.join ", " }}), [] of ASTNode, %("1, 2, 3")
      end

      it "executes join with strings" do
        assert_macro "", %({{ {"a", "b"}.join ", " }}), [] of ASTNode, %("a, b")
      end

      it "executes map" do
        assert_macro "", %({{ {1, 2, 3}.map { |e| e == 2 } }}), [] of ASTNode, "{false, true, false}"
      end

      it "executes map with constants" do
        assert_macro "x", %({{x.map { |e| e.id }}}), [TupleLiteral.new([Path.new("Foo"), Path.new("Bar")] of ASTNode)] of ASTNode, "{Foo, Bar}"
      end

      it "executes map with arg" do
        assert_macro "x", %({{x.map { |e| e.id }}}), [TupleLiteral.new(["hello".call] of ASTNode)] of ASTNode, "{hello}"
      end

      describe "#map_with_index" do
        context "with both arguments" do
          it "returns the resulting tuple" do
            assert_macro "", %({{{1, 2, 3}.map_with_index { |e, idx| e == 2 || idx <= 1 }}}), [] of ASTNode, %({true, true, false})
          end
        end

        context "without the index argument" do
          it "returns the resulting tuple" do
            assert_macro "", %({{{1, 2, 3}.map_with_index { |e| e }}}), [] of ASTNode, %({1, 2, 3})
          end
        end

        context "without the element argument" do
          it "returns the resulting tuple" do
            assert_macro "", %({{{1, 2, 3}.map_with_index { |_, idx| idx }}}), [] of ASTNode, %({0, 1, 2})
          end
        end

        context "without either argument" do
          it "returns the resulting tuple" do
            assert_macro "", %({{{1, 2, 3}.map_with_index { 7 }}}), [] of ASTNode, %({7, 7, 7})
          end
        end
      end

      it "executes select" do
        assert_macro "", %({{ {1, 2, 3}.select { |e| e == 1 } }}), [] of ASTNode, "{1}"
      end

      it "executes reject" do
        assert_macro "", %({{ {1, 2, 3}.reject { |e| e == 1 } }}), [] of ASTNode, "{2, 3}"
      end

      it "executes find (finds)" do
        assert_macro "", %({{ {1, 2, 3}.find { |e| e == 2 } }}), [] of ASTNode, "2"
      end

      it "executes find (doesn't find)" do
        assert_macro "", %({{ {1, 2, 3}.find { |e| e == 4 } }}), [] of ASTNode, "nil"
      end

      it "executes any? (true)" do
        assert_macro "", %({{ {1, 2, 3}.any? { |e| e == 1 } }}), [] of ASTNode, "true"
      end

      it "executes any? (false)" do
        assert_macro "", %({{ {1, 2, 3}.any? { |e| e == 4 } }}), [] of ASTNode, "false"
      end

      it "executes all? (true)" do
        assert_macro "", %({{ {1, 1, 1}.all? { |e| e == 1 } }}), [] of ASTNode, "true"
      end

      it "executes all? (false)" do
        assert_macro "", %({{ {1, 2, 1}.all? { |e| e == 1 } }}), [] of ASTNode, "false"
      end

      it "executes first" do
        assert_macro "", %({{ {1, 2, 3}.first }}), [] of ASTNode, "1"
      end

      it "executes last" do
        assert_macro "", %({{ {1, 2, 3}.last }}), [] of ASTNode, "3"
      end

      it "executes splat" do
        assert_macro "", %({{ {1, 2, 3}.splat }}), [] of ASTNode, "1, 2, 3"
      end

      it "executes splat with arg" do
        assert_macro "", %({{ {1, 2, 3}.splat(", ") }}), [] of ASTNode, "1, 2, 3, "
      end

      it "executes splat with symbols and strings" do
        assert_macro "", %({{ {:foo, "hello", 3}.splat }}), [] of ASTNode, %(:foo, "hello", 3)
      end

      it "executes splat with splat" do
        assert_macro "", %({{ *{1, 2, 3} }}), [] of ASTNode, "1, 2, 3"
      end

      it "executes is_a?" do
        assert_macro "", %({{ {1, 2, 3}.is_a?(TupleLiteral) }}), [] of ASTNode, "true"
        assert_macro "", %({{ {1, 2, 3}.is_a?(ArrayLiteral) }}), [] of ASTNode, "false"
      end

      it "creates a tuple literal with a var" do
        assert_macro "x", %({% a = {x} %}{{a[0]}}), [1.int32] of ASTNode, "1"
      end

      it "executes sort with numbers" do
        assert_macro "", %({{ {3, 2, 1}.sort }}), [] of ASTNode, "{1, 2, 3}"
      end

      it "executes sort with strings" do
        assert_macro "", %({{ {"c", "b", "a"}.sort }}), [] of ASTNode, %({"a", "b", "c"})
      end

      it "executes sort with ids" do
        assert_macro "", %({{ {"c".id, "b".id, "a".id}.sort }}), [] of ASTNode, %({a, b, c})
      end

      it "executes sort with ids and strings" do
        assert_macro "", %({{ {"c".id, "b", "a".id}.sort }}), [] of ASTNode, %({a, "b", c})
      end

      it "executes uniq" do
        assert_macro "", %({{ {1, 1, 1, 2, 3, 1, 2, 3, 4}.uniq }}), [] of ASTNode, %({1, 2, 3, 4})
      end

      it "executes unshift" do
        assert_macro "", %({% x = {1}; x.unshift(2); %}{{x}}), [] of ASTNode, %({2, 1})
      end

      it "executes push" do
        assert_macro "", %({% x = {1}; x.push(2); x << 3 %}{{x}}), [] of ASTNode, %({1, 2, 3})
      end

      it "executes includes?" do
        assert_macro "", %({{ {1, 2, 3}.includes?(1) }}), [] of ASTNode, %(true)
        assert_macro "", %({{ {1, 2, 3}.includes?(4) }}), [] of ASTNode, %(false)
      end

      it "executes +" do
        assert_macro "", %({{ {1, 2} + {3, 4, 5} }}), [] of ASTNode, %({1, 2, 3, 4, 5})
      end
    end

    describe "regex methods" do
      it "executes source" do
        assert_macro "", %({{ /rëgéx/i.source }}), [] of ASTNode, %("rëgéx")
      end

      it "executes options" do
        assert_macro "", %({{ //.options }}), [] of ASTNode, %([] of ::Symbol)
        assert_macro "", %({{ /a/i.options }}), [] of ASTNode, %([:i] of ::Symbol)
        assert_macro "", %({{ /re/mix.options }}), [] of ASTNode, %([:i, :m, :x] of ::Symbol)
      end
    end

    describe "metavar methods" do
      it "executes nothing" do
        assert_macro "x", %({{x}}), [MetaMacroVar.new("foo", Program.new.int32)] of ASTNode, %(foo)
      end

      it "executes name" do
        assert_macro "x", %({{x.name}}), [MetaMacroVar.new("foo", Program.new.int32)] of ASTNode, %(foo)
      end

      it "executes id" do
        assert_macro "x", %({{x.id}}), [MetaMacroVar.new("foo", Program.new.int32)] of ASTNode, %(foo)
      end

      it "executes is_a?" do
        assert_macro "x", %({{x.is_a?(MetaVar)}}), [MetaMacroVar.new("foo", Program.new.int32)] of ASTNode, %(true)
      end
    end

    describe "block methods" do
      it "executes body" do
        assert_macro "x", %({{x.body}}), [Block.new(body: 1.int32)] of ASTNode, "1"
      end

      it "executes args" do
        assert_macro "x", %({{x.args}}), [Block.new(["x".var, "y".var])] of ASTNode, "[x, y]"
      end

      it "executes splat_index" do
        assert_macro "x", %({{x.splat_index}}), [Block.new(["x".var, "y".var], splat_index: 1)] of ASTNode, "1"
        assert_macro "x", %({{x.splat_index}}), [Block.new(["x".var, "y".var])] of ASTNode, "nil"
      end
    end

    describe "expressions methods" do
      it "executes expressions" do
        assert_macro "x", %({{x.body.expressions[0]}}), [Block.new(body: Expressions.new(["some_call".call, "some_other_call".call] of ASTNode))] of ASTNode, "some_call"
      end
    end

    it "executes assign" do
      assert_macro "", %({{a = 1}}{{a}}), [] of ASTNode, "11"
    end

    it "executes assign without output" do
      assert_macro "", %({% a = 1 %}{{a}}), [] of ASTNode, "1"
    end

    describe TypeNode do
      describe "#includers" do
        it "returns an array of types `self` is included in" do
          assert_type(%(
            module Foo
            end

            module Baz
              module Tar
                include Baz
              end
            end

            abstract class Parent
            end

            module Enumt(T)
              include Baz
            end

            class Bar < Parent
              include Foo
              include Baz
            end

            struct Str
              include Enumt(String)
              include Baz
            end

            struct Gen(T)
              include Baz
            end

            abstract struct AStr
              include Baz
            end

            abstract class ACla
              include Baz
            end

            class SubT(T)
              include Baz
            end

            class ChildT(T) < SubT(T)
            end

          {% if Baz.includers.map(&.stringify) == ["Baz::Tar", "Enumt(T)", "Bar", "Str", "Gen(T)", "AStr", "ACla", "SubT(T)"] && Enumt.includers.map(&.stringify) == ["Str"]  %}
            1
          {% else %}
            'a'
          {% end %}
        )) { int32 }
        end
      end

      it "executes name" do
        assert_macro("x", "{{x.name}}", "String") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes instance_vars" do
        assert_macro("x", "{{x.instance_vars.map &.stringify}}", %(["bytesize", "length", "c"])) do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes class vars" do
        assert_macro("x", "{{x.class_vars.map &.name}}", %([class_var])) do |program|
          klass = NonGenericClassType.new(program, program, "SomeType", program.reference)
          declare_class_var(klass, "@@class_var", program.string)
          [TypeNode.new(klass)] of ASTNode
        end
      end

      it "executes class vars (with inheritance)" do
        assert_macro("x", "{{x.class_vars.map &.name}}", %([child_class_var, base_class_var, mod_class_var])) do |program|
          base_class = NonGenericClassType.new(program, program, "BaseType", program.reference)
          declare_class_var(base_class, "@@base_class_var", program.string)
          mod = NonGenericModuleType.new(program, program, "SomeModule")
          declare_class_var(mod, "@@mod_class_var", program.string)
          base_class.include mod
          child_class = NonGenericClassType.new(program, program, "ChildType", base_class)
          declare_class_var(child_class, "@@child_class_var", program.string)
          [TypeNode.new(child_class)] of ASTNode
        end
      end

      it "executes instance_vars on metaclass" do
        assert_macro("x", "{{x.class.instance_vars.map &.stringify}}", %([])) do |program|
          klass = NonGenericClassType.new(program, program, "SomeType", program.reference)
          klass.declare_instance_var("@var", program.string)
          [TypeNode.new(klass)] of ASTNode
        end
      end

      it "executes class_vars on metaclass" do
        assert_macro("x", "{{x.class.class_vars.map &.stringify}}", %([])) do |program|
          klass = NonGenericClassType.new(program, program, "SomeType", program.reference)
          declare_class_var(klass, "@@class_var", program.string)
          [TypeNode.new(klass)] of ASTNode
        end
      end

      it "executes instance_vars on symbol literal" do
        assert_macro("x", "{{x.instance_vars.map &.stringify}}", %([])) do |program|
          [TypeNode.new(SymbolLiteralType.new(program, "foo".symbol))] of ASTNode
        end
      end

      it "executes class_vars on symbol literal" do
        assert_macro("x", "{{x.class_vars.map &.stringify}}", %([])) do |program|
          [TypeNode.new(SymbolLiteralType.new(program, "foo".symbol))] of ASTNode
        end
      end

      it "executes methods" do
        assert_macro("x", "{{x.methods.map &.name}}", %([foo])) do |program|
          klass = NonGenericClassType.new(program, program, "SomeType", program.reference)
          a_def = Def.new "foo"
          klass.add_def a_def
          [TypeNode.new(klass)] of ASTNode
        end
      end

      it "executes class methods" do
        assert_macro("x", "{{x.class.methods.map &.name}}", %([allocate])) do |program|
          klass = NonGenericClassType.new(program, program, "SomeType", program.reference)
          [TypeNode.new(klass)] of ASTNode
        end
      end

      it "executes ancestors" do
        assert_macro("x", "{{x.ancestors}}", %([SomeModule, Reference, Object])) do |program|
          mod = NonGenericModuleType.new(program, program, "SomeModule")
          klass = NonGenericClassType.new(program, program, "SomeType", program.reference)
          klass.include mod

          [TypeNode.new(klass)] of ASTNode
        end
      end

      it "executes ancestors (with generic)" do
        assert_macro("x", "{{x.ancestors}}", %([SomeGenericModule(String), SomeGenericType(String), Reference, Object])) do |program|
          generic_type = GenericClassType.new(program, program, "SomeGenericType", program.reference, ["T"])
          generic_mod = GenericModuleType.new(program, program, "SomeGenericModule", ["T"])
          type_var = {"T" => TypeNode.new(program.string)} of String => ASTNode
          type = GenericClassInstanceType.new(program, generic_type, program.reference, type_var)
          mod = GenericModuleInstanceType.new(program, generic_mod, type_var)

          klass = NonGenericClassType.new(program, program, "SomeType", type)
          klass.include mod

          [TypeNode.new(klass)] of ASTNode
        end
      end

      it "executes superclass" do
        assert_macro("x", "{{x.superclass}}", %(Reference)) do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes size of tuple" do
        assert_macro("x", "{{x.size}}", "2") do |program|
          [TypeNode.new(program.tuple_of([program.int32, program.string] of TypeVar))] of ASTNode
        end
      end

      it "executes size of tuple metaclass" do
        assert_macro("x", "{{x.size}}", "2") do |program|
          [TypeNode.new(program.tuple_of([program.int32, program.string] of TypeVar).metaclass)] of ASTNode
        end
      end

      it "executes type_vars" do
        assert_macro("x", "{{x.type_vars.map &.stringify}}", %(["A", "B"])) do |program|
          [TypeNode.new(GenericClassType.new(program, program, "SomeType", program.object, ["A", "B"]))] of ASTNode
        end
      end

      it "executes class" do
        assert_macro("x", "{{x.class.name}}", "String.class") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes instance" do
        assert_macro("x", "{{x.class.instance}}", "String") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes ==" do
        assert_macro("x", "{{x == Reference}}", "false") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
        assert_macro("x", "{{x == String}}", "true") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes !=" do
        assert_macro("x", "{{x != Reference}}", "true") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
        assert_macro("x", "{{x != String}}", "false") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes <" do
        assert_macro("x", "{{x < Reference}}", "true") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
        assert_macro("x", "{{x < String}}", "false") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes <=" do
        assert_macro("x", "{{x <= Reference}}", "true") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
        assert_macro("x", "{{x <= String}}", "true") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes >" do
        assert_macro("x", "{{x > Reference}}", "false") do |program|
          [TypeNode.new(program.reference)] of ASTNode
        end
        assert_macro("x", "{{x > String}}", "true") do |program|
          [TypeNode.new(program.reference)] of ASTNode
        end
      end

      it "executes >=" do
        assert_macro("x", "{{x >= Reference}}", "true") do |program|
          [TypeNode.new(program.reference)] of ASTNode
        end
        assert_macro("x", "{{x >= String}}", "true") do |program|
          [TypeNode.new(program.reference)] of ASTNode
        end
      end

      it "executes nilable? (false)" do
        assert_macro("x", "{{x.nilable?}}", "false") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes nilable? (true)" do
        assert_macro("x", "{{x.nilable?}}", "true") do |program|
          [TypeNode.new(program.union_of(program.string, program.nil))] of ASTNode
        end
      end

      it "executes resolve" do
        assert_macro("x", "{{x.resolve}}", "String") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes resolve?" do
        assert_macro("x", "{{x.resolve?}}", "String") do |program|
          [TypeNode.new(program.string)] of ASTNode
        end
      end

      it "executes union_types (union)" do
        assert_macro("x", "{{x.union_types}}", %([Bool, Int32])) do |program|
          [TypeNode.new(program.union_of(program.int32, program.bool))] of ASTNode
        end
      end

      it "executes union_types (non-union)" do
        assert_macro("x", "{{x.union_types}}", %([Int32])) do |program|
          [TypeNode.new(program.int32)] of ASTNode
        end
      end
    end

    describe "type declaration methods" do
      it "executes var" do
        assert_macro "x", %({{x.var}}), [TypeDeclaration.new(Var.new("some_name"), Path.new("SomeType"))] of ASTNode, "some_name"
      end

      it "executes var when instance var" do
        assert_macro "x", %({{x.var}}), [TypeDeclaration.new(InstanceVar.new("@some_name"), Path.new("SomeType"))] of ASTNode, "@some_name"
      end

      it "executes type" do
        assert_macro "x", %({{x.type}}), [TypeDeclaration.new(Var.new("some_name"), Path.new("SomeType"))] of ASTNode, "SomeType"
      end

      it "executes value" do
        assert_macro "x", %({{x.value}}), [TypeDeclaration.new(Var.new("some_name"), Path.new("SomeType"), 1.int32)] of ASTNode, "1"
      end
    end

    describe "uninitialized var methods" do
      it "executes var" do
        assert_macro "x", %({{x.var}}), [UninitializedVar.new(Var.new("some_name"), Path.new("SomeType"))] of ASTNode, "some_name"
      end

      it "executes type" do
        assert_macro "x", %({{x.type}}), [UninitializedVar.new(Var.new("some_name"), Path.new("SomeType"))] of ASTNode, "SomeType"
      end
    end

    describe "proc notation methods" do
      it "gets single input" do
        assert_macro "x", %({{x.inputs}}), [ProcNotation.new(([Path.new("SomeType")] of ASTNode), Path.new("SomeResult"))] of ASTNode, "[SomeType]"
      end

      it "gets single output" do
        assert_macro "x", %({{x.output}}), [ProcNotation.new(([Path.new("SomeType")] of ASTNode), Path.new("SomeResult"))] of ASTNode, "SomeResult"
      end

      it "gets multiple inputs" do
        assert_macro "x", %({{x.inputs}}), [ProcNotation.new([Path.new("SomeType"), Path.new("OtherType")] of ASTNode)] of ASTNode, "[SomeType, OtherType]"
      end

      it "gets empty output" do
        assert_macro "x", %({{x.output}}), [ProcNotation.new([Path.new("SomeType")] of ASTNode)] of ASTNode, "nil"
      end
    end

    describe "proc literal methods" do
      it "executes body" do
        assert_macro "x", %({{x.body}}), [ProcLiteral.new(Def.new("->", body: 1.int32))] of ASTNode, "1"
      end

      it "executes args" do
        assert_macro "x", %({{x.args}}), [ProcLiteral.new(Def.new("->", args: [Arg.new("z")]))] of ASTNode, "[z]"
      end
    end

    describe "proc pointer methods" do
      it "executes obj when present" do
        assert_macro "x", %({{x.obj}}), [ProcPointer.new(Var.new("some_object"), "method", [] of ASTNode)] of ASTNode, "some_object"
      end

      it "executes obj when absent" do
        assert_macro "x", %({{x.obj}}), [ProcPointer.new(NilLiteral.new, "method", [] of ASTNode)] of ASTNode, "nil"
      end

      it "executes name" do
        assert_macro "x", %({{x.name}}), [ProcPointer.new(Var.new("some_object"), "method", [] of ASTNode)] of ASTNode, "method"
      end

      it "executes args when empty" do
        assert_macro "x", %({{x.args}}), [ProcPointer.new(Var.new("some_object"), "method", [] of ASTNode)] of ASTNode, "[]"
      end

      it "executes args when not empty" do
        assert_macro "x", %({{x.args}}), [ProcPointer.new(Var.new("some_object"), "method", [Path.new("SomeType"), Path.new("OtherType")] of ASTNode)] of ASTNode, "[SomeType, OtherType]"
      end
    end

    describe "def methods" do
      it "executes name" do
        assert_macro "x", %({{x.name}}), [Def.new("some_def")] of ASTNode, "some_def"
      end

      it "executes body" do
        assert_macro "x", %({{x.body}}), [Def.new("some_def", body: 1.int32)] of ASTNode, "1"
      end

      it "executes args" do
        assert_macro "x", %({{x.args}}), [Def.new("some_def", args: [Arg.new("z")])] of ASTNode, "[z]"
      end

      it "executes splat_index" do
        assert_macro "x", %({{x.splat_index}}), [Def.new("some_def", ["x".arg, "y".arg], splat_index: 1)] of ASTNode, "1"
        assert_macro "x", %({{x.splat_index}}), [Def.new("some_def")] of ASTNode, "nil"
      end

      it "executes double_splat" do
        assert_macro "x", %({{x.double_splat}}), [Def.new("some_def", ["x".arg, "y".arg], double_splat: "s".arg)] of ASTNode, "s"
        assert_macro "x", %({{x.double_splat}}), [Def.new("some_def")] of ASTNode, ""
      end

      it "executes block_arg" do
        assert_macro "x", %({{x.block_arg}}), [Def.new("some_def", ["x".arg, "y".arg], block_arg: "b".arg)] of ASTNode, "b"
        assert_macro "x", %({{x.block_arg}}), [Def.new("some_def")] of ASTNode, ""
      end

      it "executes accepts_block?" do
        assert_macro "x", %({{x.accepts_block?}}), [Def.new("some_def", ["x".arg, "y".arg], yields: 1)] of ASTNode, "true"
        assert_macro "x", %({{x.accepts_block?}}), [Def.new("some_def")] of ASTNode, "false"
      end

      it "executes return_type" do
        assert_macro "x", %({{x.return_type}}), [Def.new("some_def", ["x".arg, "y".arg], return_type: "b".arg)] of ASTNode, "b"
        assert_macro "x", %({{x.return_type}}), [Def.new("some_def")] of ASTNode, ""
      end

      it "executes receiver" do
        assert_macro "x", %({{x.receiver}}), [Def.new("some_def", receiver: Var.new("self"))] of ASTNode, "self"
      end

      it "executes visibility" do
        assert_macro "x", %({{x.visibility}}), [Def.new("some_def")] of ASTNode, ":public"
        assert_macro "x", %({{x.visibility}}), [Def.new("some_def").tap { |d| d.visibility = Visibility::Private }] of ASTNode, ":private"
      end
    end

    describe "macro methods" do
      it "executes name" do
        assert_macro "x", %({{x.name}}), [Macro.new("some_macro")] of ASTNode, "some_macro"
      end

      it "executes body" do
        assert_macro "x", %({{x.body}}), [Macro.new("some_macro", body: 1.int32)] of ASTNode, "1"
      end

      it "executes args" do
        assert_macro "x", %({{x.args}}), [Macro.new("some_macro", args: [Arg.new("z")])] of ASTNode, "[z]"
      end

      it "executes splat_index" do
        assert_macro "x", %({{x.splat_index}}), [Macro.new("some_macro", ["x".arg, "y".arg], splat_index: 1)] of ASTNode, "1"
        assert_macro "x", %({{x.splat_index}}), [Macro.new("some_macro")] of ASTNode, "nil"
      end

      it "executes double_splat" do
        assert_macro "x", %({{x.double_splat}}), [Macro.new("some_macro", ["x".arg, "y".arg], double_splat: "s".arg)] of ASTNode, "s"
        assert_macro "x", %({{x.double_splat}}), [Macro.new("some_macro")] of ASTNode, ""
      end

      it "executes block_arg" do
        assert_macro "x", %({{x.block_arg}}), [Macro.new("some_macro", ["x".arg, "y".arg], block_arg: "b".arg)] of ASTNode, "b"
        assert_macro "x", %({{x.block_arg}}), [Macro.new("some_macro")] of ASTNode, ""
      end

      it "executes visibility" do
        assert_macro "x", %({{x.visibility}}), [Macro.new("some_macro")] of ASTNode, ":public"
        assert_macro "x", %({{x.visibility}}), [Macro.new("some_macro").tap { |d| d.visibility = Visibility::Private }] of ASTNode, ":private"
      end
    end

    describe "unary expression methods" do
      it "executes exp" do
        assert_macro "x", %({{x.exp}}), [Not.new("some_call".call)] of ASTNode, "some_call"
      end
    end

    describe "offsetof methods" do
      it "executes type" do
        assert_macro "x", %({{x.type}}), [OffsetOf.new("SomeType".path, "@some_ivar".instance_var)] of ASTNode, "SomeType"
      end

      it "executes instance_var" do
        assert_macro "x", %({{x.instance_var}}), [OffsetOf.new("SomeType".path, "@some_ivar".instance_var)] of ASTNode, "@some_ivar"
      end
    end

    describe "visibility modifier methods" do
      node = VisibilityModifier.new(Visibility::Protected, Def.new("some_def"))

      it "executes visibility" do
        assert_macro "x", %({{x.visibility}}), [node] of ASTNode, ":protected"
      end

      it "executes exp" do
        assert_macro "x", %({{x.exp}}), [node] of ASTNode, "def some_def\nend"
      end
    end

    describe "is_a methods" do
      node = IsA.new("var".var, Path.new("Int32"))

      it "executes receiver" do
        assert_macro "x", %({{x.receiver}}), [node] of ASTNode, "var"
      end

      it "executes arg" do
        assert_macro "x", %({{x.arg}}), [node] of ASTNode, "Int32"
      end
    end

    describe "responds_to methods" do
      node = RespondsTo.new("var".var, "to_i")

      it "executes receiver" do
        assert_macro "x", %({{x.receiver}}), [node] of ASTNode, "var"
      end

      it "executes name" do
        assert_macro "x", %({{x.name}}), [node] of ASTNode, %("to_i")
      end
    end

    describe "require methods" do
      it "executes path" do
        assert_macro "x", %({{x.path}}), [Require.new("json")] of ASTNode, %("json")
      end
    end

    describe "call methods" do
      it "executes name" do
        assert_macro "x", %({{x.name}}), ["some_call".call] of ASTNode, "some_call"
      end

      it "executes args" do
        assert_macro "x", %({{x.args}}), [Call.new(nil, "some_call", [1.int32, 3.int32] of ASTNode)] of ASTNode, "[1, 3]"
      end

      it "executes receiver" do
        assert_macro "x", %({{x.receiver}}), [Call.new(1.int32, "some_call")] of ASTNode, "1"
      end

      it "executes block" do
        assert_macro "x", %({{x.block}}), [Call.new(1.int32, "some_call", block: Block.new)] of ASTNode, "do\nend"
      end

      it "executes block arg" do
        assert_macro "x", %({{x.block_arg}}), [Call.new(1.int32, "some_call", block_arg: "bl".arg)] of ASTNode, "bl"
      end

      it "executes block arg (nop)" do
        assert_macro "x", %({{x.block_arg}}), [Call.new(1.int32, "some_call")] of ASTNode, ""
      end

      it "executes named args" do
        assert_macro "x", %({{x.named_args}}), [Call.new(1.int32, "some_call", named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])] of ASTNode, "[a: 1, b: 2]"
      end

      it "executes named args name" do
        assert_macro "x", %({{x.named_args[0].name}}), [Call.new(1.int32, "some_call", named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])] of ASTNode, "a"
      end

      it "executes named args value" do
        assert_macro "x", %({{x.named_args[0].value}}), [Call.new(1.int32, "some_call", named_args: [NamedArgument.new("a", 1.int32), NamedArgument.new("b", 2.int32)])] of ASTNode, "1"
      end
    end

    describe "arg methods" do
      it "executes name" do
        arg = "into".arg
        assert_macro "x", %({{x.name}}), [arg] of ASTNode, "into"
        arg.name = "array" # internal
        assert_macro "x", %({{x.name}}), [arg] of ASTNode, "into"
      end

      it "executes internal_name" do
        arg = "into".arg
        assert_macro "x", %({{x.internal_name}}), [arg] of ASTNode, "into"
        arg.name = "array"
        assert_macro "x", %({{x.internal_name}}), [arg] of ASTNode, "array"
      end

      it "executes default_value" do
        assert_macro "x", %({{x.default_value}}), ["some_arg".arg(default_value: 1.int32)] of ASTNode, "1"
      end

      it "executes restriction" do
        assert_macro "x", %({{x.restriction}}), ["some_arg".arg(restriction: "T".path)] of ASTNode, "T"
      end
    end

    describe "cast methods" do
      it "executes obj" do
        assert_macro "x", %({{x.obj}}), [Cast.new("x".call, "Int32".path)] of ASTNode, "x"
      end

      it "executes to" do
        assert_macro "x", %({{x.to}}), [Cast.new("x".call, "Int32".path)] of ASTNode, "Int32"
      end
    end

    describe "nilable cast methods" do
      it "executes obj" do
        assert_macro "x", %({{x.obj}}), [NilableCast.new("x".call, "Int32".path)] of ASTNode, "x"
      end

      it "executes to" do
        assert_macro "x", %({{x.to}}), [NilableCast.new("x".call, "Int32".path)] of ASTNode, "Int32"
      end
    end

    describe "case methods" do
      case_node = Case.new(1.int32, [When.new([2.int32, 3.int32] of ASTNode, 4.int32)], 5.int32)

      it "executes cond" do
        assert_macro "x", %({{x.cond}}), [case_node] of ASTNode, "1"
      end

      it "executes whens" do
        assert_macro "x", %({{x.whens}}), [case_node] of ASTNode, "[when 2, 3\n  4\n]"
      end

      it "executes when conds" do
        assert_macro "x", %({{x.whens[0].conds}}), [case_node] of ASTNode, "[2, 3]"
      end

      it "executes when body" do
        assert_macro "x", %({{x.whens[0].body}}), [case_node] of ASTNode, "4"
      end

      it "executes else" do
        assert_macro "x", %({{x.else}}), [case_node] of ASTNode, "5"
      end
    end

    describe "if methods" do
      if_node = If.new(1.int32, 2.int32, 3.int32)

      it "executes cond" do
        assert_macro "x", %({{x.cond}}), [if_node] of ASTNode, "1"
      end

      it "executes then" do
        assert_macro "x", %({{x.then}}), [if_node] of ASTNode, "2"
      end

      it "executes else" do
        assert_macro "x", %({{x.else}}), [if_node] of ASTNode, "3"
      end

      it "executes else (nop)" do
        assert_macro "x", %({{x.else}}), [If.new(1.int32, 2.int32)] of ASTNode, ""
      end
    end

    describe "while methods" do
      while_node = While.new(1.int32, 2.int32)

      it "executes cond" do
        assert_macro "x", %({{x.cond}}), [while_node] of ASTNode, "1"
      end

      it "executes body" do
        assert_macro "x", %({{x.body}}), [while_node] of ASTNode, "2"
      end
    end

    describe "assign methods" do
      it "executes target" do
        assert_macro "x", %({{x.target}}), [Assign.new("foo".var, 2.int32)] of ASTNode, "foo"
      end

      it "executes value" do
        assert_macro "x", %({{x.value}}), [Assign.new("foo".var, 2.int32)] of ASTNode, "2"
      end
    end

    describe "multiassign methods" do
      multiassign_node = MultiAssign.new(["foo".var, "bar".var] of ASTNode, [2.int32, "a".string] of ASTNode)

      it "executes targets" do
        assert_macro "x", %({{x.targets}}), [multiassign_node] of ASTNode, %([foo, bar])
      end

      it "executes values" do
        assert_macro "x", %({{x.values}}), [multiassign_node] of ASTNode, %([2, "a"])
      end
    end

    describe "instancevar methods" do
      it "executes name" do
        assert_macro "x", %({{x.name}}), [InstanceVar.new("ivar")] of ASTNode, %(ivar)
      end
    end

    describe "instancevar methods" do
      it "executes name" do
        assert_macro "x", %({{x.name}}), [InstanceVar.new("ivar")] of ASTNode, %(ivar)
      end
    end

    describe "readinstancevar methods" do
      it "executes obj" do
        assert_macro "x", %({{x.obj}}), [ReadInstanceVar.new("obj".var, "ivar")] of ASTNode, %(obj)
      end

      it "executes name" do
        assert_macro "x", %({{x.name}}), [ReadInstanceVar.new("obj".var, "ivar")] of ASTNode, %(ivar)
      end
    end

    describe "classvar methods" do
      it "executes name" do
        assert_macro "x", %({{x.name}}), [ClassVar.new("cvar")] of ASTNode, %(cvar)
      end
    end

    describe "global methods" do
      it "executes name" do
        assert_macro "x", %({{x.name}}), [Global.new("gvar")] of ASTNode, %(gvar)
      end
    end

    describe "splat methods" do
      it "executes exp" do
        assert_macro "x", %({{x.exp}}), [2.int32.splat] of ASTNode, "2"
      end
    end

    describe "generic methods" do
      it "executes name" do
        assert_macro "x", %({{x.name}}), [Generic.new("Foo".path, ["T".path] of ASTNode)] of ASTNode, "Foo"
      end

      it "executes type_vars" do
        assert_macro "x", %({{x.type_vars}}), [Generic.new("Foo".path, ["T".path, "U".path] of ASTNode)] of ASTNode, "[T, U]"
      end

      it "executes named_args" do
        assert_macro "x", %({{x.named_args}}), [Generic.new("Foo".path, [] of ASTNode, named_args: [NamedArgument.new("x", "U".path), NamedArgument.new("y", "V".path)])] of ASTNode, "{x: U, y: V}"
      end

      it "executes resolve" do
        assert_macro "x", %({{x.resolve}}), [Generic.new("Array".path, ["String".path] of ASTNode)] of ASTNode, %(Array(String))

        expect_raises(Crystal::TypeException, "undefined constant Foo") do
          assert_macro "x", %({{x.resolve}}), [Generic.new("Foo".path, ["String".path] of ASTNode)] of ASTNode, %(Foo(String))
        end

        expect_raises(Crystal::TypeException, "undefined constant Foo") do
          assert_macro "x", %({{x.resolve}}), [Generic.new("Array".path, ["Foo".path] of ASTNode)] of ASTNode, %(Array(foo))
        end
      end

      it "executes resolve?" do
        assert_macro "x", %({{x.resolve?}}), [Generic.new("Array".path, ["String".path] of ASTNode)] of ASTNode, %(Array(String))
        assert_macro "x", %({{x.resolve?}}), [Generic.new("Foo".path, ["String".path] of ASTNode)] of ASTNode, %(nil)
        assert_macro "x", %({{x.resolve?}}), [Generic.new("Array".path, ["Foo".path] of ASTNode)] of ASTNode, %(nil)
      end

      it "executes types" do
        assert_macro "x", %({{x.types}}), [Generic.new("Foo".path, ["T".path] of ASTNode)] of ASTNode, "[Foo(T)]"
      end
    end

    describe "union methods" do
      it "executes types" do
        assert_macro "x", %({{x.types}}), [Crystal::Union.new(["Int32".path, "String".path] of ASTNode)] of ASTNode, "[Int32, String]"
      end

      it "executes resolve" do
        assert_macro "x", %({{x.resolve}}), [Crystal::Union.new(["Int32".path, "String".path] of ASTNode)] of ASTNode, "(Int32 | String)"
      end

      it "executes resolve?" do
        assert_macro "x", %({{x.resolve?}}), [Crystal::Union.new(["Int32".path, "String".path] of ASTNode)] of ASTNode, "(Int32 | String)"
        assert_macro "x", %({{x.resolve?}}), [Crystal::Union.new(["Int32".path, "Unknown".path] of ASTNode)] of ASTNode, "nil"
      end
    end

    describe "range methods" do
      it "executes begin" do
        assert_macro "x", %({{x.begin}}), [RangeLiteral.new(1.int32, 2.int32, true)] of ASTNode, "1"
      end

      it "executes end" do
        assert_macro "x", %({{x.end}}), [RangeLiteral.new(1.int32, 2.int32, true)] of ASTNode, "2"
      end

      it "executes excludes_end?" do
        assert_macro "x", %({{x.excludes_end?}}), [RangeLiteral.new(1.int32, 2.int32, true)] of ASTNode, "true"
      end

      it "executes map" do
        assert_macro "x", %({{x.map(&.stringify)}}), [RangeLiteral.new(1.int32, 3.int32, false)] of ASTNode, %(["1", "2", "3"])
        assert_macro "x", %({{x.map(&.stringify)}}), [RangeLiteral.new(1.int32, 3.int32, true)] of ASTNode, %(["1", "2"])
      end

      it "executes to_a" do
        assert_macro "x", %({{x.to_a}}), [RangeLiteral.new(1.int32, 3.int32, false)] of ASTNode, %([1, 2, 3])
        assert_macro "x", %({{x.to_a}}), [RangeLiteral.new(1.int32, 3.int32, true)] of ASTNode, %([1, 2])
      end
    end

    describe "path methods" do
      it "executes resolve" do
        assert_macro "x", %({{x.resolve}}), [Path.new("String")] of ASTNode, %(String)

        expect_raises(Crystal::TypeException, "undefined constant Foo") do
          assert_macro "x", %({{x.resolve}}), [Path.new("Foo")] of ASTNode, %(Foo)
        end
      end

      it "executes resolve?" do
        assert_macro "x", %({{x.resolve?}}), [Path.new("String")] of ASTNode, %(String)
        assert_macro "x", %({{x.resolve?}}), [Path.new("Foo")] of ASTNode, %(nil)
      end

      it "executes types" do
        assert_macro "x", %({{x.types}}), [Path.new("String")] of ASTNode, %([String])
      end
    end

    describe "annotation methods" do
      it "executes [] with NumberLiteral" do
        assert_macro "x, y", %({{x[y]}}), [
          Annotation.new(Path.new("Foo"), [42.int32] of ASTNode),
          0.int32,
        ] of ASTNode, %(42)
      end

      it "executes [] with SymbolLiteral" do
        assert_macro "x, y", %({{x[y]}}), [
          Annotation.new(Path.new("Foo"), [] of ASTNode, [NamedArgument.new("foo", 42.int32)]),
          "foo".symbol,
        ] of ASTNode, %(42)
      end

      it "executes [] with StringLiteral" do
        assert_macro "x, y", %({{x[y]}}), [
          Annotation.new(Path.new("Foo"), [] of ASTNode, [NamedArgument.new("foo", 42.int32)]),
          "foo".string,
        ] of ASTNode, %(42)
      end

      it "executes [] with MacroId" do
        assert_macro "x, y", %({{x[y]}}), [
          Annotation.new(Path.new("Foo"), [] of ASTNode, [NamedArgument.new("foo", 42.int32)]),
          MacroId.new("foo"),
        ] of ASTNode, %(42)
      end

      it "executes [] with other ASTNode, but raises an error" do
        expect_raises(Crystal::TypeException, "argument to [] must be a number, symbol or string, not BoolLiteral") do
          assert_macro "x, y", %({{x[y]}}), [
            Annotation.new(Path.new("Foo"), [] of ASTNode),
            true.bool,
          ] of ASTNode, %(nil)
        end
      end
    end

    describe "env" do
      it "has key" do
        ENV["FOO"] = "foo"
        assert_macro "", %({{env("FOO")}}), [] of ASTNode, %("foo")
        ENV.delete "FOO"
      end

      it "doesn't have key" do
        ENV.delete "FOO"
        assert_macro "", %({{env("FOO")}}), [] of ASTNode, %(nil)
      end
    end

    describe "flag?" do
      it "has flag" do
        assert_macro "", %({{flag?(:foo)}}), [] of ASTNode, %(true), flags: "foo"
      end

      it "doesn't have flag" do
        assert_macro "", %({{flag?(:foo)}}), [] of ASTNode, %(false)
      end
    end

    it "compares versions" do
      assert_macro "", %({{compare_versions("1.10.3", "1.2.3")}}), [] of ASTNode, %(1)
    end

    describe "printing" do
      it "puts" do
        String.build do |io|
          assert_macro "foo", %({% puts foo %}), "" do |program|
            program.stdout = io
            ["bar".string] of ASTNode
          end
        end.should eq %(bar\n)
      end

      it "p" do
        String.build do |io|
          assert_macro "foo", %({% p foo %}), "" do |program|
            program.stdout = io
            ["bar".string] of ASTNode
          end
        end.should eq %("bar"\n)
      end

      it "p!" do
        String.build do |io|
          assert_macro "foo", "{% p! foo %}", "" do |program|
            program.stdout = io
            ["bar".string] of ASTNode
          end
        end.should eq %(foo # => "bar"\n)
      end

      it "pp" do
        String.build do |io|
          assert_macro "foo", "{% pp foo %}", "" do |program|
            program.stdout = io
            ["bar".string] of ASTNode
          end
        end.should eq %("bar"\n)
      end

      it "pp!" do
        String.build do |io|
          assert_macro "foo", "{% pp! foo %}", "" do |program|
            program.stdout = io
            ["bar".string] of ASTNode
          end
        end.should eq %(foo # => "bar"\n)
      end
    end
  end

  describe "read_file" do
    context "with absolute path" do
      it "reads file (exists)" do
        run(%q<
          {{read_file("#{__DIR__}/../data/build")}}
          >, filename = __FILE__).to_string.should eq(File.read("#{__DIR__}/../data/build"))
      end

      it "reads file (doesn't exist)" do
        expect_raises(Crystal::TypeException, "No such file or directory") do
          run(%q<
            {{read_file("#{__DIR__}/../data/build_foo")}}
            >, filename = __FILE__)
        end
      end
    end

    context "with relative path" do
      it "reads file (exists)" do
        run(%q<
          {{read_file("spec/compiler/data/build")}}
          >, filename = __FILE__).to_string.should eq(File.read("spec/compiler/data/build"))
      end

      it "reads file (doesn't exist)" do
        expect_raises(Crystal::TypeException, "No such file or directory") do
          run(%q<
          {{read_file("spec/compiler/data/build_foo")}}
          >, filename = __FILE__)
        end
      end
    end
  end

  describe "read_file?" do
    context "with absolute path" do
      it "reads file (doesn't exist)" do
        run(%q<
          {{read_file?("#{__DIR__}/../data/build_foo")}} ? 10 : 20
          >, filename = __FILE__).to_i.should eq(20)
      end
    end

    context "with relative path" do
      it "reads file (doesn't exist)" do
        run(%q<
          {{read_file?("spec/compiler/data/build_foo")}} ? 10 : 20
          >, filename = __FILE__).to_i.should eq(20)
      end
    end
  end
end
