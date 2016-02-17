class Matrix(T)
  include Enumerable(T)
  include Iterable

  macro def_exception(name, message)
    class {{name.id}} < Exception
      def initialize(msg = {{message}})
        super(msg)
      end
    end
  end

  macro def_operators(*operators)
    {% for operator in operators %}
      def {{operator.id}}(other : T | Number)
        map { |e| e {{operator.id}} other }
      end
    {% end %}
  end

  def_exception "DimensionMismatch", "Matrix dimension mismatch"
  def_exception "NotRegular", "Non-regular Matrix"

  def_operators :+, :-, :*, :/, :^, :>>, :<<, :|, :&

  def initialize(@rows : Int, @columns : Int)
    @buffer = Pointer(T).malloc(size)
  end

  def initialize(@rows : Int, @columns : Int, value : T)
    @buffer = Pointer(T).malloc(size, value)
  end

  # Creates a matrix with the given number of rows and columns. It yields the
  # linear, row and column indexes in that order.
  def self.new(rows : Int, columns : Int, &block : Int32, Int32, Int32 -> T)
    matrix = Matrix(T).new(rows, columns)
    r, c = 0, 0
    matrix.size.times do |i|
      matrix[i] = yield i, r, c
      c += 1
      if r == rows
        c += 1
        r = 0
      end
      if c == columns
        r += 1
        c = 0
      end
    end
    matrix
  end

  # Creates a matrix interpreting each argument as a row.
  def self.rows(rows : Array(Array) | Tuple)
    if rows.any? { |row| row.size != rows[0].size }
      raise NotRegular.new
    end
    Matrix.new(rows.size, rows.first.size) do |i, r, c|
      rows[r][c]
    end
  end

  # Creates a matrix interpreting each argument as a column.
  def self.columns(columns : Array(Array) | Tuple)
    if columns.any? { |column| column.size != columns[0].size }
      raise NotRegular.new
    end
    Matrix.new(columns.first.size, columns.size) do |i, r, c|
      columns[c][r]
    end
  end

  # Creates a diagonal matrix with the supplied arguments. Best suited to
  # numeric matrices.
  def self.diagonal(*values)
    matrix = Matrix(T).new(values.size, values.size)
    values.each_with_index do |e, i|
      matrix[i, i] = e
    end
    matrix
  end

  # Creates a Matrix(Int32), whose diagonal values are 1 and the rest are 0.
  def self.identity(row_or_col_size : Int)
    Matrix.new(row_or_col_size, row_or_col_size) do |i, r, c|
      r == c ? 1 : 0
    end
  end

  # Creates a single row matrix with the given values.
  def self.row(*values)
    Matrix.new(1, values.size) do |i|
      values[i]
    end
  end

  # Creates a single column matrix with the given values.
  def self.column(*values)
    Matrix.new(values.size, 1) do |i|
      values[i]
    end
  end

  # Alias for Matrix.rows.
  def self.[](*rows)
    rows(rows)
  end

  # Retrieves the element at the given row and column indexes.
  # Raises IndexError.
  def [](row : Int, column : Int)
    at(row, column)
  end

  # Retrieves the element at the given row and column indexes.
  # Returns nil if out of bounds.
  def []?(row : Int, column : Int)
    at(row, column) { nil }
  end

  # Replaces the element at the given row and column with the given value.
  def []=(row : Int, column : Int, value : T)
    raise IndexError.new if row >= @rows || column >= @columns
    row += @rows if row < 0
    column += @columns if column < 0
    raise IndexError.new unless 0 <= row && 0 <= column
    @buffer[column + (row * @columns)] = value
  end

  # Retrieves the element at the given linear index. Raises IndexError.
  def [](index : Int)
    at(index)
  end

  # Retrieves the element at the given linear index. Returns nil if out of
  # bounds
  def []?(index : Int)
    at(index) { nil }
  end

  # Replaces the element at the given linear index with the given value.
  def []=(index : Int, value : T)
    raise IndexError.new if index >= size
    index += size if index < 0
    raise IndexError.new if index < 0
    @buffer[index] = value
  end

  # Retrieves the element at the given row and column indexes.
  # Yields if out of bounds.
  def at(row : Int, column : Int)
    column += @columns if column < 0
    row += @rows if row < 0
    if row >= @rows || column >= @columns || row < 0 || column < 0
      yield
    else
      @buffer[column + (row * @columns)]
    end
  end

  # Retrieves the element at the given row and column indexes.
  # Raises IndexError.
  def at(row : Int, column : Int)
    at(row, column) { raise IndexError.new }
  end

  # Retrieves the element at the given linear index.
  # Yields if out of bounds.
  def at(index : Int)
    index += size if index < 0
    if index >= size || index < 0
      yield
    else
      @buffer[index]
    end
  end

  # Retrieves the element at the given linear index.
  # Raises if out of bounds.
  def at(index : Int)
    at(index) { raise IndexError.new }
  end

  # Checks equality between self and another matrix.
  def ==(other : Matrix)
    return false unless dimensions == other.dimensions
    size.times do |i|
      return false unless at(i) == other[i]
    end
    true
  end

  # Returns a new matrix of the same size after calling the unary #- method
  # on every element. Best suited to numeric matrices.
  def -
    map { |e| -e }
  end

  # Performs addition with another matrix.
  def +(other : Matrix)
    raise DimensionMismatch.new unless dimensions == other.dimensions
    Matrix.new(@rows, @columns) do |i|
      at(i) + other[i]
    end
  end

  # Performs subtraction with another matrix.
  def -(other : Matrix)
    raise DimensionMismatch.new unless dimensions == other.dimensions
    Matrix.new(@rows, @columns) do |i|
      at(i) - other[i]
    end
  end

  # Performs multiplication with another matrix.
  def *(other : Matrix)
    raise DimensionMismatch.new unless @columns == other.row_count
    new_row_count, new_column_count = @rows, other.column_count
    matrix = Matrix(typeof(self[0] * other[0])).new(new_row_count, new_column_count)
    pos = -1
    @rows.times do |i|
      other.column_count.times do |j|
        matrix[pos += 1] = typeof(self[0] * other[0]).new((0...@columns).reduce(0) do |memo, k|
          memo + at(i, k) * other[k, j]
        end)
      end
    end
    matrix
  end

  # Performs exponentiation
  def **(other : Int)
    m = self
    if other == 0
      Matrix.identity(@columns)
    elsif other < 0
      (other.abs - 1).times { m *= self }
      m.inverse
    elsif other == 1
      clone
    else
      (other - 1).times { m *= self }
      m
    end
  end

  # Performs division with another matrix.
  def /(other : Matrix)
    self * other.inverse
  end

  # Yields every element of the matrix linearly: First the elements of the first
  # row, then the elements of the second row, etc.
  def each
    size.times { |i| yield at(i) }
    self
  end

  # Like #each but with a Symbol directive that causes the method to skip
  # certain indices:
  #   :all            -> equivalent to a simple #each (yields every element)
  #   :diagonal       -> yields elements in the diagonal
  #   :off_diagonal   -> yields elements not in the diagonal
  #   :lower          -> yields elements at or below the diagonal
  #   :strict_lower   -> yields elements below the diagonal
  #   :upper          -> yields elements at or above the diagonal
  #   :strict_upper   -> yields elements above the diagonal
  def each(which : Symbol)
    case which
    when :all
      each { |e| yield e }
    when :diagonal
      each_with_index do |e, r, c|
        yield e if r == c
      end
    when :off_diagonal
      each_with_index do |e, r, c|
        yield e if r != c
      end
    when :lower
      each_with_index do |e, r, c|
        yield e if r >= c
      end
    when :strict_lower
      each_with_index do |e, r, c|
        yield e if r > c
      end
    when :upper
      each_with_index do |e, r, c|
        yield e if r <= c
      end
    when :strict_upper
      each_with_index do |e, r, c|
        yield e if r < c
      end
    else
      raise ArgumentError.new
    end
  end

  def each(which = :all : Symbol)
    ItemIterator.new(self, directive: which)
  end

  # Yields every element along with its row and column index.
  # See #each for the optional directives.
  def each_with_index(which = :all : Symbol)
    r, c = 0, 0
    each do |e|
      case which
      when :all          then yield e, r, c
      when :diagonal     then yield e, r, c if r == c
      when :off_diagonal then yield e, r, c if r != c
      when :lower        then yield e, r, c if r >= c
      when :strict_lower then yield e, r, c if r > c
      when :upper        then yield e, r, c if r <= c
      when :strict_upper then yield e, r, c if r < c
      else                    raise ArgumentError.new
      end
      c += 1
      if r == @rows
        c += 1
        r = 0
      end
      if c == @columns
        r += 1
        c = 0
      end
    end
  end

  # Yields every row and column index.
  # See #each for the optional directives.
  def each_index(which = :all : Symbol)
    each_with_index(which) { |e, r, c| yield r, c }
  end

  def each_index(which = :all : Symbol)
    IndexIterator.new(self, directive: which)
  end

  def cycle(which = :all : Symbol)
    each(which).cycle
  end

  # Returns a new matrix with the return values of the block.
  # Yields the element and its linear, row and column indices in that order.
  def map
    Matrix.new(@rows, @columns) do |i, r, c|
      yield at(i), i, r, c
    end
  end

  # Changes the values of the matrix according to the return values of the
  # block.
  # Yields the element and its linear, row and column indices in that order.
  def map!(&block : T, Int32, Int32, Int32 -> _)
    i = 0
    each_with_index do |e, r, c|
      self[i] = yield e, i, r, c
      i += 1
    end
  end

  # Returns the row and column index of the first occurrence of "value" in
  # the matrix, nil otherwise.
  def index(value : T, which = :all : Symbol)
    each_with_index(which) do |e, r, c|
      return {r, c} if e == value
    end
    nil
  end

  # Returns the row and column index of the first occurrence of the block
  # returning true, nil otherwise
  def index(&block : T, Int32, Int32, Int32 -> Bool)
    i = 0
    each_with_index do |e, r, c|
      return {r, c} if yield e, i, r, c
      i += 1
    end
    nil
  end

  # Returns an iterator for the elements of the row at the given index.
  def row(row_index : Int)
    raise IndexError.new if row_index >= @rows
    row_index += @rows if row_index < 0
    raise IndexError.new if row_index < 0
    RowIterator.new(self, row_index)
  end

  # Yields elements of the row at the given index.
  def row(index : Int)
    raise IndexError.new if index >= @rows
    index += @rows if index < 0
    raise IndexError.new if index < 0
    @columns.times { |i| yield at(index, i) }
    self
  end

  # Returns an array of arrays that correspond to the rows of the matrix.
  def rows
    Array.new(@rows) { |i| row(i).to_a }
  end

  # Returns an iterator for the elements of the column at the given index.
  def column(column_index : Int)
    raise IndexError.new if column_index >= @columns
    column_index += @columns if column_index < 0
    raise IndexError.new if column_index < 0
    ColumnIterator.new(self, 0, column_index)
  end

  # Yields elements of the column at the given index.
  def column(index : Int)
    raise IndexError.new if index >= @columns
    index += @columns if index < 0
    raise IndexError.new if index < 0
    @rows.times { |i| yield at(i, index) }
    self
  end

  # Returns an array of arrays that correspond to the columns of the matrix.
  def columns
    Array.new(@columns) { |i| column(i).to_a }
  end

  # The number of columns.
  def column_count
    @columns
  end

  # The number of rows.
  def row_count
    @rows
  end

  # The total number of elements.
  def size
    @rows * @columns
  end

  # Returns true if all non-diagonal elements are 0.
  def diagonal?
    raise DimensionMismatch.new unless square?
    each(:off_diagonal) do |e|
      return false unless e == 0
    end
    true
  end

  def dimensions
    {@rows, @columns}
  end

  # Returns true if the matrix has either 0 rows or 0 columns.
  def empty?
    @columns == 0 || @rows == 0
  end

  # Returns true if the matrix is a lower triangular matrix.
  def lower_triangular?
    raise DimensionMismatch.new unless square?
    each(:strict_upper) do |e|
      return false unless e == 0
    end
    true
  end

  # Returns true if the matrix is an upper triangular matrix.
  def upper_triangular?
    raise DimensionMismatch.new unless square?
    each(:strict_lower) do |e|
      return false unless e == 0
    end
    true
  end

  # Returns true if the matrix is a permutation matrix.
  def permutation?
    raise DimensionMismatch.new unless square?
    @rows.times do |i|
      found = 0
      row(i) do |e|
        case e
        when 0 then next
        when 1 then found += 1
        else        return false
        end
      end
      return false unless found == 1
      found = 0
      column(i) do |e|
        case e
        when 0 then next
        when 1 then found += 1
        else        return false
        end
      end
      return false unless found == 1
    end
    true
  end

  # Returns true if the matrix is regular.
  def regular?
    !singular?
  end

  # Returns true if the matrix is singular.
  def singular?
    determinant == 0
  end

  # Returns true if the number of rows equals the number of columns.
  def square?
    @rows == @columns
  end

  # Returns true if the matrix is symmetric.
  def symmetric?
    raise DimensionMismatch.new unless square?
    each_with_index(:strict_upper) do |e, r, c|
      return false unless e == at(c, r)
    end
    true
  end

  # Returns an array of smaller matrices, each representing a row from self.
  def row_vectors
    Array.new(@rows) { |i| minor(i, 1, 0, @columns) }
  end

  # Returns an array of smaller matrices, each representing a column from self.
  def column_vectors
    Array.new(@columns) { |i| minor(0, @rows, i, 1) }
  end

  # Returns a subsection of the matrix.
  def minor(start_row : Int, rows : Int, start_col : Int, columns : Int)
    raise DimensionMismatch.new if rows < 0 || columns < 0
    raise IndexError.new if start_row + rows > @rows
    raise IndexError.new if start_col + columns > @columns

    start_row += @rows if start_row < 0
    start_col += @columns if start_col < 0

    raise IndexError.new if start_row < 0
    raise IndexError.new if start_col < 0

    matrix = Matrix(T).new(rows, columns)

    matrix.each_index do |r, c|
      min_r = start_row - r + rows - 1
      min_c = start_col - c + columns - 1
      i = -1 - ((c + (r * columns)) - (rows * columns))
      matrix[i] = at(min_r, min_c)
    end

    matrix
  end

  # Returns a subsection of the matrix.
  def minor(row_range : Range(Int, Int), col_range : Range(Int, Int))
    start_row, rows = row_range.begin, row_range.end
    start_col, columns = col_range.begin, col_range.end
    rows += 1 unless row_range.excludes_end?
    columns += 1 unless col_range.excludes_end?
    minor(start_row, rows, start_col, columns)
  end

  # Returns the determinant of the matrix. Only useful for numeric matrices.
  def determinant
    raise DimensionMismatch.new unless square?
    case @rows
    when 0
      1
    when 1
      at(0)
    when 2
      at(0) * at(3) - at(1) * at(2)
    when 3
      at(0) * at(4) * at(8) - at(0) * at(5) * at(7) -
        at(1) * at(3) * at(8) + at(1) * at(5) * at(6) +
        at(2) * at(3) * at(7) - at(2) * at(4) * at(6)
    when 4
      at(0) * at(5) * at(10) * at(15) - at(0) * at(5) * at(11) * at(14) -
        at(0) * at(6) * at(9) * at(15) + at(0) * at(6) * at(11) * at(13) +
        at(0) * at(7) * at(9) * at(14) - at(0) * at(7) * at(10) * at(13) -
        at(1) * at(4) * at(10) * at(15) + at(1) * at(4) * at(11) * at(14) +
        at(1) * at(6) * at(8) * at(15) - at(1) * at(6) * at(11) * at(12) -
        at(1) * at(7) * at(8) * at(14) + at(1) * at(7) * at(10) * at(12) +
        at(2) * at(4) * at(9) * at(15) - at(2) * at(4) * at(11) * at(13) -
        at(2) * at(5) * at(8) * at(15) + at(2) * at(5) * at(11) * at(12) +
        at(2) * at(7) * at(8) * at(13) - at(2) * at(7) * at(9) * at(12) -
        at(3) * at(4) * at(9) * at(14) + at(3) * at(4) * at(10) * at(13) +
        at(3) * at(5) * at(8) * at(14) - at(3) * at(5) * at(10) * at(12) -
        at(3) * at(6) * at(8) * at(13) + at(3) * at(6) * at(9) * at(12)
    else
      m = clone
      last = @rows - 1
      sign = 1
      pivot = 1
      @rows.times do |k|
        previous_pivot = pivot
        if (pivot = m[k, k]) == 0
          switch = ((k + 1)...@rows).find(0) do |row|
            m[row, k] != 0
          end
          m.swap_rows(switch, k)
          pivot = m[k, k]
          sign = -sign
        end
        (k + 1).upto(last) do |i|
          (k + 1).upto(last) do |j|
            m[i, j] = (pivot * m[i, j] - m[i, k] * m[k, j]) / previous_pivot
          end
        end
      end
      sign * pivot
    end
  end

  # Returns the inverse of the matrix. Only useful for numeric matrices.
  def inverse
    raise DimensionMismatch.new unless square?
    last = @rows - 1
    a = Matrix.new(@rows, @columns) { |i| at(i).to_f }
    m = Matrix.new(@rows, @columns) { |i, r, c| r == c ? 1.0 : 0.0 }

    0.upto(last) do |k|
      i = k
      akk = a[k, k].abs
      (k + 1).upto(last) do |j|
        v = a[j, k].abs
        if v > akk
          i = j
          akk = v
        end
      end
      raise NotRegular.new if akk == 0
      if i != k
        a.swap_rows(i, k)
        m.swap_rows(i, k)
      end
      akk = a[k, k]
      0.upto(last) do |ii|
        next if ii == k
        q = a[ii, k] / akk
        a[ii, k] = 0.0
        (k + 1).upto(last) do |j|
          a[ii, j] -= a[k, j] * q
        end
        0.upto(last) { |j| m[ii, j] -= m[k, j] * q }
      end
      (k + 1).upto(last) { |j| a[k, j] = a[k, j] / akk }
      0.upto(last) { |j| m[k, j] = m[k, j] / akk }
    end
    m
  end

  # Returns the rank of the matrix. Only useful for numeric matrices.
  def rank
    m = clone
    pivot_row = 0
    prev_piv = 1
    0.upto(@columns - 1) do |k|
      switch_row = (pivot_row...@rows).find do |row|
        m[row, k] != 0
      end
      if switch_row
        unless pivot_row == switch_row
          m.swap_rows(switch_row, pivot_row)
        end
        pivot = m[pivot_row, k]
        (pivot_row + 1).upto(@rows - 1) do |i|
          (k + 1).upto(@columns - 1) do |j|
            m[i, j] = (pivot * m[i, j] - m[i, k] * m[pivot_row, j]) / prev_piv
          end
        end
        pivot_row += 1
        prev_piv = pivot
      end
    end
    pivot_row
  end

  # Returns the sum of the diagonal elements. Only useful for numeric matrices.
  def trace
    raise DimensionMismatch.new unless square?
    (0...@columns).reduce(0) do |memo, i|
      memo + at(i, i)
    end
  end

  # Changes the rows into columns and vice versa.
  def transpose!
    first = 0
    while first <= @columns * @rows - 1
      succ = first
      i = 0
      loop do
        i += 1
        succ = (succ % @rows) * @columns + succ / @rows
        break if succ <= first
      end
      unless i == 1 || succ < first
        temp = at(succ = first)
        loop do
          i = (succ % @rows) * @columns + succ / @rows
          self[succ] = i == first ? temp : at(i)
          succ = i
          break if succ <= first
        end
      end
      first += 1
    end
    @rows, @columns = @columns, @rows
    self
  end

  def transpose
    clone.transpose!
  end

  # Reverses the order of the matrix.
  def reverse!
    i = 0
    j = size - 1
    while i < j
      @buffer.swap i, j
      i += 1
      j -= 1
    end
    self
  end

  def reverse
    clone.reverse!
  end

  # Shuffles the elements of the matrix.
  def shuffle!
    @buffer.shuffle!(size)
    self
  end

  def shuffle
    clone.shuffle!
  end

  # Shuffles the elements of each row.
  def shuffle_rows!
    @rows.times do |i|
      (@buffer + (i * @rows)).shuffle!(@columns)
    end
    self
  end

  def shuffle_rows
    clone.shuffle_rows!
  end

  # Shuffles the elements of each column.
  def shuffle_columns!
    transpose!
    shuffle_rows!
    transpose!
  end

  def shuffle_columns
    clone.shuffle_columns!
  end

  # Swaps two rows.
  def swap_rows(row_1 : Int, row_2 : Int)
    raise IndexError.new if row_1 >= @rows || row_2 >= @rows
    row_1 += @rows if row_1 < 0
    row_2 += @rows if row_2 < 0
    raise IndexError.new if row_1 < 0 || row_2 < 0
    @columns.times do |i|
      self[row_1, i], self[row_2, i] = at(row_2, i), at(row_1, i)
    end
    self
  end

  # Swaps two columns.
  def swap_columns(col_1 : Int, col_2 : Int)
    raise IndexError.new if col_1 >= @columns || col_2 >= @columns
    col_1 += @columns if col_1 < 0
    col_2 += @columns if col_2 < 0
    aise IndexError.new if col_1 < 0 || col_2 < 0
    @rows.times do |i|
      self[i, col_1], self[i, col_2] = at(i, col_2), at(i, col_1)
    end
    self
  end

  # Creates an identical matrix.
  def clone
    Matrix.new(@rows, @columns) do |i|
      at(i).clone
    end
  end

  def hash
    reduce(31 * @rows * @columns) do |memo, e|
      31 * memo + e.hash
    end
  end

  # Returns an array of every element in the matrix.
  def to_a
    Array.new(size) { |i| at(i) }
  end

  # Returns a hash: {row_index, column_index} => element
  def to_h
    hash = {} of {Int32, Int32} => T
    each_with_index do |e, r, c|
      hash[{r, c}] = e
    end
    hash
  end

  # Displays the matrix in a more readable form.
  def to_s(io : IO)
    if @rows == 1
      io << '['
      each_with_index do |e, r, c|
        e.inspect(io)
        io << ' ' unless c == @columns - 1
      end
      io << ']'
    else
      max_size = max_of &.inspect.size
      io << '┌'
      corner = true
      @rows.times do |t|
        io << '│' unless corner || t == @rows - 1
        io << '└' if t == @rows - 1
        i = 0
        row(t) do |e|
          size = e.inspect.size
          (max_size - size).times { io << ' ' }
          e.inspect(io)
          io << ' ' unless i == @columns - 1
          io << '│' if i == @columns - 1 && !corner && t != @rows - 1
          i += 1
        end
        io << '┐' if t == 0
        io << '┘' if t == @rows - 1
        io << '\n' unless t == @rows - 1
        corner = false
      end
    end
  end

  def inspect(io : IO)
    io << 'M' << 'a' << 't' << 'r' << 'i' << 'x' << '['
    @rows.times do |t|
      io << '['
      i = 0
      row(t) do |e|
        e.inspect(io)
        io << ',' << ' ' unless i == @columns - 1
        i += 1
      end
      io << ']'
      io << ',' << ' ' unless t == @rows - 1
    end
    io << ']'
  end

  class ItemIterator(T)
    include Iterator(T)

    def initialize(@matrix : Matrix(T), @row = 0, @col = 0, @directive = :all)
    end

    def next
      skip = case @directive
             when :all          then false
             when :diagonal     then @row != @col
             when :off_diagonal then @row == @col
             when :lower        then @row < @col
             when :strict_lower then @row <= @col
             when :upper        then @row > @col
             when :strict_upper then @row >= @col
             else                    raise ArgumentError.new
             end

      no_more_rows? = @row + 1 >= @matrix.row_count
      no_more_cols? = @col + 1 >= @matrix.column_count

      if no_more_rows? && no_more_cols?
        value = @matrix.at(@row, @col) { return stop }
        @col += 1
      elsif !no_more_rows? && no_more_cols?
        value = @matrix[@row, @col]
        @col = 0
        @row += 1
      else
        value = @matrix[@row, @col]
        @col += 1
      end

      skip ? self.next : value
    end

    def rewind
      @row, @col = 0, 0
      self
    end
  end

  # :nodoc:
  class IndexIterator(T)
    include Iterator({Int32, Int32})

    def initialize(@matrix : Matrix(T), @row = 0, @col = 0, @directive = :all)
    end

    def next
      skip = case @directive
             when :all          then false
             when :diagonal     then @row != @col
             when :off_diagonal then @row == @col
             when :lower        then @row < @col
             when :strict_lower then @row <= @col
             when :upper        then @row > @col
             when :strict_upper then @row >= @col
             else                    raise ArgumentError.new
             end

      value = {@row, @col}
      no_more_rows? = @row + 1 >= @matrix.row_count
      no_more_cols? = @col + 1 >= @matrix.column_count
      if no_more_rows? && no_more_cols?
        return stop if @col == @matrix.column_count
        @col += 1
      elsif !no_more_rows? && no_more_cols?
        @col = 0
        @row += 1
      else
        @col += 1
      end

      skip ? self.next : value
    end

    def rewind
      @row, @col = 0, 0
      self
    end
  end

  # :nodoc:
  class RowIterator(T)
    include Iterator(T)

    def initialize(@matrix : Matrix(T), @row = 0, @col = 0)
    end

    def next
      return stop if @col >= @matrix.column_count
      value = @matrix[@row, @col]
      @col += 1
      value
    end

    def rewind
      @col = 0
      self
    end
  end

  # :nodoc:
  class ColumnIterator(T)
    include Iterator(T)

    def initialize(@matrix : Matrix(T), @row = 0, @col = 0)
    end

    def next
      return stop if @row >= @matrix.row_count
      value = @matrix[@row, @col]
      @row += 1
      value
    end

    def rewind
      @row = 0
      self
    end
  end
end
