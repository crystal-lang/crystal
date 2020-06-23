require "../../spec_helper"
require "../../support/env"

private def assert_finds(search, results, relative_to = nil, path = __DIR__, file = __FILE__, line = __LINE__)
  it "finds #{search.inspect}", file, line do
    crystal_path = Crystal::CrystalPath.new(path)
    results = results.map { |result| ::Path[__DIR__, result].normalize.to_s }
    Dir.cd(__DIR__) do
      matches = crystal_path.find search, relative_to: relative_to
      matches.should eq(results), file: file, line: line
    end
  end
end

private def assert_doesnt_find(search, relative_to = nil, path = __DIR__, expected_relative_to = nil, file = __FILE__, line = __LINE__)
  it "doesn't finds #{search.inspect}", file, line do
    crystal_path = Crystal::CrystalPath.new(path)
    Dir.cd(__DIR__) do
      error = expect_raises Crystal::CrystalPath::NotFoundError do
        crystal_path.find search, relative_to: relative_to
      end
      error.relative_to.should eq(expected_relative_to), file: file, line: line
      error.filename.should eq(search), file: file, line: line
    end
  end
end

describe Crystal::CrystalPath do
  assert_finds "test_files/file_one.cr", ["test_files/file_one.cr"]
  assert_finds "test_files/file_one", ["test_files/file_one.cr"]
  assert_finds "test_files/*", [
    "test_files/file_one.cr",
    "test_files/file_two.cr",
  ]
  assert_finds "test_files/**", [
    "test_files/file_one.cr",
    "test_files/file_two.cr",
    "test_files/src/file_three.cr",
    "test_files/src/test_files.cr",
    "test_files/src/test_files/file_four.cr",
    "test_files/src/test_files/another/another.cr",
    "test_files/src/yet_another/yet_another.cr",
    "test_files/test_folder/file_three.cr",
    "test_files/test_folder/test_folder.cr",
  ]
  assert_finds "./file_two.cr", relative_to: "test_files/file_one.cr", results: [
    "test_files/file_two.cr",
  ]
  assert_finds "./test_folder/file_three.cr", relative_to: "test_files/file_one.cr", results: [
    "test_files/test_folder/file_three.cr",
  ]
  assert_finds "./test_folder/*", relative_to: "test_files/file_one.cr", results: [
    "test_files/test_folder/file_three.cr",
    "test_files/test_folder/test_folder.cr",
  ]
  assert_finds "../**", relative_to: "test_files/test_folder/file_three.cr", results: [
    "test_files/file_one.cr",
    "test_files/file_two.cr",
    "test_files/src/file_three.cr",
    "test_files/src/test_files.cr",
    "test_files/src/test_files/file_four.cr",
    "test_files/src/test_files/another/another.cr",
    "test_files/src/yet_another/yet_another.cr",
    "test_files/test_folder/file_three.cr",
    "test_files/test_folder/test_folder.cr",
  ]
  assert_finds "../test_folder", relative_to: "test_files/test_folder/file_three.cr", results: [
    "test_files/test_folder/test_folder.cr",
  ]

  # For `require "foo"`:
  # 1. foo.cr (to find something in the standard library)
  assert_finds "crystal_path_spec", ["crystal_path_spec.cr"]
  # 2. foo/src/foo.cr (to find something in a shard)
  assert_finds "test_files", ["test_files/src/test_files.cr"]

  # For `require "foo/bar"`:
  # 1. foo/bar.cr (to find something in the standard library)
  assert_finds "test_files/file_one", ["test_files/file_one.cr"]
  # 2. foo/src/bar.cr (to find something in a shard, non-namespaced structure)
  assert_finds "test_files/file_three", ["test_files/src/file_three.cr"]
  # 3. foo/src/foo/bar.cr (to find something in a shard, namespaced structure)
  assert_finds "test_files/file_four", ["test_files/src/test_files/file_four.cr"]

  # Nested searches
  # a/1. foo.cr (to find something in the standard library (nested))
  assert_finds "other_test_files", ["other_test_files/other_test_files.cr"]
  # b/2. foo/src/bar/bar.cr (to find something in a shard, non-namespaced structure, nested)
  assert_finds "test_files/yet_another", ["test_files/src/yet_another/yet_another.cr"]
  # b/3. foo/src/foo/bar/bar.cr (to find something in a shard, namespaced structure, nested)
  assert_finds "test_files/another", ["test_files/src/test_files/another/another.cr"]

  assert_doesnt_find "file_two.cr"
  assert_doesnt_find "test_folder/file_three.cr"
  assert_doesnt_find "test_folder/*", relative_to: Path[__DIR__, "test_files", "file_one.cr"].to_s, expected_relative_to: Path[__DIR__, "test_files"].to_s
  assert_doesnt_find "test_files/missing_file.cr"
  assert_doesnt_find __FILE__[1..-1], path: ":"

  # Don't find in CRYSTAL_PATH if the path is relative (#4742)
  assert_doesnt_find "./crystal_path_spec", relative_to: Path["test_files", "file_one.cr"].to_s, expected_relative_to: Path["test_files"].to_s
  assert_doesnt_find "./crystal_path_spec.cr", relative_to: Path["test_files", "file_one.cr"].to_s, expected_relative_to: Path["test_files"].to_s
  assert_doesnt_find "../crystal_path/test_files/file_one"

  # Don't find relative filenames in src or shards
  assert_doesnt_find "../../src/file_three", relative_to: Path["test_files", "test_folder", "test_folder.cr"].to_s, expected_relative_to: Path["test_files", "test_folder"].to_s

  it "includes 'lib' by default" do
    with_env("CRYSTAL_PATH": nil) do
      crystal_path = Crystal::CrystalPath.new
      crystal_path.entries[0].should eq("lib")
    end
  end

  it "overrides path with environment variable" do
    with_env("CRYSTAL_PATH": "foo#{Process::PATH_DELIMITER}bar") do
      crystal_path = Crystal::CrystalPath.new
      crystal_path.entries.should eq(%w(foo bar))
    end
  end
end
