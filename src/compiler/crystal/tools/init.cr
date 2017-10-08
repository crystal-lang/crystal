# Implementation of the `crystal init` command

require "ecr/macros"
require "option_parser"

module Crystal
  module Init
    WHICH_GIT_COMMAND = "which git >/dev/null"

    def self.run(args)
      config = Config.new

      OptionParser.parse(args) do |opts|
        opts.banner = <<-USAGE
          Usage: crystal init TYPE NAME [DIR]

          TYPE is one of:
              lib                      creates library skeleton
              app                      creates application skeleton

          NAME - name of project to be generated,
                 eg: example
          DIR  - directory where project will be generated,
                 default: NAME, eg: ./custom/path/example

          USAGE

        opts.on("--help", "show this help") do
          puts opts
          exit
        end

        opts.unknown_args do |args, after_dash|
          config.skeleton_type = fetch_skeleton_type(opts, args)
          config.name = fetch_name(opts, args)
          config.dir = fetch_directory(args, config.name)
        end
      end

      config.author = fetch_author
      config.email = fetch_email
      config.github_name = fetch_github_name
      InitProject.new(config).run
    end

    def self.fetch_author
      return "[your-name-here]" unless system(WHICH_GIT_COMMAND)
      `git config --get user.name`.strip
    end

    def self.fetch_email
      return "[your-email-here]" unless system(WHICH_GIT_COMMAND)
      `git config --get user.email`.strip
    end

    def self.fetch_github_name
      default = "[your-github-name]"
      return default unless system(WHICH_GIT_COMMAND)
      github_user = `git config --get github.user`.strip
      github_user.empty? ? default : github_user
    end

    def self.fetch_name(opts, args)
      fetch_required_parameter(opts, args, "NAME")
    end

    def self.fetch_directory(args, project_name)
      directory = args.empty? ? project_name : args.shift
      if Dir.exists?(directory) || File.exists?(directory)
        STDERR.puts "file or directory #{directory} already exists"
        exit 1
      end
      directory
    end

    def self.fetch_skeleton_type(opts, args)
      skeleton_type = fetch_required_parameter(opts, args, "TYPE")
      unless {"lib", "app"}.includes?(skeleton_type)
        STDERR.puts "invalid TYPE value: #{skeleton_type}"
        STDERR.puts opts
        exit 1
      end
      skeleton_type
    end

    def self.fetch_required_parameter(opts, args, name)
      if args.empty?
        STDERR.puts "#{name} is missing"
        STDERR.puts opts
        exit 1
      end
      args.shift
    end

    class Config
      property skeleton_type : String
      property name : String
      property dir : String
      property author : String
      property email : String
      property github_name : String
      property silent : Bool

      def initialize(
        @skeleton_type = "none",
        @name = "none",
        @dir = "none",
        @author = "none",
        @email = "none",
        @github_name = "none",
        @silent = false
      )
      end
    end

    abstract class View
      getter config : Config

      @@views = [] of View.class

      def self.views
        @@views
      end

      def self.register(view)
        views << view
      end

      def initialize(@config)
      end

      def render
        Dir.mkdir_p(File.dirname(full_path))
        File.write(full_path, to_s)
        puts log_message unless config.silent
      end

      def log_message
        "      #{"create".colorize(:light_green)}  #{full_path}"
      end

      def module_name
        config.name.split("-").map(&.camelcase).join("::")
      end

      abstract def full_path
    end

    class InitProject
      getter config : Config

      def initialize(@config : Config)
      end

      def run
        views.each do |view|
          view.new(config).render
        end
      end

      def views
        View.views
      end
    end

    class GitInitView < View
      def render
        return unless system(WHICH_GIT_COMMAND)
        return command if config.silent
        puts command
      end

      def full_path
        "#{config.dir}/.git"
      end

      private def command
        `git init #{config.dir}`
      end
    end

    TEMPLATE_DIR = "#{__DIR__}/init/template"

    macro template(name, template_path, full_path)
      class {{name.id}} < View
        ECR.def_to_s "{{TEMPLATE_DIR.id}}/{{template_path.id}}"
        def full_path
          "#{config.dir}/#{{{full_path}}}"
        end
      end

      View.register({{name.id}})
    end

    template GitignoreView, "gitignore.ecr", ".gitignore"
    template EditorconfigView, "editorconfig.ecr", ".editorconfig"
    template LicenseView, "license.ecr", "LICENSE"
    template ReadmeView, "readme.md.ecr", "README.md"
    template TravisView, "travis.yml.ecr", ".travis.yml"
    template ShardView, "shard.yml.ecr", "shard.yml"

    template SrcExampleView, "example.cr.ecr", "src/#{config.name}.cr"
    template SrcVersionView, "version.cr.ecr", "src/#{config.name}/version.cr"

    template SpecHelperView, "spec_helper.cr.ecr", "spec/spec_helper.cr"
    template SpecExampleView, "example_spec.cr.ecr", "spec/#{config.name}_spec.cr"

    View.register(GitInitView)
  end
end
