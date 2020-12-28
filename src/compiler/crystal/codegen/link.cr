module Crystal
  struct LinkAnnotation
    getter lib : String?
    getter pkg_config : String?
    getter ldflags : String?
    getter framework : String?

    def initialize(@lib = nil, @pkg_config = @lib, @ldflags = nil, @static = false, @framework = nil)
    end

    def static?
      @static
    end

    def self.from(ann : Annotation)
      args = ann.args
      named_args = ann.named_args

      if args.empty? && !named_args
        ann.raise "missing link arguments: must at least specify a library name"
      end

      lib_name = nil
      lib_ldflags = nil
      lib_static = false
      lib_pkg_config = nil
      lib_framework = nil
      count = 0

      args.each do |arg|
        case count
        when 0
          arg.raise "'lib' link argument must be a String" unless arg.is_a?(StringLiteral)
          lib_name = arg.value
        when 1
          arg.raise "'ldflags' link argument must be a String" unless arg.is_a?(StringLiteral)
          lib_ldflags = arg.value
        when 2
          arg.raise "'static' link argument must be a Bool" unless arg.is_a?(BoolLiteral)
          lib_static = arg.value
        when 3
          arg.raise "'framework' link argument must be a String" unless arg.is_a?(StringLiteral)
          lib_framework = arg.value
        else
          ann.wrong_number_of "link arguments", args.size, "1..4"
        end

        count += 1
      end

      named_args.try &.each do |named_arg|
        value = named_arg.value

        case named_arg.name
        when "lib"
          named_arg.raise "'lib' link argument already specified" if count > 0
          named_arg.raise "'lib' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_name = value.value
        when "ldflags"
          named_arg.raise "'ldflags' link argument already specified" if count > 1
          named_arg.raise "'ldflags' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_ldflags = value.value
        when "static"
          named_arg.raise "'static' link argument already specified" if count > 2
          named_arg.raise "'static' link argument must be a Bool" unless value.is_a?(BoolLiteral)
          lib_static = value.value
        when "framework"
          named_arg.raise "'framework' link argument already specified" if count > 3
          named_arg.raise "'framework' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_framework = value.value
        when "pkg_config"
          named_arg.raise "'pkg_config' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_pkg_config = value.value
        else
          named_arg.raise "unknown link argument: '#{named_arg.name}' (valid arguments are 'lib', 'ldflags', 'static', 'pkg_config' and 'framework')"
        end
      end

      new(lib_name, lib_pkg_config, lib_ldflags, lib_static, lib_framework)
    end
  end

  class CrystalLibraryPath
    def self.default_path : String
      ENV.fetch("CRYSTAL_LIBRARY_PATH", Crystal::Config.library_path)
    end

    class_getter paths : Array(String) do
      default_path.split(Process::PATH_DELIMITER, remove_empty: true)
    end
  end

  class Program
    def object_extension
      has_flag?("windows") ? ".obj" : ".o"
    end

    def lib_flags
      has_flag?("windows") ? lib_flags_windows : lib_flags_posix
    end

    private def lib_flags_windows
      String.build do |flags|
        link_annotations.reverse_each do |ann|
          if ldflags = ann.ldflags
            flags << ' ' << ldflags
          end

          if libname = ann.lib
            flags << ' ' << Process.quote_windows("#{libname}.lib")
          end
        end
      end
    end

    private def lib_flags_posix
      flags = [] of String
      static_build = has_flag?("static")

      # Instruct the linker to link statically if the user asks
      flags << "-static" if static_build

      # Add CRYSTAL_LIBRARY_PATH locations, so the linker preferentially
      # searches user-given library paths.
      CrystalLibraryPath.paths.each do |path|
        flags << Process.quote_posix("-L#{path}")
      end

      link_annotations.reverse_each do |ann|
        if ldflags = ann.ldflags
          flags << ldflags
        end

        # First, check pkg-config for the pkg-config module name if provided, then
        # check pkg-config with the lib name, then fall back to -lname
        if (pkg_config_name = ann.pkg_config) && (flag = pkg_config(pkg_config_name, static_build))
          flags << flag
        elsif (lib_name = ann.lib) && (flag = pkg_config(lib_name, static_build))
          flags << flag
        elsif (lib_name = ann.lib)
          flags << Process.quote_posix("-l#{lib_name}")
        end

        if framework = ann.framework
          flags << "-framework" << Process.quote_posix(framework)
        end
      end

      flags.join(" ")
    end

    PKG_CONFIG_PATH = Process.find_executable("pkg-config")

    # Returns the result of running `pkg-config mod` but returns nil if
    # pkg-config is not installed, or the module does not exist.
    private def pkg_config(mod, static = false) : String?
      return unless pkg_config_path = PKG_CONFIG_PATH
      return unless (Process.run(pkg_config_path, {mod}).success? rescue nil)

      args = ["--libs"]
      args << "--static" if static
      args << mod

      process = Process.new(pkg_config_path, args, input: :close, output: :pipe, error: :inherit)
      flags = process.output.gets_to_end.chomp
      status = process.wait
      if status.success?
        flags
      else
        nil
      end
    end

    # Returns every @[Link] annotation in the program parsed as `LinkAnnotation`
    def link_annotations
      annotations = [] of LinkAnnotation
      add_link_annotations @types, annotations
      annotations
    end

    private def add_link_annotations(types, annotations)
      types.try &.each_value do |type|
        next if type.is_a?(AliasType) || type.is_a?(TypeDefType)

        if type.is_a?(LibType) && type.used? && (link_annotations = type.link_annotations)
          annotations.concat link_annotations
        end

        add_link_annotations type.types?, annotations
      end
    end
  end
end
