# Implementation of the `crystal init` command

require "ecr/macros"
require "option_parser"
require "./git"

module Crystal
  module Init
    class Error < Crystal::Error
      def self.new(message, opts : OptionParser)
        new("#{message}\n#{opts}\n")
      end
    end

    class FilesConflictError < Error
      getter conflicting_files : Array(String)

      def initialize(@conflicting_files)
        super("Some files would be overwritten: #{conflicting_files.join(", ")}")
      end
    end

    def self.run(args)
      config = parse_args(args)
      InitProject.new(config).run
    rescue ex : Init::FilesConflictError
      STDERR.puts "Cannot initialize Crystal project, the following files would be overwritten:"
      ex.conflicting_files.each do |path|
        STDERR.puts "   #{"file".colorize(:red)} #{path} #{"already exist".colorize(:red)}"
      end
      STDERR.puts "You can use --force to overwrite those files,"
      STDERR.puts "or --skip-existing to skip existing files and generate the others."
      exit 1
    rescue ex : Init::Error
      STDERR.puts "Cannot initialize Crystal project: #{ex}"
      exit 1
    end

    def self.parse_args(args)
      config = Config.new

      OptionParser.parse(args) do |opts|
        opts.banner = <<-USAGE
          Usage: crystal init TYPE (DIR | NAME DIR)

          Initializes a project folder as a git repository and default folder
          structure for Crystal projects.

          TYPE is one of:
              lib                      Creates a library skeleton
              app                      Creates an application skeleton

          DIR  - directory where project will be generated
          NAME - name of project to be generated, default: basename of DIR

          USAGE

        opts.on("-h", "--help", "show this help") do
          puts opts
          exit
        end

        opts.on("-f", "--force", "force overwrite existing files") do
          config.force = true
        end

        opts.on("-s", "--skip-existing", "skip existing files") do
          config.skip_existing = true
        end

        opts.unknown_args do |args, after_dash|
          config.skeleton_type = fetch_skeleton_type(opts, args)
          dir = fetch_required_parameter(opts, args, "DIR")
          if args.empty?
            # crystal init TYPE DIR
            config.dir = dir
            config.name = config.expanded_dir.basename
          else
            # crystal init TYPE NAME DIR
            config.name = dir
            config.dir = args.shift
          end
        end
      end

      if config.force && config.skip_existing
        raise Error.new "Cannot use --force and --skip-existing together"
      end

      validate_name(config.name)

      config.author = fetch_author
      config.email = fetch_email
      config.github_name = fetch_github_name
      config
    end

    def self.fetch_author
      Crystal::Git.git_config("user.name") || "your-name-here"
    end

    def self.fetch_email
      Crystal::Git.git_config("user.email") || "your-email-here"
    end

    def self.fetch_github_name
      Crystal::Git.git_config("github.user") || "your-github-user"
    end

    def self.fetch_skeleton_type(opts, args)
      skeleton_type = fetch_required_parameter(opts, args, "TYPE")
      unless skeleton_type.in?("lib", "app")
        raise Error.new "Invalid TYPE value: #{skeleton_type}", opts
      end
      skeleton_type
    end

    def self.fetch_required_parameter(opts, args, name)
      if args.empty?
        raise Error.new "Argument #{name} is missing", opts
      end
      args.shift
    end

    def self.validate_name(name)
      case
      when name.blank?                       then raise Error.new("NAME must not be empty")
      when name.size > 50                    then raise Error.new("NAME must not be longer than 50 characters")
      when name.each_char.any?(&.uppercase?) then raise Error.new("NAME should be all lower cased")
      when !name[0].ascii_letter?            then raise Error.new("NAME must start with a letter")
      when name.index("--")                  then raise Error.new("NAME must not have consecutive dashes")
      when name.index("__")                  then raise Error.new("NAME must not have consecutive underscores")
      when !name.each_char.all? { |c| c.alphanumeric? || c.in?('-', '_') }
        raise Error.new("NAME must only contain alphanumerical characters, underscores or dashes")
      else
        # name is valid
      end
    end

    class Config
      property skeleton_type : String
      property name : String
      property dir : String
      property author : String
      property email : String
      property github_name : String
      property silent : Bool
      property force : Bool
      property skip_existing : Bool

      def initialize(
        @skeleton_type = "none",
        @name = "none",
        @dir = "none",
        @author = "none",
        @email = "none",
        @github_name = "none",
        @silent = false,
        @force = false,
        @skip_existing = false,
      )
      end

      getter expanded_dir : ::Path { ::Path.new(dir).expand(home: true) }

      getter github_repo : String { "#{github_name}/#{expanded_dir.basename}" }
    end

    abstract class View
      getter config : Config
      getter full_path : ::Path

      @@views = [] of View.class

      def self.views
        @@views
      end

      def self.register(view)
        views << view
      end

      def initialize(@config)
        @full_path = config.expanded_dir.join(path)
      end

      def overwriting?
        File.exists?(full_path)
      end

      def render
        overwriting = overwriting?

        Dir.mkdir_p(full_path.dirname)
        File.write(full_path, to_s)
        puts log_message(overwriting) unless config.silent
      end

      def log_message(overwriting = false)
        if overwriting
          " #{"overwrite".colorize(:light_green)}  #{full_path}"
        else
          "    #{"create".colorize(:light_green)}  #{full_path}"
        end
      end

      def module_name
        View.module_name(config.name)
      end

      def self.module_name(name)
        name
          .gsub(/[-_]([^a-z])/i, "\\1")
          .split('-')
          .compact_map do |name|
            name.camelcase if name[0]?.try(&.ascii_letter?)
          end
          .join("::")
      end

      abstract def path
    end

    class InitProject
      getter config : Config

      def initialize(@config : Config)
      end

      def overwrite_checks(views)
        existing_views, new_views = views.partition(&.overwriting?)

        if existing_views.present? && !config.skip_existing
          raise FilesConflictError.new existing_views.map(&.path)
        end

        new_views
      end

      def run
        if (info = File.info?(config.expanded_dir)) && !info.directory?
          raise Error.new "#{config.dir.inspect} is a #{info.type.to_s.downcase}"
        end

        views = self.views

        unless config.force
          views = overwrite_checks(views)
        end

        views.each &.render
      end

      private def views
        View.views.map(&.new(config))
      end
    end

    class GitInitView < View
      def render
        Crystal::Git.git_command(["init", config.dir], output: config.silent ? Process::Redirect::Close : STDOUT)
      end

      def path
        ".git"
      end
    end

    TEMPLATE_DIR = "#{__DIR__}/init/template"

    macro template(name, template_path, destination_path)
      class {{ name.id }} < View
        ECR.def_to_s {{ "#{TEMPLATE_DIR.id}/#{template_path.id}" }}

        def path
          {{ destination_path }}
        end
      end

      View.register({{ name.id }})
    end

    template GitignoreView, "gitignore.ecr", ".gitignore"
    template EditorconfigView, "editorconfig.ecr", ".editorconfig"
    template LicenseView, "license.ecr", "LICENSE"
    template ReadmeView, "readme.md.ecr", "README.md"
    template ShardView, "shard.yml.ecr", "shard.yml"

    template SrcExampleView, "example.cr.ecr", "src/#{config.name}.cr"

    template SpecHelperView, "spec_helper.cr.ecr", "spec/spec_helper.cr"
    template SpecExampleView, "example_spec.cr.ecr", "spec/#{config.name}_spec.cr"

    View.register(GitInitView)
  end
end
