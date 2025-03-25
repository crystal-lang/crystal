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

    describe "multibyte" do
      it "single-character match" do
        assert_file_matches "a?b", "a☺b"
        refute_file_matches "a???b", "a☺b"
      end

      it "character sets" do
        assert_file_matches "[🐶🐱🐰].jpg", "🐶.jpg"
        refute_file_matches "[🐶🐱🐰].jpg", "🐯.jpg"
        refute_file_matches "[🐶🐱🐰].jpg", "x.jpg"
        assert_file_matches "[🐶🐱🐰x].jpg", "🐶.jpg"
        refute_file_matches "[🐶🐱🐰x].jpg", "🐯.jpg"
        assert_file_matches "[🐶🐱🐰x].jpg", "x.jpg"
        assert_file_matches "[^🐶🐱🐰].jpg", "🐯.jpg"
        refute_file_matches "[^🐶🐱🐰].jpg", "🐶.jpg"
        assert_file_matches "[^🐶🐱🐰].jpg", "x.jpg"
      end

      it "character ranges" do
        assert_file_matches "[α-ω].doc", "β.doc"
        refute_file_matches "[α-ω].doc", "Ω.doc"
        assert_file_matches "[Α-Ω].pdf", "Θ.pdf"

        assert_file_matches "[🥇-🥉].png", "🥈.png"
        refute_file_matches "[🥇-🥉].png", "🏆.png"
        refute_file_matches "[🥇-🥉].png", "2.png"

        assert_file_matches "[α-ω🥇-🥉].doc", "β.doc"
        assert_file_matches "[α-ω🥇-🥉].doc", "🥈.doc"
        refute_file_matches "[α-ω🥇-🥉].doc", "Ω.doc"
        refute_file_matches "[α-ω🥇-🥉].doc", "🏆.doc"
        assert_file_matches "[Α-Ω🥇-🥉].pdf", "Θ.pdf"
      end

      it "braces" do
        assert_file_matches "{café,restaurant}.png", "café.png"
        assert_file_matches "{🐶,🐱,🐰}.log", "🐶.log"
        refute_file_matches "{🐶,🐱,🐰}.log", "🐯.log"
      end

      it "wildcard" do
        assert_file_matches "重要/*/中.txt", "重要/子文件夹/中.txt"
        refute_file_matches "重要/*/中.txt", "重要/子文/件夹/中.txt"
      end

      it "globstar" do
        assert_file_matches "重要/**/中.txt", "重要/子文件夹/中.txt"
        assert_file_matches "重要/**/中.txt", "重要/子文/件夹/中.txt"
      end

      it "NFC and NFD are disparate" do
        assert_file_matches "café.txt", "café.txt"   # NFC
        refute_file_matches "café.txt", "café.txt"  # NFD
        refute_file_matches "cafe*.txt", "café.txt"  # NFC
        assert_file_matches "cafe*.txt", "café.txt" # NFD
      end
    end

    describe "invalid byte sequences" do
      it "single-character with invalid path" do
        assert_file_matches "?.txt", "\xC3.txt"         # Invalid byte sequence
        refute_file_matches "?.txt", "\xC3\x28.txt"     # Invalid byte sequence
        refute_file_matches "?.txt", "\xED\xA0\x80.txt" # Lone surrogate
        assert_file_matches "?.txt", "\uFFFF.txt"       # Noncharacter codepoint
      end

      it "single-character with invalid pattern" do
        refute_file_matches "\xC3\x28.txt", "a.txt"     # Invalid byte sequence
        refute_file_matches "\xED\xA0\x80.txt", "b.txt" # Lone surrogate
      end

      it "character set with invalid path" do
        refute_file_matches "[a-z].txt", "\xF0\x28\x8C\x28.txt" # Invalid byte sequence
        refute_file_matches "[A-Z].txt", "\xED\xA0\x80.txt"     # Lone surrogate
      end

      it "character set with invalid pattern" do
        refute_file_matches "[\xC3\x28].txt", "m.txt"     # Invalid byte sequence
        refute_file_matches "[\xED\xA0\x80].txt", "A.txt" # Lone surrogate
      end

      it "character range with invalid path" do
        refute_file_matches "[a-z].txt", "\xED\xA0\x80.txt" # Invalid byte sequence
        refute_file_matches "[α-ω].txt", "\xED\xBF\xBF.txt" # Lone surrogate
        refute_file_matches "[😀-🙏].png", "\xFF\xFE\xFD.png" # Invalid byte sequence
      end

      it "character range with invalid pattern" do
        refute_file_matches "[\xF0\x28\x8C\x28].txt", "o.txt"          # Corrupt range
        refute_file_matches "[\xED\xA0\x80-\xED\xBD\xBF].csv", "X.csv" # Invalid range of surrogates
      end

      it "invalid pattern and path" do
        assert_file_matches "[\xED\xA0\x80-α]?.log", "\xC3\x28.log"      # Lone surrogate in pattern, bad in path
        refute_file_matches "[😀-\uFFFF]?.json", "\xF0\x90\x28\xBC.json"  # Invalid range with corrupt UTF-8
        refute_file_matches "[\xED\xA0\x80-\uFFFF]?", "\xED\xBD\xBF.txt" # Invalid pattern range and lone low surrogate in path
      end
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
