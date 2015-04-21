require "matrix"
require "spec"

describe Matrix do
  describe "Matrix.rows" do
    it "creates a matrix with the args as an array/tuple of rows (1)" do
      m = Matrix.rows([[1, 2], [3, 4], [5, 6]])
      expect(m.to_a).to eq([1, 2, 3, 4, 5, 6])
    end

    it "creates a matrix with the args as an array/tuple of rows (2)" do
      m = Matrix.rows([['1', '2', '3', '4'], ['5', '6', '7', '8']])
      expect(m.to_a).to eq(['1', '2', '3', '4', '5', '6', '7', '8'])
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
      expect(m.to_a).to eq([1, 3, 5, 2, 4, 6])
    end

    it "creates a matrix with the args as an array/tuple of columns (2)" do
      m = Matrix.columns([['1', '2', '3', '4'], ['5', '6', '7', '8']])
      expect(m.to_a).to eq(['1', '5', '2', '6', '3', '7', '4', '8'])
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
      expect(m.rows).to eq([[1, 0, 0], [0, 2, 0], [0, 0, 3]])
    end
  end

  describe "Matrix.identity" do
    it "creates a matrix whose diagonal elements are 1 and the rest are 0" do
      m = Matrix.identity(3)
      expect(m.rows).to eq([[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    end
  end

  describe "Matrix.row" do
    it "creates a single row matrix" do
      m = Matrix.row(1, 2, 3, 4)
      expect(m.rows).to eq([[1, 2, 3, 4]])
    end
  end

  describe "Matrix.column" do
    it "creates a single column matrix" do
      m = Matrix.column(1, 2, 3, 4)
      expect(m.columns).to eq([[1, 2, 3, 4]])
    end
  end

  describe "Matrix.[]" do
    it "creates a matrix with each arg as a row" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.rows).to eq([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    end

    it "works with tuples" do
      m = Matrix[{1, 2, 3}, {4, 5, 6}, {7, 8, 9}]
      expect(m.rows).to eq([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
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
      expect((a + a)).to eq(b)
    end

    it "does addition with another matrix (2)" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = a.reverse
      c = Matrix.new(3, 3, 10)
      expect(c).to eq(a + b)
    end

    it "does addition with another T (1)" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = Matrix[[6, 7, 8], [9, 10, 11], [12, 13, 14]]
      expect((a + 5)).to eq(b)
    end

    it "does addition with another T (2)" do
      a = Matrix[["a", "b"], ["c", "d"], ["e", "f"]]
      b = Matrix[["ax", "bx"], ["cx", "dx"], ["ex", "fx"]]
      expect((a + "x")).to eq(b)
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

    it "does substraction with another matrix (1)" do
      a = Matrix[[1, 2], [3, 4], [5, 6], [7, 8]]
      b = Matrix[[2, 4], [6, 8], [10, 12], [14, 16]]
      c = Matrix[[-1, -2], [-3, -4], [-5, -6], [-7, -8]]
      expect((a - b)).to eq(c)
    end

    it "does substraction with another matrix (2)" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = a.reverse
      c = Matrix[[-8, -6, -4], [-2, 0, 2], [4, 6, 8]]
      expect((a - b)).to eq(c)
    end

    it "does substraction with another T" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = Matrix[[-4, -3, -2], [-1, 0, 1], [2, 3, 4]]
      expect((a - 5)).to eq(b)
    end
  end

  describe "*" do
    it "returns the product of two matrices (1)" do
      a = Matrix[[1, 2], [3, 4]]
      b = Matrix[[5, 6], [7, 8]]
      expect((a * b).to_a).to eq([19, 22, 43, 50])
    end

    it "returns the product of two matrices (2)" do
      a = Matrix.row(10, 11, 12)
      b = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect((a * b).to_a).to eq([138, 171, 204])
    end

    it "has the correct rows and columns after a product (1)" do
      a = Matrix.row(10, 11, 12)
      b = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect((a * b).row_count).to eq(1)
      expect((a * b).column_count).to eq(3)
    end

    it "has the correct rows and columns after a product (2)" do
      a = Matrix[[1,2], [3,4], [5,6], [7,8]]
      b = Matrix[[1, 2, 3], [4, 5, 6]]
      expect((a * b).row_count).to eq(4)
      expect((a * b).column_count).to eq(3)
    end
  end

  describe "/" do
    it "does division with another matrix (1)" do
      a = Matrix[[7, 6], [3, 9]]
      b = Matrix[[2, 9], [3, 1]]
      c = Matrix[["0.44", "2.04"], ["0.96", "0.36"]]
      expect((a / b).map(&.to_s)).to eq(c)
    end

    it "does division with another matrix (2)" do
      a = Matrix[[7, 6], [3, 9]]
      b = Matrix[[1, 0], [0, 1]]
      expect((a / a).map(&.round)).to eq(b)
    end

    it "does division with another matrix (3)" do
      a = Matrix[[1, 2, 3], [3, 2, 1], [2, 1, 3]]
      b = Matrix[[4, 5, 6], [6, 5, 4], [4, 6, 5]]
      c = Matrix[[0.7000000000000002, -0.3, -1.1102230246251565e-16],
                 [-0.2999999999999998, 0.7, -5.551115123125783e-17],
                 [1.2000000000000002, 0.19999999999999996, -1.0]]
      expect((a / b)).to eq(c)
    end
  end

  describe "**" do
    it "does ** with an Int" do
      a = Matrix[[1, 1], [1, 0]]
      b = Matrix[[3, 2], [2, 1]]
      expect((a ** 3)).to eq(b)

      a = Matrix[[7, 6], [3, 9]]
      b = Matrix[[67, 96], [48, 99]]
      expect((a ** 2)).to eq(b)

      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect((a ** 1)).to eq(a)

      a = Matrix[[1, 1], [1, 0]]
      b = Matrix[[1, -1], [-1, 2]]
      expect((a ** -2)).to eq(b)

      a = Matrix[[1, 1], [1, 0]]
      b = Matrix[[1, 0], [0, 1]]
      expect((a ** 0)).to eq(b)
    end
  end

  describe "determinant" do
    it "returns the correct determinant (1)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.determinant).to eq(0)
    end

    it "returns the correct determinant (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 5]]
      expect(m.determinant).to eq(12)
    end

    it "returns the correct determinant (3)" do
      m = Matrix[
        [8.34214e+08, 1.49162e+09, 1.73546e+09, 1.92257e+09, 9.61509e+08],
        [4.65819e+08, 1.10092e+09, 2.57361e+08, 9.85276e+08, 5.04763e+08],
        [2.63287e+08, 5.28931e+08, 1.39454e+09, 1.52471e+09, 4.30514e+08],
        [2.02314e+09, 1.92594e+08, 7.72298e+08, 1.72581e+09, 2.05689e+09],
        [7.35774e+08, 1.71179e+09, 9.40757e+08, 9.72277e+08, 1.46371e+09]]
      expect(m.determinant).to eq(1.2592223449008756e+45)
    end

    it "returns the correct determinant (4)" do
      m = Matrix[
        [0.435, 0.337, 0.494],
        [0.096, 0.569, 0.304],
        [0.891, 0.347, 0.460]]
      expect(m.determinant.round(7)).to eq(-0.0896226)
    end

    it "returns the correct determinant (5)" do
      m = Matrix[[1.23, 2.34], [3.45, 4.56]]
      expect(m.determinant.round(4)).to eq(-2.4642)
    end

    it "returns the correct determinant (6)" do
      m = Matrix[[3.45]]
      expect(m.determinant).to eq(3.45)
    end
  end

  describe "each" do
    it "iterates" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each { |e| b += e }
      expect(b).to eq(45)
    end

    it "iterates the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:diagonal) { |e| b += e }
      expect(b).to eq(15)
    end

    it "iterates skipping the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:off_diagonal) { |e| b += e }
      expect(b).to eq(30)
    end

    it "iterates at or below the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:lower) { |e| b += e }
      expect(b).to eq(34)
    end

    it "iterates below the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:strict_lower) { |e| b += e }
      expect(b).to eq(19)
    end

    it "iterates at or above the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:upper) { |e| b += e }
      expect(b).to eq(26)
    end

    it "iterates above the diagonal" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = 0
      a.each(:strict_upper) { |e| b += e }
      expect(b).to eq(11)
    end
  end

  describe "each_with_index" do
    it "iterates" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index { |e, r, c| x += e; y += r; z += c }
      expect({x, y, z}).to eq({21, 6, 3})
    end

    it "iterates the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:diagonal) { |e, r, c| x += e; y += r; z += c }
      expect({x, y, z}).to eq({5, 1, 1})
    end

    it "iterates skipping the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:off_diagonal) { |e, r, c| x += e; y += r; z += c }
      expect({x, y, z}).to eq({16, 5, 2})
    end

    it "iterates at or below the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:lower) { |e, r, c| x += e; y += r; z += c }
      expect({x, y, z}).to eq({19, 6, 2})
    end

    it "iterates below the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:strict_lower) { |e, r, c| x += e; y += r; z += c }
      expect({x, y, z}).to eq({14, 5, 1})
    end

    it "iterates at or above the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:upper) { |e, r, c| x += e; y += r; z += c }
      expect({x, y, z}).to eq({7, 1, 2})
    end

    it "iterates above the diagonal" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      x, y, z = 0, 0, 0
      m.each_with_index(:strict_upper) { |e, r, c| x += e; y += r; z += c }
      expect({x, y, z}).to eq({2, 0, 1})
    end
  end

  describe "index" do
    it "returns the first index when the block returns true, nil otherwise" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.index(&.even?)).to eq({0, 1})
      expect(m.index(&.>(7))).to eq({2, 1})
      expect(m.index(&.<(1))).to eq(nil)
    end

    it "returns the first index when the given value is found, nil otherwise" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.index(5, :diagonal)).to eq({1, 1})
      expect(m.index(7, :upper)).to eq(nil)
    end
  end

  describe "inverse" do
    it "returns the inverse of the matrix (1)" do
      a = Matrix[[-1, -1], [0, -1]]
      b = Matrix[[-1, 1], [0, -1]]
      expect(a.inverse).to eq(b)
    end

    it "returns the inverse of the matrix (2)" do
      a = Matrix[[4, 3], [3, 2]]
      b = Matrix[[-2, 3], [3, -4]]
      expect(a.inverse).to eq(b)
    end

    it "returns the inverse of the matrix (3)" do
      a = Matrix[[4, 7], [2, 6]]
      b = Matrix[[0.6, -0.7], [-0.2, 0.4]]
      expect(a.inverse).to eq(b)
    end
  end

  describe "minor" do
    it "returns a section of the matrix (1)" do
      m = Matrix(Int32).diagonal(9, 5, -3).minor(0, 3, 0, 2)
      expect(m.rows).to eq([[9, 0], [0, 5], [0, 0]])
    end

    it "returns a section of the matrix (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.minor(0, 3, 0, 3).rows).to eq(m.rows)
      expect(m.minor(1, 2, 0, 1).rows).to eq([[4], [7]])
      expect(m.minor(0, 3, 0, 2).rows).to eq([[1, 2], [4, 5], [7, 8]])
      expect(m.minor(1, 1, 1, 1).rows).to eq([[5]])
      expect(m.minor(-1, 1, -1, 1).rows).to eq([[9]])
    end

    it "returns a section of the matrix (3)" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      expect(m.minor(1, 2, 1, 1).rows).to eq([[4], [6]])
    end

    it "returns a section of the matrix given ranges as args" do
      m = Matrix(Int32).diagonal(9, 5, -3).minor(0..1, 0..2)
      expect(m.rows).to eq([[9, 0, 0], [0, 5, 0]])
    end
  end

  describe "row" do
    it "returns an array with the row corresponding to the given index" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      a = [4, 5, 6]
      expect(m.row(1)).to eq(a)
    end
  end

  describe "row_vectors" do
    it "returns an array of matrices, each with a single row" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = a.row_vectors
      c = [Matrix[[1, 2, 3]], Matrix[[4, 5, 6]], Matrix[[7, 8, 9]]]
      expect(b).to eq(c)
    end
  end

  describe "rows" do
    it "returns an array with the rows of the matrix" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      a = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.rows).to eq(a)
    end
  end

  describe "column" do
    it "returns an array with the column corresponding to the given index" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      a = [2, 5, 8]
      expect(m.column(1)).to eq(a)
    end
  end

  describe "column_vectors" do
    it "returns an array of matrices, each with a single column" do
      a = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      b = a.column_vectors
      c = [Matrix[[1], [4], [7]], Matrix[[2], [5], [8]], Matrix[[3], [6], [9]]]
      expect(b).to eq(c)
    end
  end

  describe "columns" do
    it "returns an array with the columns of the matrix" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      a = [[1, 4, 7], [2, 5, 8], [3, 6, 9]]
      expect(m.columns).to eq(a)
    end
  end

  describe "lower_triangular?" do
    it "returns true if the matrix is lower triangular (1)" do
      m = Matrix[[1, 0, 0], [2, 8, 0], [4, 9, 7]]
      expect(m.lower_triangular?).to be_true
    end

    it "returns true if the matrix is lower triangular (2)" do
      m = Matrix[[1, 2], [3, 4]]
      expect(m.lower_triangular?).to be_false
    end

    it "returns true if the matrix is lower triangular (3)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.lower_triangular?).to be_false
    end
  end

  describe "upper_triangular?" do
    it "returns true if the matrix is upper triangular (1)" do
      m = Matrix[[1, 4, 2], [0, 3, 4], [0, 0, 1]]
      expect(m.upper_triangular?).to be_true
    end

    it "returns true if the matrix is upper triangular (2)" do
      m = Matrix[[1, 2], [3, 4]]
      expect(m.upper_triangular?).to be_false
    end

    it "returns true if the matrix is upper triangular (3)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.upper_triangular?).to be_false
    end
  end

  describe "permutation?" do
    it "returns true if the matrix is a permutation matrix (1)" do
      m = Matrix.identity(10)
      expect(m.permutation?).to be_true
    end

    it "returns true if the matrix is a permutation matrix (2)" do
      m = Matrix[[1, 0, 0], [0, 1, 0], [0, 1, 0]]
      expect(m.permutation?).to be_false
    end

    it "returns true if the matrix is a permutation matrix (3)" do
      m = Matrix[[1, 0, 0], [0, 1, 0], [0, 0, 0]]
      expect(m.permutation?).to be_false
    end

    it "returns true if the matrix is a permutation matrix (4)" do
      expect(Matrix[[0, 0, 1], [1, 0, 1], [0, 0, 0]].permutation?).to be_false
      expect(Matrix[[0, 1, 1], [0, 0, 0], [0, 1, 0]].permutation?).to be_false
      expect(Matrix[[0, 0, 0], [1, 0, 0], [1, 1, 0]].permutation?).to be_false
      expect(Matrix[[0, 0, 1], [1, 0, 1], [0, 0, 0]].permutation?).to be_false
    end
  end

  describe "regular?" do
    it "returns true if the matrix is regular (1)" do
      m = Matrix[[2, 6], [1, 3]]
      expect(m.regular?).to be_false
    end

    it "returns true if the matrix is regular (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.regular?).to be_false
    end

    it "returns true if the matrix is regular (3)" do
      m = Matrix[[1, 2], [3, 4]]
      expect(m.regular?).to be_true
    end
  end

  describe "rank" do
    it "returns the rank of the matrix (1)" do
      m = Matrix[[1, 1, 0, 2], [-1, -1, 0, -2]]
      expect(m.rank).to eq(1)
    end

    it "returns the rank of the matrix (2)" do
      m = Matrix[[7,6], [3,9]]
      expect(m.rank).to eq(2)
    end

    it "returns the rank of the matrix (3)" do
      m = Matrix[[1.23, 2.34, 3.45], [4.56, 5.67, 6.78], [7.89, 8.91, 9.10]]
      expect(m.rank).to eq(3)
    end
  end

  describe "singular?" do
    it "returns true if the matrix is singular (1)" do
      m = Matrix[[2, 6], [1, 3]]
      expect(m.singular?).to be_true
    end

    it "returns true if the matrix is singular (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.singular?).to be_true
    end

    it "returns true if the matrix is singular (3)" do
      m = Matrix[[1, 2], [3, 4]]
      expect(m.singular?).to be_false
    end
  end

  describe "square?" do
    it "returns true if the matrix is square, false otherwise (1)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expect(m.square?).to be_true
    end

    it "returns true if the matrix is square, false otherwise (1)" do
      m = Matrix[[1, 2], [3, 4], [5, 6]]
      expect(m.square?).to be_false
    end
  end

  describe "symmetric?" do
    it "returns true if the matrix is symmetric (1)" do
      m = Matrix[[1, 2, 3], [2, 5, 6], [3, 6, 9]]
      expect(m.symmetric?).to be_true
    end

    it "returns true if the matrix is symmetric (2)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [3, 6, 9]]
      expect(m.symmetric?).to be_false
    end
  end

  describe "to_a" do
    it "returns an array with each element in the matrix (1)" do
      m = Matrix.rows([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
      a = [1, 2, 3, 4, 5, 6, 7, 8, 9]
      expect(m.to_a).to eq(a)
    end

    it "returns an array with each element in the matrix (2)" do
      m = Matrix.columns([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
      a = [1, 4, 7, 2, 5, 8, 3, 6, 9]
      expect(m.to_a).to eq(a)
    end

    it "returns an array with each element in the matrix (3)" do
      m = Matrix.identity(5)
      a = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1]
      expect(m.to_a).to eq(a)
    end
  end

  describe "to_h" do
    it "returns a hash: {row_index, column_index} => value (1)" do
      m = Matrix[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      h = { {0, 0} => 1, {0, 1} => 2, {0, 2} => 3, {1, 0} => 4, {1, 1} => 5,
        {1, 2} => 6, {2, 0} => 7, {2, 1} => 8, {2, 2} => 9}
      expect(m.to_h).to eq(h)
    end

    it "returns a hash: {row_index, column_index} => value (2)" do
      m = Matrix[[1,2], [3,4], [5,6], [7,8]]
      h = { {0, 0} => 1, {0, 1} => 2, {1, 0} => 3, {1, 1} => 4, {2, 0} => 5,
        {2, 1} => 6, {3, 0} => 7, {3, 1} => 8}
      expect(m.to_h).to eq(h)
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
        {0, 0} => 0.86, {0, 1} =>  0.6, {0, 2} => 0.27, {0, 3} => 0.24,
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
        {9, 6} => 0.84, {9, 7} => 0.91, {9, 8} => 0.07, {9, 9} => 0.88}
      expect(m.to_h).to eq(h)
    end
  end

  describe "trace" do
    it "returns the sum of the diagonal elements of the matrix (1)" do
      m = Matrix[{1, 2}, {3, 4}]
      expect(m.trace).to eq(5)
    end

    it "returns the sum of the diagonal elements of the matrix (2)" do
      m = Matrix[{1.1, 2.2, 3.3}, {4.4, 5.5, 6.6}, {7.7, 8.8, 9.9}]
      expect(m.trace).to eq(16.5)
    end
  end

  describe "transpose" do
    it "transposes the elements in a square matrix" do
      a = Matrix.rows([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
      b = Matrix.rows([[1, 4, 7], [2, 5, 8], [3, 6, 9]])
      expect(a.transpose).to eq(b)
    end

    it "transposes the elements in a non-square matrix" do
      a = Matrix.rows([['a', 'b'], ['c', 'd'], ['e', 'f'], ['g', 'h']])
      b = Matrix.rows([['a', 'c', 'e', 'g'], ['b', 'd', 'f', 'h']])
      expect(a.transpose).to eq(b)
    end

    it "transposes the elements in a single row matrix" do
      a = Matrix.row(:a, :b, :c, :d)
      b = Matrix.column(:a, :b, :c, :d)
      expect(a.transpose).to eq(b)
    end

    it "transposes the elements in a single column matrix" do
      a = Matrix.column(:a, :b, :c, :d)
      b = Matrix.row(:a, :b, :c, :d)
      expect(a.transpose).to eq(b)
    end
  end
end
