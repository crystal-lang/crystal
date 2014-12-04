# Macro methods

Just like `id`, you can invoke some other methods on AST nodes. The list here is fixed: you can't define your own macro methods.

``` ruby
class ASTNode
  # Returns a MacroId node with the *contents* of the node.
  # For a SymbolLiteral, this is the symbol name without
  # the colon.
  # For a StringLiteral, this is the string's contents
  # without the quotes.
  # For other nodes, it's just their string representation.
  def id; end

  # Returns a StringLiteral whose value is the
  # node's string representation.
  #
  #    (1 + 2).stringify #=> "1 + 2"
  def stringify; end

  # Returns a BoolLiteral whose value is true if this node
  # is equal to the other node
  def ==(other); end

  # Returns a BoolLiteral whose value is true if this node
  # is not equal to the other node
  def !=(other); end

  # Returns a BoolLiteral that is true when this ASTNode
  # is truthy. Falsey AST nodes are just NilLiteral or
  # a BoolLiteral with a false value: every other ASTNode
  # is truthy.
  def !; end
end

class ArrayLiteral < ASTNode
  # Similar to Array#[]
  def []; end

  # Similar to Enumerable#any?
  def any?(&block); end

  # Similar to Enumerable#all?
  def all?(&block); end

  # Returns a MacroId with the array literal's content
  # joined with ", "
  #
  #    [1, 2, 3].argify #=> 1, 2, 3
  def argify; end

  # Similar to Array#empty?
  def empty?; end

  # Similar to Array#first, but returns a NilLiteral
  # if the array literal is empty
  def first; end

  # Similar to Array#join(joiner)
  def join(joiner); end

  # Similar to Array#last, but returns a NilLiteral
  # if the array literal is empty
  def last; end

  def length; end

  # Similar to Array#map
  def map(&block); end

  # Similar to Array#select
  def select(&block); end
end

class HashLiteral < ASTNode
  # Similar to Hash#[], but returns NilLiteral
  # if the key is not found.
  def []; end

  # Similar to Hash#empty?
  def empty?; end

  def length; end
end

class NumberLiteral < ASTNode
  def >(other : NumberLiteral); end
  def >=(other : NumberLiteral); end
  def <(other : NumberLiteral); end
  def <=(other : NumberLiteral); end
end

class StringLiteral < ASTNode
  # Returns a StringLiteral with a substring of this
  # node's value
  def [](RangeLiteral); end

  def capitalize; end
  def downcase; end
  def empty?; end

  # Returns a StringLiteral
  # with all "::" replaced by "_"
  def identify; end

  def length; end

  # Similar to String#lines,
  # but returns an ArrayLiteral of StringLiteral
  def lines; end

  # Similar to String#split(divider),
  # but returns an ArrayLiteral of StringLiteral.
  def split(divider); end

  def strip; end
  def upcase; end
end

class TupleLiteral < ASTNode
  # Similar to Tuple#[], but returns NilLiteral
  # if the key is not found.
  def []; end

  # Similar to Tuple#empty?
  def empty?; end

  def length; end
end
```
