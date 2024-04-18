{% if flag?(:msvc) %}
  require "crystal/system/win32/visual_studio"
  require "crystal/system/win32/windows_sdk"
{% end %}

module Crystal
  struct LinkAnnotation
    getter lib : String?
    getter pkg_config : String?
    getter ldflags : String?
    getter framework : String?
    getter wasm_import_module : String?
    getter dll : String?

    def initialize(@lib = nil, @pkg_config = @lib, @ldflags = nil, @static = false, @framework = nil, @wasm_import_module = nil, @dll = nil)
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
      lib_wasm_import_module = nil
      lib_dll = nil
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
        when "wasm_import_module"
          named_arg.raise "'wasm_import_module' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_wasm_import_module = value.value
        when "dll"
          named_arg.raise "'dll' link argument must be a String" unless value.is_a?(StringLiteral)
          lib_dll = value.value
          unless lib_dll.size >= 4 && lib_dll[-4..].compare(".dll", case_insensitive: true) == 0
            named_arg.raise "'dll' link argument must use a '.dll' file extension"
          end
          if ::Path.separators(::Path::Kind::WINDOWS).any? { |separator| lib_dll.includes?(separator) }
            named_arg.raise "'dll' link argument must not include directory separators"
          end
        else
          named_arg.raise "unknown link argument: '#{named_arg.name}' (valid arguments are 'lib', 'ldflags', 'static', 'pkg_config', 'framework', 'wasm_import_module', and 'dll')"
        end
      end

      new(lib_name, lib_pkg_config, lib_ldflags, lib_static, lib_framework, lib_wasm_import_module, lib_dll)
    end
  end

  module CrystalLibraryPath
    def self.default_paths : Array(String)
      paths = ENV.fetch("CRYSTAL_LIBRARY_PATH", Crystal::Config.library_path).split(Process::PATH_DELIMITER, remove_empty: true)

      CrystalPath.expand_paths(paths)

      paths
    end

    def self.default_path : String
      default_paths.join(Process::PATH_DELIMITER)
    end

    def self.default_rpath : String
      # do not call `CrystalPath.expand_paths`, as `$ORIGIN` inside this env
      # variable is always expanded at run time
      ENV.fetch("CRYSTAL_LIBRARY_RPATH", "")
    end

    # Adds the compiler itself's RPATH to the environment for the duration of
    # the block. `$ORIGIN` in the compiler's RPATH is expanded immediately, but
    # `$ORIGIN`s in the existing environment variable are not expanded. For
    # example, on Linux:
    #
    # - CRYSTAL_LIBRARY_RPATH of the compiler: `$ORIGIN/so`
    # - Current $CRYSTAL_LIBRARY_RPATH: `/home/foo:$ORIGIN/mylibs`
    # - Compiler's full path: `/opt/crystal`
    # - Generated executable's Crystal::LIBRARY_RPATH: `/home/foo:$ORIGIN/mylibs:/opt/so`
    #
    # On Windows we additionally append the compiler's parent directory to the
    # list, as if by appending `$ORIGIN` to the compiler's RPATH. This directory
    # is effectively the first search entry on any Windows executable. Example:
    #
    # - CRYSTAL_LIBRARY_RPATH of the compiler: `$ORIGIN\dll`
    # - Current %CRYSTAL_LIBRARY_RPATH%: `C:\bar;$ORIGIN\mylibs`
    # - Compiler's full path: `C:\foo\crystal.exe`
    # - Generated executable's Crystal::LIBRARY_RPATH: `C:\bar;$ORIGIN\mylibs;C:\foo\dll;C:\foo`
    #
    # Combining RPATHs multiple times has no effect; the `CRYSTAL_LIBRARY_RPATH`
    # environment variable at compiler startup is used, not really the "current"
    # one. This can happen when running a program that also uses macro `run`s.
    def self.add_compiler_rpath(&)
      executable_path = Process.executable_path
      compiler_origin = File.dirname(executable_path) if executable_path

      current_rpaths = ORIGINAL_CRYSTAL_LIBRARY_RPATH.try &.split(Process::PATH_DELIMITER, remove_empty: true)
      compiler_rpaths = Crystal::LIBRARY_RPATH.split(Process::PATH_DELIMITER, remove_empty: true)
      CrystalPath.expand_paths(compiler_rpaths, compiler_origin)

      rpaths = compiler_rpaths
      rpaths.concat(current_rpaths) if current_rpaths
      {% if flag?(:win32) %}
        rpaths << compiler_origin if compiler_origin
      {% end %}

      old_env = ENV["CRYSTAL_LIBRARY_RPATH"]?
      ENV["CRYSTAL_LIBRARY_RPATH"] = rpaths.join(Process::PATH_DELIMITER)
      begin
        yield
      ensure
        ENV["CRYSTAL_LIBRARY_RPATH"] = old_env
      end
    end

    private ORIGINAL_CRYSTAL_LIBRARY_RPATH = ENV["CRYSTAL_LIBRARY_RPATH"]?

    class_getter paths : Array(String) do
      default_paths
    end
  end

  class Program
    def lib_flags
      has_flag?("windows") ? lib_flags_windows : lib_flags_posix
    end

    private def lib_flags_windows
      flags = [] of String

      # Add CRYSTAL_LIBRARY_PATH locations, so the linker preferentially
      # searches user-given library paths.
      if has_flag?("msvc")
        CrystalLibraryPath.paths.each do |path|
          flags << Process.quote_windows("/LIBPATH:#{path}")
        end
      end

      link_annotations.reverse_each do |ann|
        if ldflags = ann.ldflags
          flags << ldflags
        end

        if libname = ann.lib
          flags << Process.quote_windows("#{libname}.lib")
        end
      end

      flags.join(" ")
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

    # Searches among CRYSTAL_LIBRARY_PATH, the compiler's directory, and PATH
    # for every DLL specified in the used `@[Link]` annotations. Yields the
    # absolute path and `true` if found, the base name and `false` if not found.
    # The directories should match `Crystal::Repl::Context#dll_search_paths`
    def each_dll_path(& : String, Bool ->)
      executable_path = nil
      compiler_origin = nil
      paths = nil

      link_annotations.each do |ann|
        next unless dll = ann.dll

        dll_path = CrystalLibraryPath.paths.each do |path|
          full_path = File.join(path, dll)
          break full_path if File.file?(full_path)
        end

        unless dll_path
          executable_path ||= Process.executable_path
          compiler_origin ||= File.dirname(executable_path) if executable_path

          if compiler_origin
            full_path = File.join(compiler_origin, dll)
            dll_path = full_path if File.file?(full_path)
          end
        end

        unless dll_path
          paths ||= ENV["PATH"]?.try &.split(Process::PATH_DELIMITER, remove_empty: true)

          dll_path = paths.try &.each do |path|
            full_path = File.join(path, dll)
            break full_path if File.file?(full_path)
          end
        end

        yield dll_path || dll, !dll_path.nil?
      end
    end

    # Detects the current MSVC linker and the relevant linker flags that
    # recreate the MSVC developer prompt's standard library paths. If both MSVC
    # and the Windows SDK are available, the linker will be an absolute path and
    # the linker flags will contain the `/LIBPATH`s for the system libraries.
    #
    # Has no effect if the host compiler is not using MSVC.
    def msvc_compiler_and_flags : {String, Array(String)}
      linker = Compiler::MSVC_LINKER
      link_args = [] of String

      {% if flag?(:msvc) %}
        if msvc_path = Crystal::System::VisualStudio.find_latest_msvc_path
          if win_sdk_libpath = Crystal::System::WindowsSDK.find_win10_sdk_libpath
            host_bits = {{ flag?(:aarch64) ? "ARM64" : flag?(:bits64) ? "x64" : "x86" }}
            target_bits = has_flag?("aarch64") ? "arm64" : has_flag?("bits64") ? "x64" : "x86"

            # MSVC build tools and Windows SDK found; recreate `LIB` environment variable
            # that is normally expected on the MSVC developer command prompt
            link_args << "/LIBPATH:#{msvc_path.join("atlmfc", "lib", target_bits)}"
            link_args << "/LIBPATH:#{msvc_path.join("lib", target_bits)}"
            link_args << "/LIBPATH:#{win_sdk_libpath.join("ucrt", target_bits)}"
            link_args << "/LIBPATH:#{win_sdk_libpath.join("um", target_bits)}"

            # use exact path for compiler instead of relying on `PATH`, unless
            # explicitly overridden by `%CC%`
            # (letter case shouldn't matter in most cases but being exact doesn't hurt here)
            unless ENV.has_key?("CC")
              target_bits = target_bits.sub("arm", "ARM")
              linker = msvc_path.join("bin", "Host#{host_bits}", target_bits, "cl.exe").to_s
            end
          end
        end
      {% end %}

      {linker, link_args}
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
