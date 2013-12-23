#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Normalize: ssa" do
  it "performs ssa on simple assignment" do
    assert_normalize "a = 1; a = 2", "a = 1\na$1 = 2"
  end

  it "performs ssa on many simple assignments" do
    assert_normalize "a = 1; a = 2; a = 3", "a = 1\na$1 = 2\na$2 = 3"
  end

  it "performs ssa on read" do
    assert_normalize "a = 1; a = a + 1; a = a + 1", "a = 1\na$1 = a + 1\na$2 = a$1 + 1"
  end

  it "performs ssa on if with empty then" do
    assert_normalize "a = 1; if true; 1; end; a", "a = 1\nif true\n  1\nend\na"
  end

  it "performs ssa on if with empty else" do
    assert_normalize "a = 1; if true; else; 1; end; a", "a = 1\nif true\nelse\n  1\nend\na"
  end

  it "performs ssa on if without else" do
    assert_normalize "a = 1; if true; a = 2; end; a", "a = 1\nif true\n  #temp_1 = a$1 = 2\n  a$2 = a$1\n  #temp_1\nelse\n  a$2 = a\n  nil\nend\na$2"
  end

  it "performs ssa on if without then" do
    assert_normalize "a = 1; if true; else; a = 2; end; a", "a = 1\nif true\n  a$2 = a\n  nil\nelse\n  #temp_1 = a$1 = 2\n  a$2 = a$1\n  #temp_1\nend\na$2"
  end

  it "performs ssa on if" do
    assert_normalize "a = 1; if true; a = 2; else; a = 3; end; a", "a = 1\nif true\n  #temp_1 = a$1 = 2\n  a$3 = a$1\n  #temp_1\nelse\n  #temp_2 = a$2 = 3\n  a$3 = a$2\n  #temp_2\nend\na$3"
  end

  it "performs ssa on if assigns many times on then" do
    assert_normalize "a = 1; if true; a = 2; a = 3; a = 4; else; a = 5; end; a",
      "a = 1\nif true\n  #temp_1 = begin\n    a$1 = 2\n    a$2 = 3\n    a$3 = 4\n  end\n  a$5 = a$3\n  #temp_1\nelse\n  #temp_2 = a$4 = 5\n  a$5 = a$4\n  #temp_2\nend\na$5"
  end

  it "performs ssa on if assigns many times on else" do
    assert_normalize "a = 1; if true; a = 5; else; a = 2; a = 3; a = 4; end; a",
      "a = 1\nif true\n  #temp_1 = a$1 = 5\n  a$5 = a$1\n  #temp_1\nelse\n  #temp_2 = begin\n    a$2 = 2\n    a$3 = 3\n    a$4 = 4\n  end\n  a$5 = a$4\n  #temp_2\nend\na$5"
  end

  it "performs ssa on if declares var inside then" do
    assert_normalize "if true; a = 1; a = 2; end; a",
      "if true\n  #temp_1 = begin\n    a = 1\n    a$1 = 2\n  end\n  a$2 = a$1\n  #temp_1\nelse\n  a$2 = nil\n  nil\nend\na$2"
  end

  it "performs ssa on if declares var inside then 2" do
    assert_normalize "if true; a = 1; a = 2; else; 1; end; a",
      "if true\n  #temp_1 = begin\n    a = 1\n    a$1 = 2\n  end\n  a$2 = a$1\n  #temp_1\nelse\n  #temp_2 = 1\n  a$2 = nil\n  #temp_2\nend\na$2"
  end

  it "performs ssa on if declares var inside else" do
    assert_normalize "if true; else; a = 1; a = 2; end; a",
      "if true\n  a$2 = nil\n  nil\nelse\n  #temp_1 = begin\n    a = 1\n    a$1 = 2\n  end\n  a$2 = a$1\n  #temp_1\nend\na$2"
  end

  it "performs ssa on if declares var inside else 2" do
    assert_normalize "if true; 1; else; a = 1; a = 2; end; a",
      "if true\n  #temp_1 = 1\n  a$2 = nil\n  #temp_1\nelse\n  #temp_2 = begin\n    a = 1\n    a$1 = 2\n  end\n  a$2 = a$1\n  #temp_2\nend\na$2"
  end

  it "performs ssa on if declares var inside both branches" do
    assert_normalize "if true; a = 1; else; a = 2; end; a",
      "if true\n  #temp_1 = a = 1\n  a$2 = a\n  #temp_1\nelse\n  #temp_2 = a$1 = 2\n  a$2 = a$1\n  #temp_2\nend\na$2"
  end

  it "performs ssa on if don't assign other vars" do
    assert_normalize "a = 1; if true; b = 1; else; b = 2; end\na",
      "a = 1\nif true\n  #temp_1 = b = 1\n  b$2 = b\n  #temp_1\nelse\n  #temp_2 = b$1 = 2\n  b$2 = b$1\n  #temp_2\nend\na"
  end

  it "performs ssa on if with break" do
    assert_normalize "a = 1; if true; a = 2; else; break; end; a", "a = 1\nif true\n  #temp_1 = a$1 = 2\n  a$2 = a$1\n  #temp_1\nelse\n  a$2 = a\n  break\nend\na$2"
  end

  it "performs ssa on block" do
    assert_normalize "a = 1; foo { a = 2; a = a + 1 }; a = a + 1; a",
      "a = 1\nfoo() do\n  #temp_1 = begin\n    a$1 = 2\n    a$2 = a$1 + 1\n  end\n  a = a$2\n  #temp_1\nend\na$3 = a + 1\na$3"
  end

  it "performs ssa on block with break" do
    assert_normalize "a = 1; foo { a = a + 1; break }; a",
      "a = 1\nfoo() do\n  a$1 = a + 1\n  a = a$1\n  break\nend\na"
  end

  it "performs ssa on block args" do
    assert_normalize "foo { |a| a = a + 1 }",
      "foo() do |a|\n  a$1 = a + 1\nend"
  end

  it "performs ssa on while" do
    assert_normalize "a = 1; a = 2; while a = a.parent; a = a.parent; end; a = a + 1; a",
      "a = 1\na$1 = 2\nwhile a$2 = a$1.parent\n  #temp_1 = a$3 = a$2.parent\n  a$1 = a$3\n  #temp_1\nend\na$4 = a$2 + 1\na$4"
  end

  it "performs ssa on while with +=" do
    assert_normalize "a = 1; while a < 10; a += 1; end; a = a + 1; a",
      "a = 1\nwhile a < 10\n  #temp_1 = a$1 = a + 1\n  a = a$1\n  #temp_1\nend\na$2 = a + 1\na$2"
  end

  it "performs ssa on while inside else" do
    assert_normalize "if true; a = 1; else; while true; end; end",
      "if true\n  #temp_1 = a = 1\n  a$1 = a\n  #temp_1\nelse\n  #temp_2 = while true\n  end\n  a$1 = nil\n  #temp_2\nend"
  end

  ["break", "next"].each do |keyword|
    it "performs ssa on while with #{keyword}" do
      assert_normalize "a = 1; while a < 10; a = a + 1; #{keyword}; end; a",
        "a = 1\nwhile a < 10\n  a$1 = a + 1\n  a = a$1\n  #{keyword}\nend\na"
    end

    it "performs ssa on while with #{keyword} inside if" do
      assert_normalize "a = 1; while a < 10; a = a + 1; if false; #{keyword}; end; end; a",
        "a = 1\nwhile a < 10\n  #temp_1 = begin\n    a$1 = a + 1\n    if false\n      a = a$1\n      #{keyword}\n    end\n  end\n  a = a$1\n  #temp_1\nend\na"
    end

    it "performs ssa on while with #{keyword} inside while" do
      assert_normalize "a = 1; while a < 10; a = a + 1; while true; #{keyword}; end; end; a",
        "a = 1\nwhile a < 10\n  #temp_1 = begin\n    a$1 = a + 1\n    while true\n      #{keyword}\n    end\n  end\n  a = a$1\n  #temp_1\nend\na"
    end

    it "performs ssa on while with #{keyword} inside call with block" do
      assert_normalize "a = 1; while a < 10; a = a + 1; foo { #{keyword} }; end; a",
        "a = 1\nwhile a < 10\n  #temp_1 = begin\n    a$1 = a + 1\n    foo() do\n      #{keyword}\n    end\n  end\n  a = a$1\n  #temp_1\nend\na"
    end

    it "performs ssa on while with #{keyword} inside if altering var afterwards" do
      assert_normalize "a = 1; while a < 10; a = a + 1; if false; #{keyword}; end; a = a + 1; end; a",
        "a = 1\nwhile a < 10\n  #temp_1 = begin\n    a$1 = a + 1\n    if false\n      a = a$1\n      #{keyword}\n    end\n    a$2 = a$1 + 1\n  end\n  a = a$2\n  #temp_1\nend\na"
    end
  end

  it "performs ssa on while with break with variable declared inside else" do
    assert_normalize "while true; if true; break; else; b = 2; end; end",
      "b$2 = nil\nwhile true\n  #temp_2 = if true\n    b$1 = nil\n    b$2 = b$1\n    break\n  else\n    #temp_1 = b = 2\n    b$1 = b\n    #temp_1\n  end\n  b$2 = b$1\n  #temp_2\nend"
  end

  it "performs ssa on simple assignment inside def" do
    assert_normalize "def foo(a); a = 1; end", "def foo(a)\n  a$1 = 1\nend"
  end

  it "performs ssa on constant assignment doesn't affect outside" do
    assert_normalize "A = (a = 1); a = 2", "A = a = 1\na = 2"
  end

  it "performs ssa on out variable" do
    assert_normalize "foo(out a); a = 2", "foo(out a)\na$1 = 2"
  end

  it "doesn't performs ssa on instance variable if not inside def" do
    assert_normalize "@a = 1; @a", "@a = 1\n@a"
  end

  it "performs ssa on instance variable read 1" do
    assert_normalize "def x; @a; end", "def x\n  @a$1 = @a\nend"
  end

  it "performs ssa on instance variable write and read 1" do
    assert_normalize "def x; @a = 1; @a; end", "def x\n  @a = @a$1 = 1\n  @a$1\nend"
  end

  it "performs ssa on instance variable write and read 2" do
    assert_normalize "def x; @a = 1; @a = @a + 1; end", "def x\n  @a = @a$1 = 1\n  @a = @a$2 = @a$1 + 1\nend"
  end

  it "performs ssa on instance variable inside if" do
    assert_normalize "def x; if @a; else; @a = 1; end; @a; end", "def x\n  if @a$1 = @a\n    @a$3 = @a$1\n    nil\n  else\n    #temp_1 = @a = @a$2 = 1\n    @a$3 = @a$2\n    #temp_1\n  end\n  @a$3\nend"
  end

  it "performs ssa on instance variable inside if in initialize" do
    assert_normalize "def initialize; if @a; else; @a = 1; end; @a; end", "def initialize\n  if @a\n    @a = nil\n    nil\n  else\n    @a = 1\n  end\n  @a\nend"
  end

  it "performs ssa on instance variable and method call" do
    assert_normalize "def x; @a = 1; foo; @a; end", "def x\n  @a = @a$1 = 1\n  foo()\n  @a$2 = @a\nend"
  end

  it "performs ssa on instance variable and method call" do
    assert_normalize "def x; @a = 1; yield; @a; end", "def x\n  @a = @a$1 = 1\n  yield\n  @a$2 = @a\nend"
  end

  it "stops ssa if address is taken" do
    assert_normalize "a = 1; x = pointerof(a); a = 2", "a = 1\nx = pointerof(a)\na = 2"
  end

  it "stops ssa if address is taken 2" do
    assert_normalize "a = 1; a = 2; x = pointerof(a); a = 3", "a = 1\na$1 = 2\nx = pointerof(a$1)\na$1 = 3"
  end

  it "performs ssa on var on nested if" do
    assert_normalize "foo = 1; if 0; if 0; foo = 2; else; foo = 3; end; end; foo", "foo = 1\nif 0\n  #temp_3 = if 0\n    #temp_1 = foo$1 = 2\n    foo$3 = foo$1\n    #temp_1\n  else\n    #temp_2 = foo$2 = 3\n    foo$3 = foo$2\n    #temp_2\n  end\n  foo$4 = foo$3\n  #temp_3\nelse\n  foo$4 = foo\n  nil\nend\nfoo$4"
  end

  it "performs ssa on var on nested if 2" do
    assert_normalize "foo = 1; if 0; else; if 0; foo = 2; else; foo = 3; end; end; foo", "foo = 1\nif 0\n  foo$4 = foo\n  nil\nelse\n  #temp_3 = if 0\n    #temp_1 = foo$1 = 2\n    foo$3 = foo$1\n    #temp_1\n  else\n    #temp_2 = foo$2 = 3\n    foo$3 = foo$2\n    #temp_2\n  end\n  foo$4 = foo$3\n  #temp_3\nend\nfoo$4"
  end

  it "performs ssa on while, if, var and break" do
    assert_normalize "a = 1; a = 2; while 1 == 1; if 1 == 2; a = 3; else; break; end; end; puts a", "a = 1\na$1 = 2\nwhile 1 == 1\n  #temp_2 = if 1 == 2\n    #temp_1 = a$2 = 3\n    a$3 = a$2\n    #temp_1\n  else\n    a$3 = a$1\n    a$1 = a$3\n    break\n  end\n  a$1 = a$3\n  #temp_2\nend\nputs(a$1)"
  end

  it "performs ssa on instance var and while" do
    assert_normalize "def x; @foo = 1; while @foo.bar; end; end", "def x\n  @foo = @foo$1 = 1\n  while (@foo$2 = @foo).bar\n  end\nend"
  end

  it "performs on complex while, if, break interaction" do
    assert_normalize "x = false; if 1 == 2; while 1 == 2; if 1 == 2; x = true; break; end; end; end; x", "x = false\nif 1 == 2\n  #temp_2 = while 1 == 2\n    #temp_1 = if 1 == 2\n      x$1 = true\n      x$2 = x$1\n      x = x$2\n      break\n    else\n      x$2 = x\n      nil\n    end\n    x = x$2\n    #temp_1\n  end\n  x$3 = x\n  #temp_2\nelse\n  x$3 = x\n  nil\nend\nx$3"
  end

  it "performs on while which declares a var and uses it outside" do
    assert_normalize "while 1 == 2; a = 2; end; a", "a$1 = nil\nwhile 1 == 2\n  #temp_1 = a = 2\n  a$1 = a\n  #temp_1\nend\na$1"
  end

  it "performs on assignment to variable inside block" do
    assert_normalize "if 1\n  a = 1\nelse\n  foo do\n    a = 2\n  end\n end", "if 1\n  #temp_2 = a = 1\n  a$3 = a\n  #temp_2\nelse\n  #temp_3 = begin\n    a$2 = nil\n    foo() do\n      #temp_1 = a$1 = 2\n      a$2 = a$1\n      #temp_1\n    end\n  end\n  a$3 = a$2\n  #temp_3\nend"
  end
end
