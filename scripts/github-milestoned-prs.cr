# This is a simple tool to query the GitHub API for pull requests associated with
# a given milestone and format those that are not mentioned in CHANGELOG.md.
#
# Usage:
#   crystal run scripts/github-milestoned-prs.cr -- 1.0.0
#
# Environment variables:
#   GITHUB_TOKEN: Access token for the GitHub API (required)
require "http/client"
require "json"

api_token = ENV["GITHUB_TOKEN"]

request = {
  query: <<-GRAPHQL,
    query($milestone: String) {
      repository(owner: "crystal-lang", name: "crystal") {
        milestones(query: $milestone, first: 1) {
          nodes {
            pullRequests(first: 200) {
              nodes {
                number
                title
                mergedAt
                permalink
                author {
                  login
                }
                labels(first: 20) {
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
  variables: {
    milestone: ARGV.first,
  }
}

response = HTTP::Client.post("https://api.github.com/graphql", body: request.to_json, headers: HTTP::Headers{"Authorization" => "bearer #{api_token}"})

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
    x = (other.labels.includes?("security") ? 1 : 0) <=> (labels.includes?("security") ? 1 : 0)
    return x unless x.zero?
    x = (other.labels.includes?("breaking-change") ? 1 : 0) <=> (labels.includes?("breaking-change") ? 1 : 0)
    return x unless x.zero?

    if (mergedAt = self.mergedAt) && (otherMergedAt = other.mergedAt)
      mergedAt <=> otherMergedAt
    end

    0
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
  case pr.labels
  when .any? &.starts_with?("topic:lang")
    "Language"
  when .any? &.starts_with?("topic:compiler")
    "Compiler"
  when .any? &.starts_with?("topic:tools")
    "Tools"
  when .any? &.starts_with?("topic:stdlib")
    "Standard Library"
  else
    "Other"
  end
}

sections.each do |name, prs|
  puts "## #{name}"
  puts
  prs.sort!
  prs.each do |pr|
    puts "- #{pr}"
  end
  puts
end
