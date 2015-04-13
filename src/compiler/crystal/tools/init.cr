require "ecr/macros"
require "option_parser"

module Crystal
  module Init
    WHICH_GIT_COMMAND = "which git >/dev/null"

    def self.run(args)
      config = Config.new

      OptionParser.parse(args) do |opts|
        opts.banner = %{USAGE: crystal init TYPE NAME [DIR]

TYPE is one of:
    lib                      creates library skeleton
    app                      creates application skeleton

NAME - name of project to be generated,
       eg: example
DIR  - directory where project will be generated,
       default: NAME, eg: ./custom/path/example
}

        opts.on("--help", "Shows this message") do
          puts opts
          exit
        end

        opts.unknown_args do |args, after_dash|
          config.skeleton_type = fetch_skeleton_type(opts, args)
          config.name = fetch_required_parameter(opts, args, "NAME")
          config.dir = args.empty? ? config.name : args.shift
        end
      end

      config.author = fetch_author
      InitProject.new(config).run
    end

    def self.fetch_author
      return "[your-name-here]" unless system(WHICH_GIT_COMMAND)
      `git config --get user.name`.strip
    end

    def self.fetch_skeleton_type(opts, args)
      skeleton_type = fetch_required_parameter(opts, args, "TYPE")
      unless {"lib", "app"}.includes?(skeleton_type)
        puts "invalid TYPE value: #{skeleton_type}"
        puts opts
        exit 1
      end
      skeleton_type
    end

    def self.fetch_required_parameter(opts, args, name)
      if args.empty?
        puts "#{name} is missing"
        puts opts
        exit 1
      end
      args.shift
    end

    class Config
      property skeleton_type
      property name
      property dir
      property author
      property silent

      def initialize
        @skeleton_type = "none"
        @name = "none"
        @dir = "none"
        @author = "none"
        @silent = false
      end

      def initialize(@skeleton_type, @name, @dir, @author, @silent = false)
      end
    end

    abstract class View
      getter config

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
        config.name.camelcase
      end

      abstract def full_path
    end

    class InitProject
      getter config

      @@views = [] of View.class

      def initialize(@config)
      end

      def run
        views.each do |view|
          view.new(config).render
        end
      end

      def views
        self.class.views
      end

      def self.views
        @@views
      end

      def self.register_view(view)
        views << view
      end
    end

    class GitInitView < View
      getter config

      def initialize(@config)
      end

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
        ecr_file "{{TEMPLATE_DIR.id}}/{{template_path.id}}"
        def full_path
          "#{config.dir}/#{{{full_path}}}"
        end
      end

      InitProject.register_view({{name.id}})
    end

    template GitignoreView, "gitignore.ecr", ".gitignore"
    template LicenseView, "license.ecr", "LICENSE"
    template ReadmeView, "readme.md.ecr", "README.md"
    template TravisView, "travis.yml.ecr", ".travis.yml"
    template ProjectileView, "projectfile.ecr", "Projectfile"

    template SrcExampleView, "example.cr.ecr", "src/#{config.name}.cr"
    template SrcVersionView, "version.cr.ecr", "src/#{config.name}/version.cr"

    template SpecHelperView, "spec_helper.cr.ecr", "spec/spec_helper.cr"
    template SpecExampleView, "example_spec.cr.ecr", "spec/#{config.name}_spec.cr"

    InitProject.register_view(GitInitView)
  end
end
