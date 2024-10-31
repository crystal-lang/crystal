require "compiler/crystal/syntax"
require "compiler/crystal/config"
require "compiler/crystal/tools/init"
require "file_utils"
require "ini"
require "spec"
require "yaml"
require "../../../support/tempfile"
require "../../../support/env"
require "../../../support/win32"

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
private def within_temporary_directory(&)
  with_tempfile "init_spec_tmp" do |tmp_path|
    Dir.mkdir_p(tmp_path)
    Dir.cd(tmp_path) do
      yield
    end
  end
end

private def with_file(name, &)
  yield File.read(name)
end

private def run_init_project(skeleton_type, name, author, email, github_name, dir = name)
  Crystal::Init::InitProject.new(
    Crystal::Init::Config.new(skeleton_type, name, dir, author, email, github_name, true)
  ).run
end

private def git_available?
  Process.run(Crystal::Git.executable).success?
rescue IO::Error
  false
end

module Crystal
  describe Init::InitProject do
    it "correctly uses git config" do
      pending! "Git is not available" unless git_available?

      within_temporary_directory do
        File.write(".gitconfig", <<-INI)
        [user]
          email = dorian@dorianmarie.fr
          name = Dorian Marié
        INI

        with_env("GIT_CONFIG": "#{FileUtils.pwd}/.gitconfig") do
          exec_init("example", "example", "app")
        end

        with_file "example/LICENSE" do |file|
          file.should contain("Dorian Marié")
        end
      end
    end

    it "has proper contents" do
      within_temporary_directory do
        run_init_project("lib", "example", "John Smith", "john@smith.com", "jsmith")
        run_init_project("app", "example_app", "John Smith", "john@smith.com", "jsmith")
        run_init_project("app", "num-followed-hyphen-1", "John Smith", "john@smith.com", "jsmith")
        run_init_project("lib", "example-lib", "John Smith", "john@smith.com", "jsmith")
        run_init_project("lib", "camel_example-camel_lib", "John Smith", "john@smith.com", "jsmith")
        run_init_project("lib", "example", "John Smith", "john@smith.com", "jsmith", dir: "other-example-directory")

        with_file "example-lib/src/example-lib.cr" do |file|
          file.should contain("Example::Lib")
        end

        with_file "camel_example-camel_lib/src/camel_example-camel_lib.cr" do |file|
          file.should contain("CamelExample::CamelLib")
        end

        with_file "num-followed-hyphen-1/src/num-followed-hyphen-1.cr" do |file|
          file.should contain("Num::Followed::Hyphen1")
        end

        with_file "example/.gitignore" do |gitignore|
          gitignore.should contain("/docs/")
          gitignore.should contain("/.shards/")
          gitignore.should contain("/shard.lock")
          gitignore.should contain("/lib/")
        end

        with_file "example_app/.gitignore" do |gitignore|
          gitignore.should contain("/docs/")
          gitignore.should contain("/.shards/")
          gitignore.should_not contain("/shard.lock")
          gitignore.should contain("/lib/")
        end

        {"example", "example_app", "example-lib", "camel_example-camel_lib"}.each do |name|
          with_file "#{name}/.editorconfig" do |editorconfig|
            parsed = INI.parse(editorconfig)
            parsed[""]["root"].should eq("true")
            cr_ext = parsed["*.cr"]
            cr_ext["charset"].should eq("utf-8")
            cr_ext["end_of_line"].should eq("lf")
            cr_ext["insert_final_newline"].should eq("true")
            cr_ext["indent_style"].should eq("space")
            cr_ext["indent_size"].should eq("2")
            cr_ext["trim_trailing_whitespace"].should eq("true")
          end
        end

        with_file "example/LICENSE" do |license|
          license.should match %r{Copyright \(c\) \d+ John Smith}
        end

        with_file "example/README.md" do |readme|
          readme.should contain("# example")

          readme.should contain(%{1. Add the dependency to your `shard.yml`:})
          readme.should contain(<<-MARKDOWN

           ```yaml
           dependencies:
             example:
               github: jsmith/example
           ```

        MARKDOWN
          )
          readme.should contain(%{2. Run `shards install`})
          readme.should contain(%{TODO: Write a description here})
          readme.should_not contain(%{TODO: Write installation instructions here})
          readme.should contain(%{require "example"})
          readme.should contain(%{1. Fork it (<https://github.com/jsmith/example/fork>)})
          readme.should contain(%{[John Smith](https://github.com/jsmith) - creator and maintainer})
        end

        with_file "example_app/README.md" do |readme|
          readme.should contain("# example")

          readme.should contain(%{TODO: Write a description here})

          readme.should_not contain(%{1. Add the dependency to your `shard.yml`:})
          readme.should_not contain(<<-MARKDOWN

           ```yaml
           dependencies:
             example:
               github: jsmith/example
           ```

        MARKDOWN
          )
          readme.should_not contain(%{2. Run `shards install`})
          readme.should contain(%{TODO: Write installation instructions here})
          readme.should_not contain(%{require "example"})
          readme.should contain(%{1. Fork it (<https://github.com/jsmith/example_app/fork>)})
          readme.should contain(%{[John Smith](https://github.com/jsmith) - creator and maintainer})
        end

        with_file "example/shard.yml" do |shard_yml|
          parsed = YAML.parse(shard_yml)
          parsed["name"].should eq("example")
          parsed["version"].should eq("0.1.0")
          parsed["authors"].should eq(["John Smith <john@smith.com>"])
          parsed["license"].should eq("MIT")
          parsed["crystal"].should eq(">= #{Crystal::Config.version}")
          parsed["targets"]?.should be_nil
        end

        with_file "example_app/shard.yml" do |shard_yml|
          parsed = YAML.parse(shard_yml)
          parsed["targets"].should eq({"example_app" => {"main" => "src/example_app.cr"}})
        end

        with_file "example/src/example.cr" do |example|
          example.should eq(<<-CRYSTAL
        # TODO: Write documentation for `Example`
        module Example
          VERSION = "0.1.0"

          # TODO: Put your code here
        end

        CRYSTAL
          )
        end

        with_file "example/spec/spec_helper.cr" do |example|
          example.should eq(<<-CRYSTAL
        require "spec"
        require "../src/example"

        CRYSTAL
          )
        end

        with_file "example/spec/example_spec.cr" do |example|
          example.should eq(<<-CRYSTAL
        require "./spec_helper"

        describe Example do
          # TODO: Write tests

          it "works" do
            false.should eq(true)
          end
        end

        CRYSTAL
          )
        end

        if git_available?
          with_file "example/.git/config" { }

          with_file "other-example-directory/.git/config" { }
        end
      end
    end
  end

  describe "Init invocation" do
    it "produces valid yaml file" do
      within_temporary_directory do
        exec_init("example", "example", "app")

        with_file "example/shard.yml" do |file|
          YAML.parse(file)
        end
      end
    end

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
        File.write("README.md", "content before init")

        ex = expect_raises(Crystal::Init::FilesConflictError) do
          exec_init("my_lib", ".")
        end
        ex.conflicting_files.should contain("README.md")

        File.read("README.md").should eq("content before init")
        File.exists?("LICENSE").should_not be_true
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

  describe ".parse_args" do
    it "DIR" do
      config = Crystal::Init.parse_args(["lib", "foo"])
      config.name.should eq "foo"
      config.dir.should eq "foo"
      config.expanded_dir.should eq ::Path[Dir.current, "foo"]
    end

    it "DIR with path" do
      path = ::Path["foo", "bar"].to_s
      config = Crystal::Init.parse_args(["lib", path])
      config.name.should eq "bar"
      config.dir.should eq path
      config.expanded_dir.should eq ::Path[Dir.current, "foo", "bar"]
    end

    it "DIR (relative to home)" do
      path = ::Path["~", "foo"].to_s
      config = Crystal::Init.parse_args(["lib", path])
      config.name.should eq "foo"
      config.dir.should eq path
      config.expanded_dir.should eq ::Path.home.join("foo")
    end

    it "DIR (absolute)" do
      path = ::Path[::Path[Dir.current].anchor.to_s, "foo"].to_s
      config = Crystal::Init.parse_args(["lib", path])
      config.name.should eq "foo"
      config.dir.should eq path
      config.expanded_dir.should eq ::Path[path]
    end

    it "DIR = ." do
      within_temporary_directory do
        config = Crystal::Init.parse_args(["lib", "."])
        config.name.should eq File.basename(Dir.current)
        config.dir.should eq "."
        config.expanded_dir.should eq ::Path[Dir.current]
      end
    end

    it "NAME DIR" do
      config = Crystal::Init.parse_args(["lib", "foo", "foo-shard"])
      config.name.should eq "foo"
      config.dir.should eq "foo-shard"
      config.expanded_dir.should eq ::Path[Dir.current, "foo-shard"]
    end
  end

  describe ".validate_name" do
    it "empty" do
      expect_raises Crystal::Init::Error, "NAME must not be empty" do
        Crystal::Init.validate_name("")
      end
    end
    it "length" do
      Crystal::Init.validate_name("a" * 50)
      expect_raises Crystal::Init::Error, "NAME must not be longer than 50 characters" do
        Crystal::Init.validate_name("a" * 51)
      end
    end
    it "uppercase" do
      expect_raises Crystal::Init::Error, "NAME should be all lower cased" do
        Crystal::Init.validate_name("Foo")
      end
    end
    it "digits" do
      Crystal::Init.validate_name("i18n")
      expect_raises Crystal::Init::Error, "NAME must start with a letter" do
        Crystal::Init.validate_name("4u")
      end
    end
    it "dashes" do
      Crystal::Init.validate_name("foo-bar")
      expect_raises Crystal::Init::Error, "NAME must start with a letter" do
        Crystal::Init.validate_name("-foo")
      end
      expect_raises Crystal::Init::Error, "NAME must not have consecutive dashes" do
        Crystal::Init.validate_name("foo--bar")
      end
    end
    it "underscores" do
      Crystal::Init.validate_name("foo_bar")
      expect_raises Crystal::Init::Error, "NAME must start with a letter" do
        Crystal::Init.validate_name("_foo")
      end
      expect_raises Crystal::Init::Error, "NAME must not have consecutive underscores" do
        Crystal::Init.validate_name("foo__bar")
      end
    end
    it "invalid character" do
      expect_raises Crystal::Init::Error, "NAME must only contain alphanumerical characters, underscores or dashes" do
        Crystal::Init.validate_name("foo bar")
      end
      expect_raises Crystal::Init::Error, "NAME must only contain alphanumerical characters, underscores or dashes" do
        Crystal::Init.validate_name("foo\abar")
      end
      Crystal::Init.validate_name("grüß-gott")
    end
  end

  describe "View#module_name" do
    it "namespace is divided by hyphen" do
      Crystal::Init::View.module_name("my-proj-name").should eq "My::Proj::Name"
    end
    it "hyphen followed by non-ascii letter is replaced by its character" do
      Crystal::Init::View.module_name("my-proj-1").should eq "My::Proj1"
    end
    it "underscore is ignored" do
      Crystal::Init::View.module_name("my-proj_name").should eq "My::ProjName"
    end
  end
end
