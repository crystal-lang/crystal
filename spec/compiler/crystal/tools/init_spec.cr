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

    describe_file "example/.gitignore" do |gitignore|
      expect(gitignore).to contain("/.deps/")
      expect(gitignore).to contain("/.deps.lock")
      expect(gitignore).to contain("/libs/")
      expect(gitignore).to contain("/.crystal/")
    end

    describe_file "example_app/.gitignore" do |gitignore|
      expect(gitignore).to contain("/.deps/")
      expect(gitignore).to_not contain("/.deps.lock")
      expect(gitignore).to contain("/libs/")
      expect(gitignore).to contain("/.crystal/")
    end

    describe_file "example/LICENSE" do |license|
      expect(license).to match %r{Copyright \(c\) \d+ John Smith}
    end

    describe_file "example/README.md" do |readme|
      expect(readme).to contain("# example")

      expect(readme).to contain(%{```crystal
deps do
  github "[your-github-name]/example"
end
```})

      expect(readme).to contain(%{require "example"})
      expect(readme).to contain(%{1. Fork it ( https://github.com/[your-github-name]/example/fork )})
      expect(readme).to contain(%{[your-github-name](https://github.com/[your-github-name]) John Smith - creator, maintainer})
    end

    describe_file "example/Projectfile" do |projectfile|
      expect(projectfile).to eq(%{deps do\nend\n})
    end

    describe_file "example/.travis.yml" do |travis|
      parsed = YAML.load(travis) as Hash

      expect(parsed["language"]).to eq("c")

      expect(parsed["before_install"] as String)
        .to contain("curl http://dist.crystal-lang.org/apt/setup.sh | sudo bash")

      expect(parsed["before_install"] as String)
        .to contain("sudo apt-get -q update")

      expect(parsed["install"] as String)
        .to contain("sudo apt-get install crystal")

      expect(parsed["script"]).to eq(["crystal spec"])
    end

    describe_file "example/src/example.cr" do |example|
      expect(example).to eq(%{require "./example/*"

module Example
  # TODO Put your code here
end
})
    end

    describe_file "example/src/example/version.cr" do |version|
      expect(version).to eq(%{module Example
  VERSION = "0.0.1"
end
})
    end

    describe_file "example/spec/spec_helper.cr" do |example|
      expect(example).to eq(%{require "spec"
require "../src/example"
})
    end

    describe_file "example/spec/example_spec.cr" do |example|
      expect(example).to eq(%{require "./spec_helper"

describe Example do
  # TODO: Write tests

  it "works" do
    expect(false).to eq(true)
  end
end
})
    end

    describe_file "example/.git/config" {}

  end
end
