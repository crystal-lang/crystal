# Rake tasks to parse haml layouts, includes and index files and sass files for jekyll
# Assumes that the haml files are in (_layouts|_includes)/_haml
# and the less files are in css/_less

namespace :haml do
  require 'haml'

  def convert file, destination
    base_name = File.basename(file, '.haml') + '.html'
    convert_full file, File.join(destination, base_name)
  end

  def convert_full from, to
    html = Haml::Engine.new(File.read(from)).render
    File.open(to, 'w') { |f| f.write html }
  end

  desc 'Parse haml layout files'
  task :layouts do
    Dir.glob('_layouts/_haml/*.haml') do |path|
      convert path, '_layouts'
    end

    puts 'Parsed haml layout files'
  end

  desc 'Parse haml include files'
  task :includes do
    Dir.glob('_includes/_haml/*.haml') do |path|
      convert path, '_includes'
    end

    puts 'Parsed haml include files'
  end

  desc 'Parse haml index files'
  task :indexes do
    convert './index.haml', File.dirname('./index.haml')
    convert_full './sponsors.haml', './sponsors/index.html'

    puts 'Parsed haml index files'
  end
end

desc 'Parse less files'
task :less do
  require 'less'

  parser = Less::Parser.new filename: "stylesheet.css", paths: "stylesheets/_sass"
  css = parser.parse(File.read("stylesheets/_sass/stylesheet.less")).to_css
  File.open('stylesheets/stylesheet.css', 'w') { |f| f.write css }

  puts 'Parsed main.sass'
end

def tidy_docs
  Dir.glob('docs/**/*.html') do |path|
    diff = `git diff --numstat #{path}`
    if diff.start_with?("1\t1\t")
      line_change = `git diff -U0 #{path} | tail -n 1`
      if line_change =~ /<div class="book" data-level="[^\"]+" data-basepath="[^\"]+" data-revision="[^\"]+">/
        `git checkout #{path}`
      end
    end
  end
end

desc 'Build docs'
task :docs do
  `which gitbook`
  unless $?.success?
    abort "ERROR: can't find gitbook on your PATH, please install gitbook-cli:\n\n" \
          "gem install bundler # if you don't have bundler already\n" \
          "bundle\n" \
          "npm install -g gitbook-cli"
  end

  system "gitbook build ./_gitbook --gitbook=2.3.2"

  system "rm -rf ./docs"
  system "mv ./_gitbook/_book ./docs"
  tidy_docs
end

desc 'Tidy up generated gitbook files to avoid superfluous changes'
task :'docs:tidy' do
  tidy_docs
end

desc 'Parse all haml items'
task haml: ['haml:layouts', 'haml:includes', 'haml:indexes']

desc 'Build all haml and sass files for deployment'
task build: [:haml, :less, :docs]
