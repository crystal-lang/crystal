---
title: Heroku Buildpack
thumbnail: H
author: bcardiff
---

At the end of 2014 a [first draft](https://github.com/manastech/heroku-buildpack-crystal/commit/b364f9115706a2a1c97ff40bd44aef1cf73e6288) of a [Heroku](//heroku.com) buildpack for crystal was createad. This was truly great. Being able to run crystal apps in the Heroku stack was charm idea.

While we continued to develop the language, the tools, and the standard library, the community around Crystal grew. Many were interested in trying their Crystal-powered web apps in Heroku. The [network graph](https://github.com/crystal-lang/heroku-buildpack-crystal/network) at github for the buildpack is quite big, especially for just a bunch of bash scripts!

However, due to some flaws in the approach, the buildpack failed to stay up to date with the latest versions of Crystal; but that is now solved!  Yay!

While efforts to develop web frameworks continue nowadays, we wanted to share the very basic steps to use the Crystal buildpack to deploy a web application in Heroku without the need for any additional dependencies.

# Create a Crystal project

This assumes you already have [crystal installed](http://crystal-lang.org/docs/installation/).

Use `crystal init app` to create the app.

<pre class="code">
$ crystal init app heroku101
    create  heroku101/.gitignore
    create  heroku101/LICENSE
    create  heroku101/README.md
    create  heroku101/.travis.yml
    create  heroku101/shard.yml
    create  heroku101/src/heroku101.cr
    create  heroku101/src/heroku101/version.cr
    create  heroku101/spec/spec_helper.cr
    create  heroku101/spec/heroku101_spec.cr
Initialized empty Git repository in /Users/bcardiff/Work/Manas/crystal/heroku101/.git/

$ cd heroku101/
</pre>

**Note:** During the rest of the post all the commands are executed from the `heroku101/` directory.

The `shard.yml` file declares the name of the project as `heroku101`. This will be used by the buildpack to determine the main source file to compile: `./src/heroku101.cr`.

<pre class="code">
$ cat shard.yml
name: heroku101
version: 0.1.0
...
</pre>

To create a simple http server edit the `src/heroku101.cr` file and add the following content:

{% highlight ruby %}
# file: src/heroku101.cr
require "http/server"

bind = "0.0.0.0"
port = 8080

server = HTTP::Server.new(bind, port) do |context|
  context.response.content_type = "text/plain"
  context.response << "Hello world, got #{context.request.path}"
end

puts "Listening on http://#{bind}:#{port}"
server.listen
{% endhighlight ruby %}

To build and run the program:

<pre class="code">
$ crystal src/heroku101.cr
Listening on http://0.0.0.0:8080
</pre>

Open your browser at [http://0.0.0.0:8080](http://0.0.0.0:8080).

To stop the server just terminate the process by pressing `Ctrl+C`.

# Herokufy it

Right now the project knows nothing about Heroku. To get started, a Heroku application needs first to be registered. The easiest way to do this is via the [Heroku toolbelt](https://toolbelt.heroku.com/):

<pre class="code">
$ heroku create --buildpack https://github.com/crystal-lang/heroku-buildpack-crystal.git
Creating app... done, ⬢ sleepy-thicket-16179
Setting buildpack to https://github.com/crystal-lang/heroku-buildpack-crystal.git... done
https://sleepy-thicket-16179.herokuapp.com/ | https://git.heroku.com/sleepy-thicket-16179.git
</pre>

The above command will generate a random app name. Check the [docs](https://devcenter.heroku.com/articles/creating-apps) to give your app a name from the beginning.

Before deploying, we need to make a small change. Heroku randomly assigns a port number to be used by the app. Thanks to be buildpack, this will be informed in a `--port` option when running the application.

So, add a `require "option_parser"` at the beginning of `src/heroku101.cr` and override the `port` variable default with:

{% highlight ruby %}
OptionParser.parse! do |opts|
  opts.on("-p PORT", "--port PORT", "define port to run server") do |opt|
    port = opt.to_i
  end
end
{% endhighlight ruby %}

The full `src/heroku101.cr` should be:

{% highlight ruby %}
# file: src/heroku101.cr
require "http/server"
require "option_parser"

bind = "0.0.0.0"
port = 8080

OptionParser.parse! do |opts|
  opts.on("-p PORT", "--port PORT", "define port to run server") do |opt|
    port = opt.to_i
  end
end

server = HTTP::Server.new(bind, port) do |context|
  context.response.content_type = "text/plain"
  context.response << "Hello world, got #{context.request.path}"
end

puts "Listening on http://#{bind}:#{port}"
server.listen
{% endhighlight ruby %}

To build and run with `--port` option:

<pre class="code">
$ crystal src/heroku101.cr -- --port 9090
Listening on http://0.0.0.0:9090
</pre>

Or build an optimised release locally and execute it via:

<pre class="code">
$ crystal build src/heroku101.cr --release
$ ./heroku101
Listening on http://0.0.0.0:8080
^C
$ ./heroku101 --port 9090
Listening on http://0.0.0.0:9090
^C
</pre>

# Deploy!

When you are ready to go live with your app just deploy it the usual way with `git push heroku master`.

<pre class="code">
$ git push heroku master
Counting objects: 22, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (17/17), done.
Writing objects: 100% (22/22), 2.85 KiB | 0 bytes/s, done.
Total 22 (delta 3), reused 0 (delta 0)
remote: Compressing source files... done.
remote: Building source:
remote:
remote: -----> Fetching set buildpack https://github.com/crystal-lang/heroku-buildpack-crystal.git... done
remote: -----> Crystal app detected
remote: -----> Installing Crystal (0.17.3 due to latest release at https://github.com/crystal-lang/crystal)
remote: -----> Installing Dependencies
remote: -----> Compiling src/heroku101.cr (auto-detected from shard.yml)
remote:
remote: -----> Discovering process types
remote:        Procfile declares types     -> (none)
remote:        Default types for buildpack -> web
remote:
remote: -----> Compressing...
remote:        Done: 289.4K
remote: -----> Launching...
remote:        Released v3
remote:        https://sleepy-thicket-16179.herokuapp.com/ deployed to Heroku
remote:
remote: Verifying deploy.... done.
To https://git.heroku.com/sleepy-thicket-16179.git
 * [new branch]      master -> master
</pre>

The buildpack will:

1. Install the latest crystal release.
2. Install project dependencies via shards.
3. Compile the main source file in release mode.
4. Run the web server process with `--port` option.

# Specify the crystal version

If you want to use a different Crystal version, create a `.crystal-version` file with the desired version, following [crenv](https://github.com/pine/crenv)’s convention.

<pre class="code">
$ echo '0.17.1' > .crystal-version
</pre>

Commit the changes in `.crystal-version` and deploy.

<pre class="code">
$ git push heroku master
Counting objects: 3, done.
Delta compression using up to 8 threads.
Compressing objects: 100% (2/2), done.
Writing objects: 100% (3/3), 301 bytes | 0 bytes/s, done.
Total 3 (delta 1), reused 0 (delta 0)
remote: Compressing source files... done.
remote: Building source:
remote:
remote: -----> Fetching set buildpack https://github.com/crystal-lang/heroku-buildpack-crystal.git... done
remote: -----> Crystal app detected
remote: -----> Installing Crystal (0.17.1 due to .crystal-version file)
remote: -----> Installing Dependencies
remote: -----> Compiling src/heroku101.cr (auto-detected from shard.yml)
...
</pre>

You will now notice the `(0.17.1 due to .crystal-version file)` legend.

Whenever you are ready to upgrade to the latest crystal version, update the content of the file or just remove it and deploy again.

## Show me the code!

Find all the sample source code used at
[https://github.com/bcardiff/sample-crystal-heroku101](https://github.com/bcardiff/sample-crystal-heroku101).

To contribute to crystal buildpack, just [fork it](https://github.com/crystal-lang/heroku-buildpack-crystal). Contributions are welcome!


