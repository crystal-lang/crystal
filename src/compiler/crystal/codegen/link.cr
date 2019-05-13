module Crystal
  struct LinkAnnotation
    getter lib : String?
    getter ldflags : String?
    getter framework : String?

    def initialize(@lib = nil, @ldflags = nil, @static = false, @framework = nil)
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
        else
          named_arg.raise "unknown link argument: '#{named_arg.name}' (valid arguments are 'lib', 'ldflags', 'static' and 'framework')"
        end
      end

      new(lib_name, lib_ldflags, lib_static, lib_framework)
    end
  end

  class CrystalLibraryPath
    def self.default_path : String
      ENV.fetch("CRYSTAL_LIBRARY_PATH", Crystal::Config.library_path)
    end

    class_getter paths : Array(String) do
      default_path.split(':', remove_empty: true)
    end
  end

  class Program
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
            flags << ' ' << libname << ".lib"
          end
        end
      end
    end

    private def lib_flags_posix
      library_path = ["/usr/lib", "/usr/local/lib"]
      has_pkg_config = nil

      String.build do |flags|
        link_annotations.reverse_each do |ann|
          if ldflags = ann.ldflags
            flags << ' ' << ldflags
          end

          if libname = ann.lib
            if has_pkg_config.nil?
              has_pkg_config = Process.run("which", {"pkg-config"}, output: Process::Redirect::Close).success?
            end

            static = has_flag?("static") || ann.static?

            if static && (static_lib = find_static_lib(libname, CrystalLibraryPath.paths))
              flags << ' ' << static_lib
            elsif has_pkg_config && (libflags = pkg_config_flags(libname, static, library_path))
              flags << ' ' << libflags
            elsif static && (static_lib = find_static_lib(libname, library_path))
              flags << ' ' << static_lib
            else
              flags << " -l" << libname
            end
          end

          if framework = ann.framework
            flags << " -framework " << framework
          end
        end

        # Append the CRYSTAL_LIBRARY_PATH values as -L flags.
        CrystalLibraryPath.paths.each do |path|
          flags << " -L#{path}"
        end
        # Append the default paths as -L flags in case the linker doesn't know
        # about them (eg: FreeBSD won't search /usr/local/lib by default):
        library_path.each do |path|
          flags << " -L#{path}"
        end
      end
    end

    def link_annotations
      annotations = [] of LinkAnnotation
      add_link_annotations @types, annotations
      annotations
    end

    private def pkg_config_flags(libname, static, library_path)
      if system("pkg-config #{libname}")
        if static
          flags = [] of String
          `pkg-config #{libname} --libs --static`.split.each do |cfg|
            if cfg.starts_with?("-L")
              library_path << cfg[2..-1]
            elsif cfg.starts_with?("-l")
              flags << (find_static_lib(cfg[2..-1], library_path) || cfg)
            else
              flags << cfg
            end
          end
          flags.join ' '
        else
          `pkg-config #{libname} --libs`.chomp
        end
      end
    end

    private def find_static_lib(libname, library_path)
      library_path.each do |libdir|
        static_lib = "#{libdir}/lib#{libname}.a"
        return static_lib if File.exists?(static_lib)
      end
      nil
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
