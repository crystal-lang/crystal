require "spec"

describe PrettyPrint do
  assert_hello 0..6, <<-END
    hello
    a
    b
    c
    d
    END

  assert_hello 7..8, <<-END
    hello a
    b
    c
    d
    END

  assert_hello 9..10, <<-END
    hello a b
    c
    d
    END

  assert_hello 11..12, <<-END
      hello a b c
      d
      END

  assert_hello 13..13, <<-END
      hello a b c d
      END

  assert_tree 0..19, <<-END
    aaaa[bbbbb[ccc,
               dd],
         eee,
         ffff[gg,
              hhh,
              ii]]
    END

  assert_tree 20..22, <<-END
    aaaa[bbbbb[ccc, dd],
         eee,
         ffff[gg,
              hhh,
              ii]]
    END

  assert_tree 23..43, <<-END
    aaaa[bbbbb[ccc, dd],
         eee,
         ffff[gg, hhh, ii]]
    END

  assert_tree 44..44, <<-END
    aaaa[bbbbb[ccc, dd], eee, ffff[gg, hhh, ii]]
    END

  assert_tree_alt 0..18, <<-END
    aaaa[
      bbbbb[
        ccc,
        dd
      ],
      eee,
      ffff[
        gg,
        hhh,
        ii
      ]
    ]
    END

  assert_tree_alt 19..20, <<-END
    aaaa[
      bbbbb[ ccc, dd ],
      eee,
      ffff[
        gg,
        hhh,
        ii
      ]
    ]
    END

  assert_tree_alt 21..49, <<-END
    aaaa[
      bbbbb[ ccc, dd ],
      eee,
      ffff[ gg, hhh, ii ]
    ]
    END

  assert_tree_alt 50..50, <<-END
    aaaa[ bbbbb[ ccc, dd ], eee, ffff[ gg, hhh, ii ] ]
    END

  assert_strict_pretty 0..4, <<-END
    if
      a
        ==
        b
    then
      a
        <<
        2
    else
      a
        +
        b
    END

  assert_strict_pretty 5..5, <<-END
    if
      a
        ==
        b
    then
      a
        <<
        2
    else
      a +
        b
    END

  assert_strict_pretty 6..6, <<-END
    if
      a ==
        b
    then
      a <<
        2
    else
      a +
        b
    END

  assert_strict_pretty 7..7, <<-END
    if
      a ==
        b
    then
      a <<
        2
    else
      a + b
    END

  assert_strict_pretty 8..8, <<-END
    if
      a == b
    then
      a << 2
    else
      a + b
    END

  assert_strict_pretty 9..9, <<-END
    if a == b
    then
      a << 2
    else
      a + b
    END

  assert_strict_pretty 10..10, <<-END
    if a == b
    then
      a << 2
    else a + b
    END

  assert_strict_pretty 11..31, <<-END
    if a == b
    then a << 2
    else a + b
    END

  assert_strict_pretty 32..32, <<-END
    if a == b then a << 2 else a + b
    END

  assert_fill 0..6, <<-END
    abc
    def
    ghi
    jkl
    mno
    pqr
    stu
    END

  assert_fill 7..10, <<-END
    abc def
    ghi jkl
    mno pqr
    stu
    END

  assert_fill 11..14, <<-END
    abc def ghi
    jkl mno pqr
    stu
    END

  assert_fill 15..18, <<-END
    abc def ghi jkl
    mno pqr stu
    END

  assert_fill 19..22, <<-END
    abc def ghi jkl mno
    pqr stu
    END

  assert_fill 23..26, <<-END
    abc def ghi jkl mno pqr
    stu
    END

  assert_fill 27..27, <<-END
    abc def ghi jkl mno pqr stu
    END

  it "tail group" do
    text = String.build { |io|
      PrettyPrint.format(io, 10) { |q|
        q.group {
          q.group {
            q.text "abc"
            q.breakable
            q.text "def"
          }
          q.group {
            q.text "ghi"
            q.breakable
            q.text "jkl"
          }
        }
      }
    }
    text.should eq("abc defghi\njkl")
  end
end

private class Tree
  @children : Array(Tree)

  def initialize(@string : String)
    @children = [] of Tree
  end

  def initialize(@string : String, *children)
    @children = children.to_a
  end

  def show(q)
    q.group {
      q.text @string
      q.nest(@string.size) {
        unless @children.empty?
          q.text '['
          q.nest(1) {
            first = true
            @children.each { |t|
              if first
                first = false
              else
                q.text ','
                q.breakable
              end
              t.show(q)
            }
          }
          q.text ']'
        end
      }
    }
  end

  def altshow(q)
    q.group {
      q.text @string
      unless @children.empty?
        q.text '['
        q.nest(2) {
          q.breakable
          first = true
          @children.each { |t|
            if first
              first = false
            else
              q.text ','
              q.breakable
            end
            t.altshow(q)
          }
        }
        q.breakable
        q.text ']'
      end
    }
  end
end

private def tree
  Tree.new("aaaa",
    Tree.new("bbbbb",
      Tree.new("ccc"),
      Tree.new("dd")),
    Tree.new("eee"),
    Tree.new("ffff",
      Tree.new("gg"),
      Tree.new("hhh"),
      Tree.new("ii")))
end

private def tree(width)
  String.build { |io|
    PrettyPrint.format(io, width) { |q| tree.show(q) }
  }
end

private def tree_alt(width)
  String.build { |io|
    PrettyPrint.format(io, width) { |q| tree.altshow(q) }
  }
end

private def hello(width)
  String.build { |io|
    PrettyPrint.format(io, width) { |hello|
      hello.group {
        hello.group {
          hello.group {
            hello.group {
              hello.text "hello"
              hello.breakable; hello.text "a"
            }
            hello.breakable; hello.text "b"
          }
          hello.breakable; hello.text "c"
        }
        hello.breakable; hello.text "d"
      }
    }
  }
end

private def stritc_pretty(width)
  String.build do |io|
    PrettyPrint.format(io, width) { |q|
      q.group {
        q.group { q.nest(2) {
          q.text "if"; q.breakable
          q.group {
            q.nest(2) {
              q.group { q.text "a"; q.breakable; q.text "==" }
              q.breakable; q.text "b"
            }
          }
        } }
        q.breakable
        q.group { q.nest(2) {
          q.text "then"; q.breakable
          q.group {
            q.nest(2) {
              q.group { q.text "a"; q.breakable; q.text "<<" }
              q.breakable; q.text "2"
            }
          }
        } }
        q.breakable
        q.group { q.nest(2) {
          q.text "else"; q.breakable
          q.group {
            q.nest(2) {
              q.group { q.text "a"; q.breakable; q.text "+" }
              q.breakable; q.text "b"
            }
          }
        } }
      }
    }
  end
end

private def fill(width)
  String.build { |io|
    PrettyPrint.format(io, width) { |q|
      q.group {
        q.text "abc"
        q.fill_breakable
        q.text "def"
        q.fill_breakable
        q.text "ghi"
        q.fill_breakable
        q.text "jkl"
        q.fill_breakable
        q.text "mno"
        q.fill_breakable
        q.text "pqr"
        q.fill_breakable
        q.text "stu"
      }
    }
  }
end

private def assert_hello(range, expected)
  it "pretty prints hello #{range}" do
    range.each do |width|
      hello(width).should eq(expected)
    end
  end
end

private def assert_tree(range, expected)
  it "pretty prints tree #{range}" do
    range.each do |width|
      tree(width).should eq(expected)
    end
  end
end

private def assert_tree_alt(range, expected)
  it "pretty prints tree alt #{range}" do
    range.each do |width|
      tree_alt(width).should eq(expected)
    end
  end
end

private def assert_strict_pretty(range, expected)
  it "pretty prints strict pretty #{range}" do
    range.each do |width|
      stritc_pretty(width).should eq(expected)
    end
  end
end

private def assert_fill(range, expected)
  it "pretty prints fill #{range}" do
    range.each do |width|
      fill(width).should eq(expected)
    end
  end
end
