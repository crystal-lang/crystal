#! /usr/bin/env crystal

# This helper queries merged pull requests for a given milestone from the GitHub API
# and creates formatted changelog entries.
#
# Pull requests that are already referenced in CHANGELOG.md are omitted, which
# makes it easy to incrementally add entries.
#
# Entries are grouped by topic (based on topic labels) and ordered by merge date.
# Some annotations are automatically added based on labels.
#
# Usage:
#
#   scripts/github-changelog.cr <milestone>
#
# Environment variables:
#   GITHUB_TOKEN: Access token for the GitHub API (required)
require "http/client"
require "json"

abort "Missing GITHUB_TOKEN env variable" unless ENV["GITHUB_TOKEN"]?
abort "Missing <milestone> argument" unless ARGV.first?

api_token = ENV["GITHUB_TOKEN"]
repository = "crystal-lang/crystal"
milestone = ARGV.first

query = <<-GRAPHQL
  query($milestone: String, $owner: String!, $repository: String!) {
    repository(owner: $owner, name: $repository) {
      milestones(query: $milestone, first: 1) {
        nodes {
          pullRequests(first: 300) {
            nodes {
              number
              title
              mergedAt
              permalink
              author {
                login
              }
              labels(first: 10) {
                nodes {
                  name
                }
              }
            }
          }
        }
      }
    }
  }
  GRAPHQL

owner, _, name = repository.partition("/")
variables = {
  owner:      owner,
  repository: name,
  milestone:  milestone,
}

response = HTTP::Client.post("https://api.github.com/graphql",
  body: {query: query, variables: variables}.to_json,
  headers: HTTP::Headers{
    "Authorization" => "bearer #{api_token}",
  }
)

module LabelNameConverter
  def self.from_json(pull : JSON::PullParser)
    pull.on_key! "name" do
      String.new(pull)
    end
  end
end

record PullRequest,
  number : Int32,
  title : String,
  mergedAt : Time?,
  permalink : String,
  author : String?,
  labels : Array(String) do
  include JSON::Serializable
  include Comparable(self)

  @[JSON::Field(root: "login")]
  @author : String?

  @[JSON::Field(root: "nodes", converter: JSON::ArrayConverter(LabelNameConverter))]
  @labels : Array(String)

  def to_s(io : IO)
    if labels.includes?("breaking-change")
      io << "**(breaking-change)** "
    end
    if labels.includes?("security")
      io << "**(security)** "
    end
    if labels.includes?("performance")
      io << "**(performance)** "
    end
    io << title << " ("
    io << "[#" << number << "](" << permalink << ")"
    if author = self.author
      io << ", thanks @" << author
    end
    io << ")"
  end

  def <=>(other : self)
    sort_tuple <=> other.sort_tuple
  end

  def sort_tuple
    {labels.includes?("security") ? 0 : 1, labels.includes?("breaking-change") ? 0 : 1, labels.includes?("kind:bug") ? 0 : 1, mergedAt || Time.unix(0)}
  end
end

parser = JSON::PullParser.new(response.body)
array = parser.on_key! "data" do
  parser.on_key! "repository" do
    parser.on_key! "milestones" do
      parser.on_key! "nodes" do
        parser.read_begin_array
        a = parser.on_key! "pullRequests" do
          parser.on_key! "nodes" do
            Array(PullRequest).new(parser)
          end
        end
        parser.read_end_array
        a
      end
    end
  end
end

changelog = File.read("CHANGELOG.md")
array.select! { |pr| pr.mergedAt && !changelog.index(pr.permalink) }
sections = array.group_by { |pr|
  pr.labels.each do |label|
    case label
    when .starts_with?("topic:lang")
      break "Language"
    when .starts_with?("topic:compiler")
      break "Compiler"
    when .starts_with?("topic:tools")
      break "Tools"
    when .starts_with?("topic:stdlib")
      if label == "topic:stdlib"
        break "Standard Library"
      else
        break "Standard Library: #{label.lchop("topic:stdlib:").titleize}"
      end
    else
      next
    end
  end || "Other"
}

titles = sections.keys.sort!
last_title1 = nil

titles.each do |title|
  prs = sections[title]
  title1, _, title2 = title.partition(": ")
  if title2.presence
    if title1 != last_title1
      puts "## #{title1}"
      puts
    end
    puts "### #{title2}"
  else
    puts "## #{title1}"
  end
  last_title1 = title1

  puts
  prs.sort!
  prs.each do |pr|
    puts "- #{pr}"
  end
  puts
end
