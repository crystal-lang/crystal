class Crystal::Doc::Generator
  getter program : Program

  @base_dir : String
  @is_crystal_repo : Bool
  @repository : String? = nil
  getter repository_name = ""

  # Adding a flag and associated css class will add support in parser
  FLAG_COLORS = {
    "BUG"        => "red",
    "DEPRECATED" => "red",
    "FIXME"      => "yellow",
    "NOTE"       => "purple",
    "OPTIMIZE"   => "green",
    "TODO"       => "orange",
  }
  FLAGS = FLAG_COLORS.keys

  GIT_REMOTE_PATTERNS = {
    /github\.com(?:\:|\/)(?<user>(?:\w|-|_)+)\/(?<repo>(?:\w|-|_|\.)+?)(?:\.git)?\s/ => {
      repository: "https://github.com/%{user}/%{repo}/blob/%{rev}",
      repo_name:  "github.com/%{user}/%{repo}",
    },
    /gitlab\.com(?:\:|\/)(?<user>(?:\w|-|_|\.)+)\/(?<repo>(?:\w|-|_|\.)+?)(?:\.git)?\s/ => {
      repository: "https://gitlab.com/%{user}/%{repo}/blob/%{rev}",
      repo_name:  "gitlab.com/%{user}/%{repo}",
    },
  }

  def initialize(@program : Program, @included_dirs : Array(String), @dir = "./doc")
    @base_dir = `pwd`.chomp
    @types = {} of Crystal::Type => Doc::Type
    @repo_name = ""
    @is_crystal_repo = false
    compute_repository
  end

  def run
    Dir.mkdir_p @dir

    types = collect_subtypes(@program)

    program_type = type(@program)
    if program_type.class_methods.any? { |method| must_include? method }
      types.insert 0, program_type
    end

    generate_docs program_type, types
  end

  def program_type
    type(@program)
  end

  def generate_docs(program_type, types)
    copy_files
    generate_types_docs types, @dir, types
    generate_readme program_type, types
  end

  def generate_readme(program_type, types)
    if File.file?("README.md")
      filename = "README.md"
    elsif File.file?("Readme.md")
      filename = "Readme.md"
    end

    if filename
      body = doc(program_type, File.read(filename))
    else
      body = ""
    end

    File.write "#{@dir}/index.html", MainTemplate.new(body, types, repository_name)
  end

  def copy_files
    Dir.mkdir_p "#{@dir}/css"
    Dir.mkdir_p "#{@dir}/js"

    File.write "#{@dir}/css/style.css", StyleTemplate.new
    File.write "#{@dir}/js/doc.js", JsTypeTemplate.new
  end

  def generate_types_docs(types, dir, all_types)
    types.each do |type|
      if type.program?
        filename = "#{dir}/toplevel.html"
      else
        filename = "#{dir}/#{type.name}.html"
      end

      File.write filename, TypeTemplate.new(type, all_types)

      next if type.program?

      subtypes = type.types
      if subtypes && !subtypes.empty?
        dirname = "#{dir}/#{type.name}"
        Dir.mkdir_p dirname
        generate_types_docs subtypes, dirname, all_types
      end
    end
  end

  def must_include?(type : Doc::Type)
    must_include? type.type
  end

  def must_include?(type : Crystal::Type)
    return false if type.private?
    return false if nodoc?(type)
    return true if crystal_builtin?(type)

    type.locations.try &.any? do |type_location|
      must_include? type_location
    end
  end

  def must_include?(method : Method)
    must_include? method.def
  end

  def must_include?(a_def : Crystal::Def)
    return false if nodoc?(a_def)

    must_include? a_def.location
  end

  def must_include?(a_macro : Macro)
    must_include? a_macro.macro
  end

  def must_include?(a_macro : Crystal::Macro)
    return false if nodoc?(a_macro)

    must_include? a_macro.location
  end

  def must_include?(location : Crystal::Location)
    case filename = location.filename
    when String
      @included_dirs.any? { |included_dir| filename.starts_with? included_dir }
    when VirtualFile
      must_include? filename.expanded_location
    else
      false
    end
  end

  def must_include?(nil : Nil)
    false
  end

  def nodoc?(str : String?)
    str == ":nodoc:" || str == "nodoc"
  end

  def nodoc?(obj)
    nodoc? obj.doc.try &.strip
  end

  def crystal_builtin?(type)
    return false unless @is_crystal_repo
    return false unless type.is_a?(Const) || type.is_a?(NonGenericModuleType)

    crystal_type = @program.types["Crystal"]
    return true if type == crystal_type

    return false unless type.is_a?(Const)
    return false unless type.namespace == crystal_type

    {"BUILD_COMMIT", "BUILD_DATE", "CACHE_DIR", "DEFAULT_PATH",
     "DESCRIPTION", "PATH", "VERSION", "LLVM_VERSION"}.each do |name|
      return true if type == crystal_type.types[name]?
    end

    false
  end

  def type(type)
    @types[type] ||= Type.new(self, type)
  end

  def method(type, method, class_method)
    Method.new(self, type, method, class_method)
  end

  def macro(type, a_macro)
    Macro.new(self, type, a_macro)
  end

  def collect_subtypes(parent)
    types = [] of Type

    parent.types?.try &.each_value do |type|
      case type
      when Const, LibType
        next
      end

      types << type(type) if must_include? type
    end

    types.sort_by! &.name.downcase
  end

  def collect_constants(parent)
    types = [] of Constant

    parent.type.types?.try &.each_value do |type|
      if type.is_a?(Const) && must_include? type
        types << Constant.new(self, parent, type)
      end
    end

    types.sort_by! &.name.downcase unless parent.type.is_a?(EnumType)
    types
  end

  def summary(obj : Type | Method | Macro | Constant)
    doc = obj.doc
    return nil unless doc

    summary obj, doc
  end

  def summary(context, string)
    line = fetch_doc_lines(string).lines.first?
    return nil unless line

    dot_index = line =~ /\.($|\s)/
    if dot_index
      line = line[0..dot_index]
    end

    doc context, line
  end

  def doc(obj : Type | Method | Macro | Constant)
    doc = obj.doc
    return nil unless doc

    doc obj, doc
  end

  def doc(context, string)
    string = isolate_flag_lines string
    markdown = String.build do |io|
      Markdown.parse string, MarkdownDocRenderer.new(context, io)
    end
    generate_flags markdown
  end

  def fetch_doc_lines(doc)
    doc.gsub /\n+/ do |match|
      if match.size == 1
        " "
      else
        "\n"
      end
    end
  end

  # Replaces flag keywords with html equivalent
  #
  # Assumes that flag keywords are at the beginning of respective `p` element
  def generate_flags(string)
    FLAGS.reduce(string) do |str, flag|
      flag_regexp = /<p>\s*#{flag}:?/
      element_sub = %(<p><span class="flag #{FLAG_COLORS[flag]}">#{flag}</span> )
      str.gsub(flag_regexp, element_sub)
    end
  end

  # Adds extra line break to flag keyword lines
  #
  # Guarantees that line is within its own paragraph element when parsed
  def isolate_flag_lines(string)
    flag_regexp = /^ ?(#{FLAGS.join('|')}):?/
    String.build do |io|
      string.each_line(chomp: false).join("", io) do |line, io|
        if line =~ flag_regexp
          io << '\n' << line
        else
          io << line
        end
      end
    end
  end

  def compute_repository
    remotes = `git remote -v`
    return unless $?.success?

    git_matches = remotes.each_line.compact_map do |line|
      GIT_REMOTE_PATTERNS.each_key.compact_map(&.match(line)).first?
    end.to_a

    @is_crystal_repo = git_matches.any? { |gr| gr.string =~ %r{github\.com[/:]crystal-lang/crystal(?:\.git)?\s} }

    origin = git_matches.find(&.string.starts_with?("origin")) || git_matches.first?
    return unless origin

    user = origin["user"]
    repo = origin["repo"]
    rev = `git rev-parse HEAD`.chomp

    info = GIT_REMOTE_PATTERNS[origin.regex]
    @repository = info[:repository] % {user: user, repo: repo, rev: rev}
    @repository_name = info[:repo_name] % {user: user, repo: repo}
  end

  def source_link(node)
    location = relative_location node
    return unless location

    filename = relative_filename location
    return unless filename

    "#{@repository}#{filename}#L#{location.line_number}"
  end

  def relative_location(node : ASTNode)
    relative_location node.location
  end

  def relative_location(location : Location?)
    return unless location

    repository = @repository
    return unless repository

    filename = location.filename
    if filename.is_a?(VirtualFile)
      location = filename.expanded_location
    end

    location
  end

  def relative_filename(location)
    filename = location.filename
    return unless filename.is_a?(String)
    return unless filename.starts_with? @base_dir
    filename[@base_dir.size..-1]
  end

  record RelativeLocation, filename : String, line_number : Int32, url : String?
  SRC_SEP = "src#{File::SEPARATOR}"

  def relative_locations(type)
    repository = @repository
    locations = [] of RelativeLocation
    type.locations.try &.each do |location|
      location = relative_location location
      next unless location

      filename = relative_filename location
      next unless filename

      url = "#{repository}#{filename}" if repository

      filename = filename[1..-1] if filename.starts_with? File::SEPARATOR
      filename = filename[4..-1] if filename.starts_with? SRC_SEP

      locations << RelativeLocation.new(filename, location.line_number, url)
    end
    locations
  end
end
