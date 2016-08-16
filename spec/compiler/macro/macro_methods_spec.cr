require "../../spec_helper"

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

    it "executes +" do
      assert_macro "", "{{1 + 2}}", [] of ASTNode, "3"
    end

    it "executes -" do
      assert_macro "", "{{1 - 2}}", [] of ASTNode, "-1"
    end

    it "executes *" do
      assert_macro "", "{{2 * 3}}", [] of ASTNode, "6"
    end

    it "executes /" do
      assert_macro "", "{{5 / 3}}", [] of ASTNode, "1"
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
      assert_macro "", %({{"1 2 3".split}}), [] of ASTNode, %(["1", "2", "3"])
    end

    it "executes split with argument" do
      assert_macro "", %({{"1-2-3".split("-")}}), [] of ASTNode, %(["1", "2", "3"])
    end

    it "executes split with char argument" do
      assert_macro "", %({{"1-2-3".split('-')}}), [] of ASTNode, %(["1", "2", "3"])
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
      assert_macro "x", %({{x.chars}}), [StringLiteral.new("123")] of ASTNode, %(['1', '2', '3'])
    end

    it "executes lines" do
      assert_macro "x", %({{x.lines}}), [StringLiteral.new("1\n2\n3")] of ASTNode, %(["1\\n", "2\\n", "3"])
    end

    it "executes size" do
      assert_macro "", %({{"hello".size}}), [] of ASTNode, "5"
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

    it "executes underscore" do
      assert_macro "", %({{"FooBar".underscore}}), [] of ASTNode, %("foo_bar")
    end

    it "executes to_i" do
      assert_macro "", %({{"1234".to_i}}), [] of ASTNode, %(1234)
    end

    it "executes to_i(base)" do
      assert_macro "", %({{"1234".to_i(16)}}), [] of ASTNode, %(4660)
    end
  end

  describe "macro id methods" do
    it "forwards methods to string" do
      assert_macro "x", %({{x.ends_with?("llo")}}), [MacroId.new("hello")] of ASTNode, %(true)
      assert_macro "x", %({{x.ends_with?("tro")}}), [MacroId.new("hello")] of ASTNode, %(false)
      assert_macro "x", %({{x.starts_with?("hel")}}), [MacroId.new("hello")] of ASTNode, %(true)
      assert_macro "x", %({{x.chomp}}), [MacroId.new("hello\n")] of ASTNode, %(hello)
      assert_macro "x", %({{x.upcase}}), [MacroId.new("hello")] of ASTNode, %(HELLO)
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

    it "executes map with constants" do
      assert_macro "x", %({{x.map { |e| e.id }}}), [ArrayLiteral.new([Path.new("Foo"), Path.new("Bar")] of ASTNode)] of ASTNode, "[Foo, Bar]"
    end

    it "executes map with arg" do
      assert_macro "x", %({{x.map { |e| e.id }}}), [ArrayLiteral.new(["hello".call] of ASTNode)] of ASTNode, "[hello]"
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

    it "executes argify" do
      assert_macro "", %({{[1, 2, 3].argify}}), [] of ASTNode, "1, 2, 3"
    end

    it "executes argify with symbols and strings" do
      assert_macro "", %({{[:foo, "hello", 3].argify}}), [] of ASTNode, %(:foo, "hello", 3)
    end

    it "executes argify with splat" do
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
  end

  describe "hash methods" do
    it "executes size" do
      assert_macro "", %({{{:a => 1, :b => 3}.size}}), [] of ASTNode, "2"
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
  end

  describe "named literal methods" do
    it "executes size" do
      assert_macro "", %({{{a: 1, b: 3}.size}}), [] of ASTNode, "2"
    end

    it "executes empty?" do
      assert_macro "", %({{{a: 1}.empty?}}), [] of ASTNode, "false"
    end

    it "executes []" do
      assert_macro "", %({{{a: 1}[:a]}}), [] of ASTNode, "1"
    end

    it "executes [] not found" do
      assert_macro "", %({{{a: 1}[:b]}}), [] of ASTNode, "nil"
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
      assert_macro "", %({% a = {} of Nil => Nil; a[1] = 2 %}{{a[1]}}), [] of ASTNode, "2"
    end

    it "creates a named tuple literal with a var" do
      assert_macro "x", %({% a = {a: x} %}{{a[:a]}}), [1.int32] of ASTNode, "1"
    end

    it "executes to_a" do
      assert_macro "", %({{{a: 1, b: 3}.to_a}}), [] of ASTNode, "[{a, 1}, {b, 3}]"
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

    it "executes argify" do
      assert_macro "", %({{ {1, 2, 3}.argify }}), [] of ASTNode, "1, 2, 3"
    end

    it "executes argify with symbols and strings" do
      assert_macro "", %({{ {:foo, "hello", 3}.argify }}), [] of ASTNode, %(:foo, "hello", 3)
    end

    it "executes argify with splat" do
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

  describe "metavar methods" do
    it "executes nothing" do
      assert_macro "x", %({{x}}), [MetaVar.new("foo", Program.new.int32)] of ASTNode, %(foo)
    end

    it "executes name" do
      assert_macro "x", %({{x.name}}), [MetaVar.new("foo", Program.new.int32)] of ASTNode, %(foo)
    end

    it "executes id" do
      assert_macro "x", %({{x.id}}), [MetaVar.new("foo", Program.new.int32)] of ASTNode, %(foo)
    end
  end

  describe "block methods" do
    it "executes body" do
      assert_macro "x", %({{x.body}}), [Block.new(body: 1.int32)] of ASTNode, "1"
    end

    it "executes args" do
      assert_macro "x", %({{x.args}}), [Block.new(["x".var, "y".var])] of ASTNode, "[x, y]"
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

  describe "type methods" do
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
      assert_macro("x", "{{x.class.name}}", "String:Class") do |program|
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

    it "executes receiver" do
      assert_macro "x", %({{x.receiver}}), [Def.new("some_def", receiver: Var.new("self"))] of ASTNode, "self"
    end

    it "executes visibility" do
      assert_macro "x", %({{x.visibility}}), [Def.new("some_def")] of ASTNode, ":public"
      assert_macro "x", %({{x.visibility}}), [Def.new("some_def").tap { |d| d.visibility = Visibility::Private }] of ASTNode, ":private"
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
      assert_macro "x", %({{x.name}}), ["some_arg".arg] of ASTNode, "some_arg"
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

  describe "assign methods" do
    it "executes target" do
      assert_macro "x", %({{x.target}}), [Assign.new("foo".var, 2.int32)] of ASTNode, "foo"
    end

    it "executes value" do
      assert_macro "x", %({{x.value}}), [Assign.new("foo".var, 2.int32)] of ASTNode, "2"
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
end
