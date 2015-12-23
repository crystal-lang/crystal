require "matrix"
require "spec"

describe Matrix do
  describe "Matrix.rows" do
    it "creates a matrix with the args as an array/tuple of rows (1)" do
      m = Matrix.rows([[1, 2], [3, 4], [5, 6]])
      m.to_a.should eq([1, 2, 3, 4, 5, 6])
    end

    it "creates a matrix with the args as an array/tuple of rows (2)" do
      m = Matrix.rows([['1', '2', '3', '4'], ['5', '6', '7', '8']])
      m.to_a.should eq(['1', '2', '3', '4', '5', '6', '7', '8'])
    end

    it "raises when given rows of different size" do
      expect_raises Matrix::NotRegular do
        Matrix.rows([[1, 2], [3, 4, 5]])
      end
    end
  end

  describe "Matrix.columns" do
    it "creates a matrix with the args as an array/tuple of columns (1)" do
      m = Matrix.columns([[1, 2], [3, 4], [5, 6]])
      m.to_a.should eq([1, 3, 5, 2, 4, 6])
    end

    it "creates a matrix with the args as an array/tuple of columns (2)" do
      m = Matrix.columns([['1', '2', '3', '4'], ['5', '6', '7', '8']])
      m.to_a.should eq(['1', '5', '2', '6', '3', '7', '4', '8'])
    end

    it "raises when given rows of different size" do
      expect_raises Matrix::NotRegular do
        Matrix.columns([[1, 2], [3, 4, 5]])
      end
    end
  end

  describe "Matrix.diagonal" do
    it "creates a square matrix where args are the diagonal values" do
      m = Matrix(Int32).diagonal(1, 2, 3)
      m.rows.should eq([[1, 0, 0], [0, 2, 0], [0, 0, 3]])
    end
  end

  describe "Matrix.identity" do
    it "creates a matrix whose diagonal elements are 1 and the rest are 0" do
      m = Matrix.identity(3)
      m.rows.should eq([[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    end
  end

  describe "Matrix.row" do
    it "creates a single row matrix" do
      m = Matrix.row(1, 2, 3, 4)
      m.rows.should eq([[1, 2, 3, 4]])
    end
  end

  describe "Matrix.column" do
    it "creates a single column matrix" do
      m = Matrix.column(1, 2, 3, 4)
      m.columns.should eq([[1, 2, 3, 4]])
    end
  end

  describe "Matrix.[]" do
    it "creates a matrix with each arg as a row" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.rows.should eq([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    end

    it "works with tuples" do
      m = Matrix[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      m.rows.should eq([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    end

    it "raises when given rows of different size" do
      expect_raises Matrix::NotRegular do
        Matrix[[1, 2], [3, 4, 10]]
      end
    end
  end

  describe "+" do
    it "raises when the two matrices don't have the same dimensions" do
      a = Matrix[[1, 2], [3, 4], [5, 6], [7, 8]]
      b = Matrix[[1, 2], [3, 4], [5, 6]]
      expect_raises Matrix::DimensionMismatch do
        a + b
      end
    end

    it "does addition with another matrix (1)" do
      a = Matrix[[1, 2], [3, 4], [5, 6], [7, 8]]
      b = Matrix[[2, 4], [6, 8], [10, 12], [14, 16]]
      (a + a).should eq(b)
    end

    it "does addition with another matrix (2)" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = a.reverse
      c = Matrix.new(3, 3, 10)
      c.should eq(a + b)
    end

    it "does addition with another T (1)" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = Matrix[[6, 7, 8], [9, 10, 11], [12, 13, 14]]
      (a + 5).should eq(b)
    end

    it "does addition with another T (2)" do
      a = Matrix[["a", "b"], ["c", "d"], ["e", "f"]]
      b = Matrix[["ax", "bx"], ["cx", "dx"], ["ex", "fx"]]
      (a + "x").should eq(b)
    end
  end

  describe "-" do
    it "raises when the two matrices don't have the same dimensions" do
      a = Matrix[[1, 2], [3, 4], [5, 6], [7, 8]]
      b = Matrix[[1, 2], [3, 4], [5, 6]]
      expect_raises Matrix::DimensionMismatch do
        a - b
      end
    end

    it "does subtraction with another matrix (1)" do
      a = Matrix[[1, 2], [3, 4], [5, 6], [7, 8]]
      b = Matrix[[2, 4], [6, 8], [10, 12], [14, 16]]
      c = Matrix[[-1, -2], [-3, -4], [-5, -6], [-7, -8]]
      (a - b).should eq(c)
    end

    it "does subtraction with another matrix (2)" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = a.reverse
      c = Matrix[[-8, -6, -4], [-2, 0, 2], [4, 6, 8]]
      (a - b).should eq(c)
    end

    it "does subtraction with another T" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = Matrix[[-4, -3, -2], [-1, 0, 1], [2, 3, 4]]
      (a - 5).should eq(b)
    end
  end

  describe "*" do
    it "returns the product of two matrices (1)" do
      a = Matrix[[1, 2], [3, 4]]
      b = Matrix[[5, 6], [7, 8]]
      (a * b).to_a.should eq([19, 22, 43, 50])
    end

    it "returns the product of two matrices (2)" do
      a = Matrix.row(10, 11, 12)
      b = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      (a * b).to_a.should eq([138, 171, 204])
    end

    it "has the correct rows and columns after a product (1)" do
      a = Matrix.row(10, 11, 12)
      b = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      (a * b).row_count.should eq(1)
      (a * b).column_count.should eq(3)
    end

    it "has the correct rows and columns after a product (2)" do
      a = Matrix[[1, 2], [3, 4], [5, 6], [7, 8]]
      b = Matrix[[1, 2, 3], [4, 5, 6]]
      (a * b).row_count.should eq(4)
      (a * b).column_count.should eq(3)
    end
  end

  describe "/" do
    it "does division with another matrix (1)" do
      a = Matrix[[7, 6], [3, 9]]
      b = Matrix[[2, 9], [3, 1]]
      c = Matrix[["0.44", "2.04"], ["0.96", "0.36"]]
      (a / b).map(&.to_s).should eq(c)
    end

    it "does division with another matrix (2)" do
      a = Matrix[[7, 6], [3, 9]]
      b = Matrix[[1, 0], [0, 1]]
      (a / a).map(&.round).should eq(b)
    end

    it "does division with another matrix (3)" do
      a = Matrix[[1, 2, 3], [3, 2, 1], [2, 1, 3]]
      b = Matrix[[1, 2, 1], [2, 0, 4], [2, 1, 3]]
      c = Matrix[[3, 3, -4],
        [-3, -5, 8],
        [0, 0, 1]]
      (a / b).should eq(c)
    end
  end

  describe "**" do
    it "does ** with an Int" do
      a = Matrix[[1, 1], [1, 0]]
      b = Matrix[[3, 2], [2, 1]]
      (a ** 3).should eq(b)

      a = Matrix[[7, 6], [3, 9]]
      b = Matrix[[67, 96], [48, 99]]
      (a ** 2).should eq(b)

      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      (a ** 1).should eq(a)

      a = Matrix[[1, 1], [1, 0]]
      b = Matrix[[1, -1], [-1, 2]]
      (a ** -2).should eq(b)

      a = Matrix[[1, 1], [1, 0]]
      b = Matrix[[1, 0], [0, 1]]
      (a ** 0).should eq(b)
    end
  end

  describe "determinant" do
    it "returns the correct determinant (1)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.determinant.should eq(0)
    end

    it "returns the correct determinant (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 5]]
      m.determinant.should eq(12)
    end

    it "returns the correct determinant (3)" do
      m = Matrix[
        [8.34214e+08, 1.49162e+09, 1.73546e+09, 1.92257e+09, 9.61509e+08],
        [4.65819e+08, 1.10092e+09, 2.57361e+08, 9.85276e+08, 5.04763e+08],
        [2.63287e+08, 5.28931e+08, 1.39454e+09, 1.52471e+09, 4.30514e+08],
        [2.02314e+09, 1.92594e+08, 7.72298e+08, 1.72581e+09, 2.05689e+09],
        [7.35774e+08, 1.71179e+09, 9.40757e+08, 9.72277e+08, 1.46371e+09]]
      m.determinant.should be_close(1.25922e+45, 1e40)
    end

    it "returns the correct determinant (4)" do
      m = Matrix[
        [0.435, 0.337, 0.494],
        [0.096, 0.569, 0.304],
        [0.891, 0.347, 0.460]]
      m.determinant.round(7).should eq(-0.0896226)
    end

    it "returns the correct determinant (5)" do
      m = Matrix[[1.23, 2.34], [3.45, 4.56]]
      m.determinant.round(4).should eq(-2.4642)
    end

    it "returns the correct determinant (6)" do
      m = Matrix[[3.45]]
      m.determinant.should eq(3.45)
    end
  end

  describe "each" do
    it "iterates" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each { |e| b += e }
      b.should eq(45)
    end

    it "iterates the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:diagonal) { |e| b += e }
      b.should eq(15)
    end

    it "iterates skipping the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:off_diagonal) { |e| b += e }
      b.should eq(30)
    end

    it "iterates at or below the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:lower) { |e| b += e }
      b.should eq(34)
    end

    it "iterates below the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:strict_lower) { |e| b += e }
      b.should eq(19)
    end

    it "iterates at or above the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:upper) { |e| b += e }
      b.should eq(26)
    end

    it "iterates above the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:strict_upper) { |e| b += e }
      b.should eq(11)
    end
  end

  describe "each_with_index" do
    it "iterates" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index { |e, r, c| x += e; y += r; z += c }
      {x, y, z}.should eq({21, 6, 3})
    end

    it "iterates the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:diagonal) { |e, r, c| x += e; y += r; z += c }
      {x, y, z}.should eq({5, 1, 1})
    end

    it "iterates skipping the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:off_diagonal) { |e, r, c| x += e; y += r; z += c }
      {x, y, z}.should eq({16, 5, 2})
    end

    it "iterates at or below the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:lower) { |e, r, c| x += e; y += r; z += c }
      {x, y, z}.should eq({19, 6, 2})
    end

    it "iterates below the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:strict_lower) { |e, r, c| x += e; y += r; z += c }
      {x, y, z}.should eq({14, 5, 1})
    end

    it "iterates at or above the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:upper) { |e, r, c| x += e; y += r; z += c }
      {x, y, z}.should eq({7, 1, 2})
    end

    it "iterates above the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:strict_upper) { |e, r, c| x += e; y += r; z += c }
      {x, y, z}.should eq({2, 0, 1})
    end
  end

  describe "index" do
    it "returns the first index when the block returns true, nil otherwise" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.index(&.even?).should eq({0, 1})
      m.index(&.>(7)).should eq({2, 1})
      m.index(&.<(1)).should eq(nil)
    end

    it "returns the first index when the given value is found, nil otherwise" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.index(5, :diagonal).should eq({1, 1})
      m.index(7, :upper).should eq(nil)
    end
  end

  describe "inverse" do
    it "returns the inverse of the matrix (1)" do
      a = Matrix[[-1, -1], [0, -1]]
      b = Matrix[[-1, 1], [0, -1]]
      a.inverse.should eq(b)
    end

    it "returns the inverse of the matrix (2)" do
      a = Matrix[[4, 3], [3, 2]]
      b = Matrix[[-2, 3], [3, -4]]
      a.inverse.should eq(b)
    end

    it "returns the inverse of the matrix (3)" do
      a = Matrix[[4, 7], [2, 6]]
      b = Matrix[[0.6, -0.7], [-0.2, 0.4]]
      a.inverse.should eq(b)
    end
  end

  describe "minor" do
    it "returns a section of the matrix (1)" do
      m = Matrix(Int32).diagonal(9, 5, -3).minor(0, 3, 0, 2)
      m.rows.should eq([[9, 0], [0, 5], [0, 0]])
    end

    it "returns a section of the matrix (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.minor(0, 3, 0, 3).rows.should eq(m.rows)
      m.minor(1, 2, 0, 1).rows.should eq([[4], [7]])
      m.minor(0, 3, 0, 2).rows.should eq([[1, 2], [4, 5], [7, 8]])
      m.minor(1, 1, 1, 1).rows.should eq([[5]])
      m.minor(-1, 1, -1, 1).rows.should eq([[9]])
    end

    it "returns a section of the matrix (3)" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      m.minor(1, 2, 1, 1).rows.should eq([[4], [6]])
    end

    it "returns a section of the matrix given ranges as args" do
      m = Matrix(Int32).diagonal(9, 5, -3).minor(0..1, 0..2)
      m.rows.should eq([[9, 0, 0], [0, 5, 0]])
    end
  end

  describe "row" do
    it "returns an iterator for with the row corresponding to the given index" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      a = [4, 5, 6]
      m.row(1).to_a.should eq(a)
    end
  end

  describe "row_vectors" do
    it "returns an array of matrices, each with a single row" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = a.row_vectors
      c = [Matrix[[1, 2, 3]], Matrix[[4, 5, 6]], Matrix[[7, 8, 9]]]
      b.should eq(c)
    end
  end

  describe "rows" do
    it "returns an array with the rows of the matrix" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      a = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.rows.should eq(a)
    end
  end

  describe "column" do
    it "returns an iterator for the column corresponding to the given index" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      a = [2, 5, 8]
      m.column(1).to_a.should eq(a)
    end
  end

  describe "column_vectors" do
    it "returns an array of matrices, each with a single column" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = a.column_vectors
      c = [Matrix[[1], [4], [7]], Matrix[[2], [5], [8]], Matrix[[3], [6], [9]]]
      b.should eq(c)
    end
  end

  describe "columns" do
    it "returns an array with the columns of the matrix" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      a = [[1, 4, 7], [2, 5, 8], [3, 6, 9]]
      m.columns.should eq(a)
    end
  end

  describe "lower_triangular?" do
    it "returns true if the matrix is lower triangular (1)" do
      m = Matrix[[1, 0, 0], [2, 8, 0], [4, 9, 7]]
      m.lower_triangular?.should be_true
    end

    it "returns true if the matrix is lower triangular (2)" do
      m = Matrix[[1, 2], [3, 4]]
      m.lower_triangular?.should be_false
    end

    it "returns true if the matrix is lower triangular (3)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.lower_triangular?.should be_false
    end
  end

  describe "upper_triangular?" do
    it "returns true if the matrix is upper triangular (1)" do
      m = Matrix[[1, 4, 2], [0, 3, 4], [0, 0, 1]]
      m.upper_triangular?.should be_true
    end

    it "returns true if the matrix is upper triangular (2)" do
      m = Matrix[[1, 2], [3, 4]]
      m.upper_triangular?.should be_false
    end

    it "returns true if the matrix is upper triangular (3)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.upper_triangular?.should be_false
    end
  end

  describe "permutation?" do
    it "returns true if the matrix is a permutation matrix (1)" do
      m = Matrix.identity(10)
      m.permutation?.should be_true
    end

    it "returns true if the matrix is a permutation matrix (2)" do
      m = Matrix[[1, 0, 0], [0, 1, 0], [0, 1, 0]]
      m.permutation?.should be_false
    end

    it "returns true if the matrix is a permutation matrix (3)" do
      m = Matrix[[1, 0, 0], [0, 1, 0], [0, 0, 0]]
      m.permutation?.should be_false
    end

    it "returns true if the matrix is a permutation matrix (4)" do
      Matrix[[0, 0, 1], [1, 0, 1], [0, 0, 0]].permutation?.should be_false
      Matrix[[0, 1, 1], [0, 0, 0], [0, 1, 0]].permutation?.should be_false
      Matrix[[0, 0, 0], [1, 0, 0], [1, 1, 0]].permutation?.should be_false
      Matrix[[0, 0, 1], [1, 0, 1], [0, 0, 0]].permutation?.should be_false
    end
  end

  describe "regular?" do
    it "returns true if the matrix is regular (1)" do
      m = Matrix[[2, 6], [1, 3]]
      m.regular?.should be_false
    end

    it "returns true if the matrix is regular (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.regular?.should be_false
    end

    it "returns true if the matrix is regular (3)" do
      m = Matrix[[1, 2], [3, 4]]
      m.regular?.should be_true
    end
  end

  describe "rank" do
    it "returns the rank of the matrix (1)" do
      m = Matrix[[1, 1, 0, 2], [-1, -1, 0, -2]]
      m.rank.should eq(1)
    end

    it "returns the rank of the matrix (2)" do
      m = Matrix[[7, 6], [3, 9]]
      m.rank.should eq(2)
    end

    it "returns the rank of the matrix (3)" do
      m = Matrix[[1.23, 2.34, 3.45], [4.56, 5.67, 6.78], [7.89, 8.91, 9.10]]
      m.rank.should eq(3)
    end
  end

  describe "singular?" do
    it "returns true if the matrix is singular (1)" do
      m = Matrix[[2, 6], [1, 3]]
      m.singular?.should be_true
    end

    it "returns true if the matrix is singular (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.singular?.should be_true
    end

    it "returns true if the matrix is singular (3)" do
      m = Matrix[[1, 2], [3, 4]]
      m.singular?.should be_false
    end
  end

  describe "square?" do
    it "returns true if the matrix is square, false otherwise (1)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      m.square?.should be_true
    end

    it "returns true if the matrix is square, false otherwise (1)" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      m.square?.should be_false
    end
  end

  describe "symmetric?" do
    it "returns true if the matrix is symmetric (1)" do
      m = Matrix[[1, 2, 3], [2, 5, 6], [3, 6, 9]]
      m.symmetric?.should be_true
    end

    it "returns true if the matrix is symmetric (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [3, 6, 9]]
      m.symmetric?.should be_false
    end
  end

  describe "to_a" do
    it "returns an array with each element in the matrix (1)" do
      m = Matrix.rows([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
      a = [1, 2, 3, 4, 5, 6, 7, 8, 9]
      m.to_a.should eq(a)
    end

    it "returns an array with each element in the matrix (2)" do
      m = Matrix.columns([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
      a = [1, 4, 7, 2, 5, 8, 3, 6, 9]
      m.to_a.should eq(a)
    end

    it "returns an array with each element in the matrix (3)" do
      m = Matrix.identity(5)
      a = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1]
      m.to_a.should eq(a)
    end
  end

  describe "to_h" do
    it "returns a hash: {row_index, column_index} => value (1)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      h = { {0, 0} => 1, {0, 1} => 2, {0, 2} => 3, {1, 0} => 4, {1, 1} => 5,
        {1, 2} => 6, {2, 0} => 7, {2, 1} => 8, {2, 2} => 9 }
      m.to_h.should eq(h)
    end

    it "returns a hash: {row_index, column_index} => value (2)" do
      m = Matrix[[1, 2], [3, 4], [5, 6], [7, 8]]
      h = { {0, 0} => 1, {0, 1} => 2, {1, 0} => 3, {1, 1} => 4, {2, 0} => 5,
        {2, 1} => 6, {3, 0} => 7, {3, 1} => 8 }
      m.to_h.should eq(h)
    end

    it "returns a hash: {row_index, column_index} => value (3)" do
      m = Matrix[
        [0.86, 0.60, 0.27, 0.24, 0.64, 0.46, 0.93, 0.58, 0.13, 0.33],
        [0.51, 0.78, 0.78, 0.57, 0.27, 0.56, 0.80, 0.56, 0.13, 0.12],
        [0.80, 0.29, 0.10, 0.13, 0.87, 0.13, 0.43, 0.46, 0.01, 0.05],
        [0.92, 0.00, 0.47, 0.26, 0.79, 0.01, 0.40, 0.74, 0.77, 0.89],
        [0.42, 0.08, 0.91, 0.88, 0.01, 0.82, 0.06, 0.63, 0.31, 0.28],
        [0.79, 0.65, 0.45, 0.95, 0.58, 0.45, 0.18, 0.81, 0.32, 0.82],
        [0.15, 0.70, 0.45, 0.90, 0.90, 0.97, 0.32, 0.50, 0.95, 0.57],
        [0.19, 0.49, 0.24, 0.89, 0.00, 0.64, 0.28, 0.27, 0.92, 0.39],
        [0.86, 0.55, 1.00, 0.83, 0.26, 0.69, 0.48, 0.33, 0.26, 0.85],
        [0.36, 0.15, 0.76, 0.92, 0.14, 0.50, 0.84, 0.91, 0.07, 0.88]]
      h = {
        {0, 0} => 0.86, {0, 1} => 0.6, {0, 2} => 0.27, {0, 3} => 0.24,
        {0, 4} => 0.64, {0, 5} => 0.46, {0, 6} => 0.93, {0, 7} => 0.58,
        {0, 8} => 0.13, {0, 9} => 0.33, {1, 0} => 0.51, {1, 1} => 0.78,
        {1, 2} => 0.78, {1, 3} => 0.57, {1, 4} => 0.27, {1, 5} => 0.56,
        {1, 6} => 0.80, {1, 7} => 0.56, {1, 8} => 0.13, {1, 9} => 0.12,
        {2, 0} => 0.80, {2, 1} => 0.29, {2, 2} => 0.10, {2, 3} => 0.13,
        {2, 4} => 0.87, {2, 5} => 0.13, {2, 6} => 0.43, {2, 7} => 0.46,
        {2, 8} => 0.01, {2, 9} => 0.05, {3, 0} => 0.92, {3, 1} => 0.00,
        {3, 2} => 0.47, {3, 3} => 0.26, {3, 4} => 0.79, {3, 5} => 0.01,
        {3, 6} => 0.40, {3, 7} => 0.74, {3, 8} => 0.77, {3, 9} => 0.89,
        {4, 0} => 0.42, {4, 1} => 0.08, {4, 2} => 0.91, {4, 3} => 0.88,
        {4, 4} => 0.01, {4, 5} => 0.82, {4, 6} => 0.06, {4, 7} => 0.63,
        {4, 8} => 0.31, {4, 9} => 0.28, {5, 0} => 0.79, {5, 1} => 0.65,
        {5, 2} => 0.45, {5, 3} => 0.95, {5, 4} => 0.58, {5, 5} => 0.45,
        {5, 6} => 0.18, {5, 7} => 0.81, {5, 8} => 0.32, {5, 9} => 0.82,
        {6, 0} => 0.15, {6, 1} => 0.70, {6, 2} => 0.45, {6, 3} => 0.90,
        {6, 4} => 0.90, {6, 5} => 0.97, {6, 6} => 0.32, {6, 7} => 0.50,
        {6, 8} => 0.95, {6, 9} => 0.57, {7, 0} => 0.19, {7, 1} => 0.49,
        {7, 2} => 0.24, {7, 3} => 0.89, {7, 4} => 0.00, {7, 5} => 0.64,
        {7, 6} => 0.28, {7, 7} => 0.27, {7, 8} => 0.92, {7, 9} => 0.39,
        {8, 0} => 0.86, {8, 1} => 0.55, {8, 2} => 1.00, {8, 3} => 0.83,
        {8, 4} => 0.26, {8, 5} => 0.69, {8, 6} => 0.48, {8, 7} => 0.33,
        {8, 8} => 0.26, {8, 9} => 0.85, {9, 0} => 0.36, {9, 1} => 0.15,
        {9, 2} => 0.76, {9, 3} => 0.92, {9, 4} => 0.14, {9, 5} => 0.50,
        {9, 6} => 0.84, {9, 7} => 0.91, {9, 8} => 0.07, {9, 9} => 0.88,
      }
      m.to_h.should eq(h)
    end
  end

  describe "trace" do
    it "returns the sum of the diagonal elements of the matrix (1)" do
      m = Matrix[{1, 2}, {3, 4}]
      m.trace.should eq(5)
    end

    it "returns the sum of the diagonal elements of the matrix (2)" do
      m = Matrix[{1.1, 2.2, 3.3}, {4.4, 5.5, 6.6}, {7.7, 8.8, 9.9}]
      m.trace.should eq(16.5)
    end
  end

  describe "transpose" do
    it "transposes the elements in a square matrix" do
      a = Matrix.rows([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
      b = Matrix.rows([[1, 4, 7], [2, 5, 8], [3, 6, 9]])
      a.transpose.should eq(b)
    end

    it "transposes the elements in a non-square matrix" do
      a = Matrix.rows([['a', 'b'], ['c', 'd'], ['e', 'f'], ['g', 'h']])
      b = Matrix.rows([['a', 'c', 'e', 'g'], ['b', 'd', 'f', 'h']])
      a.transpose.should eq(b)
    end

    it "transposes the elements in a single row matrix" do
      a = Matrix.row(:a, :b, :c, :d)
      b = Matrix.column(:a, :b, :c, :d)
      a.transpose.should eq(b)
    end

    it "transposes the elements in a single column matrix" do
      a = Matrix.column(:a, :b, :c, :d)
      b = Matrix.row(:a, :b, :c, :d)
      a.transpose.should eq(b)
    end
  end

  describe "each iterator" do
    it "does next" do
      iter = Matrix.identity(3).each
      {1, 0, 0, 0, 1, 0, 0, 0, 1}.each { |e| iter.next.should eq(e) }
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq(1)
    end

    it "cycles" do
      Matrix.identity(3).cycle.take(10).join.should eq("1000100011")
    end
  end

  describe "each_index iterator" do
    it "does next" do
      iter = Matrix.new(3, 2, &.itself).each_index
      iter.next.should eq({0, 0})
      iter.next.should eq({0, 1})
      iter.next.should eq({1, 0})
      iter.next.should eq({1, 1})
      iter.next.should eq({2, 0})
      iter.next.should eq({2, 1})
      iter.next.should be_a(Iterator::Stop)

      iter.rewind
      iter.next.should eq({0, 0})
    end
  end

  describe "row iterator" do
    it "does next" do
      m = Matrix.identity(3)

      iter = m.row(0)
      {1, 0, 0}.each { |e| iter.next.should eq(e) }
      iter.next.should be_a(Iterator::Stop)
      iter.rewind
      iter.next.should eq(1)

      iter = m.row(1)
      {0, 1, 0}.each { |e| iter.next.should eq(e) }
      iter.next.should be_a(Iterator::Stop)
      iter.rewind
      iter.next.should eq(0)

      iter = m.row(2)
      {0, 0, 1}.each { |e| iter.next.should eq(e) }
      iter.next.should be_a(Iterator::Stop)
      iter.rewind
      iter.next.should eq(0)

      iter = m.row(-1)
      {0, 0, 1}.each { |e| iter.next.should eq(e) }
      iter.next.should be_a(Iterator::Stop)
      iter.rewind
      iter.next.should eq(0)
    end
  end

  describe "column iterator" do
    it "does next" do
      m = Matrix.identity(3)

      iter = m.column(0)
      {1, 0, 0}.each { |e| iter.next.should eq(e) }
      iter.next.should be_a(Iterator::Stop)
      iter.rewind
      iter.next.should eq(1)

      iter = m.column(1)
      {0, 1, 0}.each { |e| iter.next.should eq(e) }
      iter.next.should be_a(Iterator::Stop)
      iter.rewind
      iter.next.should eq(0)

      iter = m.column(2)
      {0, 0, 1}.each { |e| iter.next.should eq(e) }
      iter.next.should be_a(Iterator::Stop)
      iter.rewind
      iter.next.should eq(0)

      iter = m.column(-1)
      {0, 0, 1}.each { |e| iter.next.should eq(e) }
      iter.next.should be_a(Iterator::Stop)
      iter.rewind
      iter.next.should eq(0)
    end
  end
end
