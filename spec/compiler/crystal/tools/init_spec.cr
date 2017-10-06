require "spec"
require "yaml"
require "ini"
require "compiler/crystal/config"
require "compiler/crystal/tools/init"

private def describe_file(name, &block : String ->)
  describe name do
    it "has proper contents" do
      block.call(File.read("tmp/#{name}"))
    end
  end
end

private def run_init_project(skeleton_type, name, dir, author, email, github_name)
  Crystal::Init::InitProject.new(
    Crystal::Init::Config.new(skeleton_type, name, dir, author, email, github_name, true)
  ).run
end

module Crystal
  describe Init::InitProject do
    `[ -d tmp/example ] && rm -r tmp/example`
    `[ -d tmp/example_app ] && rm -r tmp/example_app`

    run_init_project("lib", "example", "tmp/example", "John Smith", "john@smith.com", "jsmith")
    run_init_project("app", "example_app", "tmp/example_app", "John Smith", "john@smith.com", "jsmith")
    run_init_project("lib", "example-lib", "tmp/example-lib", "John Smith", "john@smith.com", "jsmith")
    run_init_project("lib", "camel_example-camel_lib", "tmp/camel_example-camel_lib", "John Smith", "john@smith.com", "jsmith")
    run_init_project("lib", "example", "tmp/other-example-directory", "John Smith", "john@smith.com", "jsmith")

    describe_file "example-lib/src/example-lib.cr" do |file|
      file.should contain("Example::Lib")
    end

    describe_file "camel_example-camel_lib/src/camel_example-camel_lib.cr" do |file|
      file.should contain("CamelExample::CamelLib")
    end

    describe_file "example/.gitignore" do |gitignore|
      gitignore.should contain("/.shards/")
      gitignore.should contain("/shard.lock")
      gitignore.should contain("/lib/")
    end

    describe_file "example_app/.gitignore" do |gitignore|
      gitignore.should contain("/.shards/")
      gitignore.should_not contain("/shard.lock")
      gitignore.should contain("/lib/")
    end

    ["example", "example_app", "example-lib", "camel_example-camel_lib"].each do |name|
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

  describe Init do
    it "prints error if a directory already present" do
      Dir.mkdir_p("#{__DIR__}/tmp")

      `bin/crystal init lib "#{__DIR__}/tmp" 2>&1 >/dev/null`.should contain("file or directory #{__DIR__}/tmp already exists")

      `rm -rf #{__DIR__}/tmp`
    end

    it "prints error if a file already present" do
      File.open("#{__DIR__}/tmp", "w")

      `bin/crystal init lib "#{__DIR__}/tmp" 2>&1 >/dev/null`.should contain("file or directory #{__DIR__}/tmp already exists")

      File.delete("#{__DIR__}/tmp")
    end

    it "honors the custom set directory name" do
      Dir.mkdir_p("tmp")

      `bin/crystal init lib tmp 2>&1 >/dev/null`.should contain("file or directory tmp already exists")

      `bin/crystal init lib tmp "#{__DIR__}/fresh-new-tmp" 2>&1 >/dev/null`.should_not contain("file or directory tmp already exists")

      `bin/crystal init lib tmp "#{__DIR__}/fresh-new-tmp" 2>&1 >/dev/null`.should contain("file or directory #{__DIR__}/fresh-new-tmp already exists")

      `rm -rf tmp #{__DIR__}/fresh-new-tmp`
    end
  end
end
