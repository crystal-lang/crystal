require "compiler/crystal/config"
require "compiler/crystal/tools/init"
require "file_utils"
require "ini"
require "spec"
require "yaml"

PROJECT_ROOT_DIR = "#{__DIR__}/../../../.."

private def exec_init(project_name, project_dir = nil, type = "lib", force = false, skip_existing = false)
  args = [type, project_name]
  args << project_dir if project_dir
  args << "--force" if force
  args << "--skip-existing" if skip_existing

  config = Crystal::Init.parse_args(args)
  config.silent = true
  Crystal::Init::InitProject.new(config).run
end

# Creates a temporary directory, cd to it and run the block inside it.
# The directory and its content is deleted when the block return.
private def within_temporary_directory
  tmp_path = "#{PROJECT_ROOT_DIR}/tmp/init_spec_tmp_dir-#{Process.pid}"
  Dir.mkdir_p(tmp_path)
  begin
    Dir.cd(tmp_path) do
      yield
    end
  ensure
    FileUtils.rm_rf(tmp_path)
  end
end

private def describe_file(name, &block : String ->)
  describe name do
    it "has proper contents" do
      block.call(File.read(name))
    end
  end
end

private def run_init_project(skeleton_type, name, author, email, github_name, dir = name)
  Crystal::Init::InitProject.new(
    Crystal::Init::Config.new(skeleton_type, name, dir, author, email, github_name, true)
  ).run
end

module Crystal
  describe Init::InitProject do
    within_temporary_directory do
      run_init_project("lib", "example", "John Smith", "john@smith.com", "jsmith")
      run_init_project("app", "example_app", "John Smith", "john@smith.com", "jsmith")
      run_init_project("lib", "example-lib", "John Smith", "john@smith.com", "jsmith")
      run_init_project("lib", "camel_example-camel_lib", "John Smith", "john@smith.com", "jsmith")
      run_init_project("lib", "example", "John Smith", "john@smith.com", "jsmith", dir: "other-example-directory")

      describe_file "example-lib/src/example-lib.cr" do |file|
        file.should contain("Example::Lib")
      end

      describe_file "camel_example-camel_lib/src/camel_example-camel_lib.cr" do |file|
        file.should contain("CamelExample::CamelLib")
      end

      describe_file "example/.gitignore" do |gitignore|
        gitignore.should contain("/docs/")
        gitignore.should contain("/.shards/")
        gitignore.should contain("/shard.lock")
        gitignore.should contain("/lib/")
      end

      describe_file "example_app/.gitignore" do |gitignore|
        gitignore.should contain("/docs/")
        gitignore.should contain("/.shards/")
        gitignore.should_not contain("/shard.lock")
        gitignore.should contain("/lib/")
      end

      {"example", "example_app", "example-lib", "camel_example-camel_lib"}.each do |name|
        describe_file "#{name}/.editorconfig" do |editorconfig|
          parsed = INI.parse(editorconfig)
          cr_ext = parsed["*.cr"]
          cr_ext["charset"].should eq("utf-8")
          cr_ext["end_of_line"].should eq("lf")
          cr_ext["insert_final_newline"].should eq("true")
          cr_ext["indent_style"].should eq("space")
          cr_ext["indent_size"].should eq("2")
          cr_ext["trim_trailing_whitespace"].should eq("true")
        end
      end

      describe_file "example/LICENSE" do |license|
        license.should match %r{Copyright \(c\) \d+ John Smith}
      end

      describe_file "example/README.md" do |readme|
        readme.should contain("# example")

        readme.should contain(%{```yaml
dependencies:
  example:
    github: jsmith/example
```})

        readme.should contain(%{TODO: Write a description here})
        readme.should_not contain(%{TODO: Write installation instructions here})
        readme.should contain(%{require "example"})
        readme.should contain(%{1. Fork it ( https://github.com/jsmith/example/fork )})
        readme.should contain(%{[jsmith](https://github.com/jsmith) John Smith - creator, maintainer})
      end

      describe_file "example_app/README.md" do |readme|
        readme.should contain("# example")

        readme.should_not contain(%{```yaml
dependencies:
  example:
    github: jsmith/example
```})

        readme.should contain(%{TODO: Write a description here})
        readme.should contain(%{TODO: Write installation instructions here})
        readme.should_not contain(%{require "example"})
        readme.should contain(%{1. Fork it ( https://github.com/jsmith/example_app/fork )})
        readme.should contain(%{[jsmith](https://github.com/jsmith) John Smith - creator, maintainer})
      end

      describe_file "example/shard.yml" do |shard_yml|
        parsed = YAML.parse(shard_yml)
        parsed["name"].should eq("example")
        parsed["version"].should eq("0.1.0")
        parsed["authors"].should eq(["John Smith <john@smith.com>"])
        parsed["license"].should eq("MIT")
        parsed["crystal"].should eq(Crystal::Config.version)
        parsed["targets"]?.should be_nil
      end

      describe_file "example_app/shard.yml" do |shard_yml|
        parsed = YAML.parse(shard_yml)
        parsed["targets"].should eq({"example_app" => {"main" => "src/example_app.cr"}})
      end

      describe_file "example/.travis.yml" do |travis|
        parsed = YAML.parse(travis)

        parsed["language"].should eq("crystal")
      end

      describe_file "example/src/example.cr" do |example|
        example.should eq(%{require "./example/*"

# TODO: Write documentation for `Example`
module Example
  # TODO: Put your code here
end
})
      end

      describe_file "example/src/example/version.cr" do |version|
        version.should eq(%{module Example
  VERSION = "0.1.0"
end
})
      end

      describe_file "example/spec/spec_helper.cr" do |example|
        example.should eq(%{require "spec"
require "../src/example"
})
      end

      describe_file "example/spec/example_spec.cr" do |example|
        example.should eq(%{require "./spec_helper"

describe Example do
  # TODO: Write tests

  it "works" do
    false.should eq(true)
  end
end
})
      end

      describe_file "example/.git/config" { }

      describe_file "other-example-directory/.git/config" { }
    end
  end

  describe "Init invocation" do
    it "prints error if a file is already present" do
      within_temporary_directory do
        existing_file = "existing-file"
        File.touch(existing_file)
        expect_raises(Crystal::Init::Error, "#{existing_file.inspect} is a file") do
          exec_init(existing_file)
        end
      end
    end

    it "honors the custom set directory name" do
      within_temporary_directory do
        project_name = "my_project"
        project_dir = "project_dir"

        Dir.mkdir(project_name)
        File.write("README.md", "content before init")

        exec_init(project_name, project_dir)

        File.read("README.md").should eq("content before init")
        File.exists?(File.join(project_dir, "README.md")).should be_true
      end
    end

    it "errors if files will be overwritten by a generated file" do
      within_temporary_directory do
        File.touch("README.md")

        ex = expect_raises(Crystal::Init::FilesConflictError) do
          exec_init("my_lib", ".")
        end
        ex.conflicting_files.should contain("./README.md")
      end
    end

    it "doesn't error if files will be overwritten by a generated file and --force is used" do
      within_temporary_directory do
        File.write("README.md", "content before init")
        File.exists?("README.md").should be_true

        exec_init("my_lib", ".", force: true)

        File.read("README.md").should_not eq("content before init")
        File.exists?("LICENSE").should be_true
      end
    end

    it "doesn't error when asked to skip existing files" do
      within_temporary_directory do
        File.write("README.md", "content before init")

        exec_init("my_lib", ".", skip_existing: true)

        File.read("README.md").should eq("content before init")
        File.exists?("LICENSE").should be_true
      end
    end
  end
end
