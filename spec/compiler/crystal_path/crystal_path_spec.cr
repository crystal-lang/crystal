require "../../spec_helper"

private def assert_finds(search, results, relative_to = nil, path = __DIR__, file = __FILE__, line = __LINE__)
  it "finds #{search.inspect}", file, line do
    crystal_path = Crystal::CrystalPath.new(path)
    relative_to = "#{__DIR__}/#{relative_to}" if relative_to
    results = results.map { |result| "#{__DIR__}/#{result}" }
    matches = crystal_path.find search, relative_to: relative_to
    matches.should eq(results)
  end
end

private def assert_doesnt_find(search, relative_to = nil, path = __DIR__, file = __FILE__, line = __LINE__)
  it "doesn't finds #{search.inspect}", file, line do
    crystal_path = Crystal::CrystalPath.new(path)
    relative_to = "#{__DIR__}/#{relative_to}" if relative_to
    expect_raises Exception, /can't find file/ do
      crystal_path.find search, relative_to: relative_to
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
  assert_doesnt_find "test_folder/*", relative_to: "#{__DIR__}/test_files/file_one.cr"
  assert_doesnt_find "test_files/missing_file.cr"
  assert_doesnt_find __FILE__[1..-1], path: ":"

  # Don't find in CRYSTAL_PATH if the path is relative (#4742)
  assert_doesnt_find "./crystal_path_spec", relative_to: "test_files/file_one.cr"
  assert_doesnt_find "./crystal_path_spec.cr", relative_to: "test_files/file_one.cr"
  assert_doesnt_find "../crystal_path/test_files/file_one"
end
