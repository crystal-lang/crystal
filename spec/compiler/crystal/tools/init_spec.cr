require "spec"
require "yaml"
require "compiler/crystal/tools/init"

def describe_file(name)
  describe name do
    it "has proper contents" do
      yield(File.read("tmp/#{name}"))
    end
  end
end

def run_init_project(skeleton_type, name, dir, author)
  Crystal::Init::InitProject.new(
    Crystal::Init::Config.new(skeleton_type, name, dir, author, true)
  ).run
end

module Crystal
  describe Init::InitProject do
    `[ -d tmp/example ] && rm -r tmp/example`
    `[ -d tmp/example_app ] && rm -r tmp/example_app`

    run_init_project("lib", "example", "tmp/example", "John Smith")
    run_init_project("app", "example_app", "tmp/example_app", "John Smith")
    run_init_project("lib", "example-lib", "tmp/example-lib", "John Smith")

    describe_file "example-lib/src/example-lib.cr" do |file|
      file.should contain("Example::Lib")
    end
    
    describe_file "example/.gitignore" do |gitignore|
      gitignore.should contain("/.deps/")
      gitignore.should contain("/.deps.lock")
      gitignore.should contain("/libs/")
      gitignore.should contain("/.crystal/")
    end

    describe_file "example_app/.gitignore" do |gitignore|
      gitignore.should contain("/.deps/")
      gitignore.should_not contain("/.deps.lock")
      gitignore.should contain("/libs/")
      gitignore.should contain("/.crystal/")
    end

    describe_file "example/LICENSE" do |license|
      license.should match %r{Copyright \(c\) \d+ John Smith}
    end

    describe_file "example/README.md" do |readme|
      readme.should contain("# example")

      readme.should contain(%{```crystal
deps do
  github "[your-github-name]/example"
end
```})

      readme.should contain(%{require "example"})
      readme.should contain(%{1. Fork it ( https://github.com/[your-github-name]/example/fork )})
      readme.should contain(%{[your-github-name](https://github.com/[your-github-name]) John Smith - creator, maintainer})
    end

    describe_file "example/Projectfile" do |projectfile|
      projectfile.should eq(%{deps do\nend\n})
    end

    describe_file "example/.travis.yml" do |travis|
      parsed = YAML.load(travis) as Hash

      parsed["language"].should eq("c")

      (parsed["before_install"] as String)
        .should contain("curl http://dist.crystal-lang.org/apt/setup.sh | sudo bash")

      (parsed["before_install"] as String)
        .should contain("sudo apt-get -q update")

      (parsed["install"] as String)
        .should contain("sudo apt-get install crystal")

      parsed["script"].should eq(["crystal spec"])
    end

    describe_file "example/src/example.cr" do |example|
      example.should eq(%{require "./example/*"

module Example
  # TODO Put your code here
end
})
    end

    describe_file "example/src/example/version.cr" do |version|
      version.should eq(%{module Example
  VERSION = "0.0.1"
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

    describe_file "example/.git/config" {}

  end
end
