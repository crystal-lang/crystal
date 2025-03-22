require "spec"

private def assert_file_matches(pattern, path : String, *, file = __FILE__, line = __LINE__)
  File.match?(pattern, path).should be_true, file: file, line: line
  File.match?(pattern, Path.posix(path)).should be_true, file: file, line: line
  File.match?(pattern, Path.posix(path).to_windows).should be_true, file: file, line: line
end

private def refute_file_matches(pattern, path : String, *, file = __FILE__, line = __LINE__)
  File.match?(pattern, path).should be_false, file: file, line: line
  File.match?(pattern, Path.posix(path)).should be_false, file: file, line: line
  File.match?(pattern, Path.posix(path).to_windows).should be_false, file: file, line: line
end

describe File do
  describe ".match?" do
    it "matches basics" do
      assert_file_matches "abc", "abc"
      assert_file_matches "*", "abc"
      assert_file_matches "*c", "abc"
      assert_file_matches "a*", "a"
      assert_file_matches "a*", "abc"
      assert_file_matches "a*/b", "abc/b"
      assert_file_matches "*x", "xxx"
      assert_file_matches "*.x", "a.x"
      assert_file_matches "a/b/*.x", "a/b/c.x"
      refute_file_matches "*.x", "a/b/c.x"
      refute_file_matches "c.x", "a/b/c.x"
      refute_file_matches "b/*.x", "a/b/c.x"
    end

    it "matches multiple expansions" do
      assert_file_matches "a*b*c*d*e*/f", "axbxcxdxe/f"
      assert_file_matches "a*b*c*d*e*/f", "axbxcxdxexxx/f"
      assert_file_matches "a*b?c*x", "abxbbxdbxebxczzx"
      refute_file_matches "a*b?c*x", "abxbbxdbxebxczzy"
    end

    it "matches unicode characters" do
      assert_file_matches "a?b", "a☺b"
      refute_file_matches "a???b", "a☺b"
    end

    it "* don't match path separator" do
      refute_file_matches "a*", "ab/c"
      refute_file_matches "a*/b", "a/c/b"
      refute_file_matches "a*b*c*d*e*/f", "axbxcxdxe/xxx/f"
      refute_file_matches "a*b*c*d*e*/f", "axbxcxdxexxx/fff"
    end

    it "**" do
      assert_file_matches "a/b/**", "a/b/c.x"
      assert_file_matches "a/**", "a/b/c.x"
      assert_file_matches "a/**/d.x", "a/b/c/d.x"
      refute_file_matches "a/**b/d.x", "a/bb/c/d.x"
      refute_file_matches "a/b**/*", "a/bb/c/d.x"
    end

    it "** bugs (#15319)" do
      refute_file_matches "a/**/*", "a/b/c/d.x"
      assert_file_matches "a/b**/d.x", "a/bb/c/d.x"
      refute_file_matches "**/*.x", "a/b/c.x"
      assert_file_matches "**.x", "a/b/c.x"
    end

    it "** matches path separator" do
      assert_file_matches "a**", "ab/c"
      assert_file_matches "a**/b", "a/c/b"
      assert_file_matches "a*b*c*d*e**/f", "axbxcxdxe/xxx/f"
      assert_file_matches "a*b*c*d*e**/f", "axbxcxdxexxx/f"
      refute_file_matches "a*b*c*d*e**/f", "axbxcxdxexxx/fff"
    end

    it "classes" do
      assert_file_matches "ab[c]", "abc"
      assert_file_matches "ab[b-d]", "abc"
      refute_file_matches "ab[d-b]", "abc"
      refute_file_matches "ab[e-g]", "abc"
      assert_file_matches "ab[e-gc]", "abc"
      refute_file_matches "ab[^c]", "abc"
      refute_file_matches "ab[^b-d]", "abc"
      assert_file_matches "ab[^e-g]", "abc"
      assert_file_matches "a[^a]b", "a☺b"
      refute_file_matches "a[^a][^a][^a]b", "a☺b"
      assert_file_matches "[a-ζ]*", "α"
      refute_file_matches "*[a-ζ]", "A"
    end

    it "escape" do
      # NOTE: `*` is forbidden in Windows paths
      File.match?("a\\*b", "a*b").should be_true
      refute_file_matches "a\\*b", "ab"
      File.match?("a\\**b", "a*bb").should be_true
      refute_file_matches "a\\**b", "abb"
      File.match?("a*\\*b", "ab*b").should be_true
      refute_file_matches "a*\\*b", "abb"

      assert_file_matches "a\\[b\\]", "a[b]"
      refute_file_matches "a\\[b\\]", "ab"
      assert_file_matches "a\\[bb\\]", "a[bb]"
      refute_file_matches "a\\[bb\\]", "abb"
      assert_file_matches "a[b]\\[b\\]", "ab[b]"
      refute_file_matches "a[b]\\[b\\]", "abb"
    end

    it "special chars" do
      refute_file_matches "a?b", "a/b"
      refute_file_matches "a*b", "a/b"
    end

    it "classes escapes" do
      assert_file_matches "[\\]a]", "]"
      assert_file_matches "[\\-]", "-"
      assert_file_matches "[x\\-]", "x"
      assert_file_matches "[x\\-]", "-"
      refute_file_matches "[x\\-]", "z"
      assert_file_matches "[\\-x]", "x"
      assert_file_matches "[\\-x]", "-"
      refute_file_matches "[\\-x]", "a"

      expect_raises(File::BadPatternError, "empty character set") do
        File.match?("[]a]", "]")
      end
      expect_raises(File::BadPatternError, "missing range start") do
        File.match?("[-]", "-")
      end
      expect_raises(File::BadPatternError, "missing range end") do
        File.match?("[x-]", "x")
      end
      expect_raises(File::BadPatternError, "missing range start") do
        File.match?("[-x]", "x")
      end
      expect_raises(File::BadPatternError, "Empty escape character") do
        File.match?("\\", "a")
      end
      expect_raises(File::BadPatternError, "missing range start") do
        File.match?("[a-b-c]", "a")
      end
      expect_raises(File::BadPatternError, "unterminated character set") do
        File.match?("[", "a")
      end
      expect_raises(File::BadPatternError, "unterminated character set") do
        File.match?("[^", "a")
      end
      expect_raises(File::BadPatternError, "unterminated character set") do
        File.match?("[^bc", "a")
      end
      expect_raises(File::BadPatternError, "unterminated character set") do
        File.match?("a[", "a")
      end
    end

    it "alternates" do
      assert_file_matches "{abc,def}", "abc"
      assert_file_matches "ab{c,}", "abc"
      assert_file_matches "ab{c,}", "ab"
      refute_file_matches "ab{d,e}", "abc"
      assert_file_matches "ab{*,/cde}", "abcde"
      assert_file_matches "ab{*,/cde}", "ab/cde"
      assert_file_matches "ab{?,/}de", "abcde"
      assert_file_matches "ab{?,/}de", "ab/de"
      assert_file_matches "ab{{c,d}ef,}", "ab"
      assert_file_matches "ab{{c,d}ef,}", "abcef"
      assert_file_matches "ab{{c,d}ef,}", "abdef"
    end
  end
end
