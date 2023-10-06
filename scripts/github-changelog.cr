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

def query_prs(api_token, repository, milestone)
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
  unless response.success?
    abort "GitHub API response: #{response.status}\n#{response.body}"
  end

  response
end

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
  merged_at : Time?,
  permalink : String,
  author : String?,
  labels : Array(String) do
  include JSON::Serializable
  include Comparable(self)

  @[JSON::Field(key: "mergedAt")]
  @merged_at : Time?

  @[JSON::Field(root: "login")]
  @author : String?

  @[JSON::Field(root: "nodes", converter: JSON::ArrayConverter(LabelNameConverter))]
  @labels : Array(String)

  def to_s(io : IO)
    if topic = self.sub_topic
      io << "*(" << sub_topic << ")* "
    end
    if labels.includes?("security")
      io << "**[security]** "
    end
    if labels.includes?("breaking-change")
      io << "**[breaking]** "
    end
    if deprecated?
      io << "**[deprecation]** "
    end
    io << title.sub(/^\[?(?:#{type}|#{sub_topic})(?::|\]:?) /i, "") << " ("
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
    {
      type || "",
      topic || [] of String,
      deprecated? ? 0 : 1,
      merged_at || Time.unix(0),
    }
  end

  def infra_sort_tuple
    {
      topic || [] of String,
      type || "",
      deprecated? ? 0 : 1,
      merged_at || Time.unix(0),
    }
  end

  def primary_topic
    topic.try(&.[0]?) || "other"
  end

  def sub_topic
    topic.try(&.[1..].join(":").presence)
  end

  def topic
    labels.find { |label|
      label.starts_with?("topic:") && label != "topic:multithreading"
    }.try(&.lchop("topic:").split(/:|\//))
  end

  def deprecated?
    labels.includes?("deprecation")
  end

  def breaking?
    labels.includes?("kind:breaking")
  end

  def feature?
    labels.includes?("kind:feature")
  end

  def fix?
    labels.includes?("kind:bug")
  end

  def refactor?
    labels.includes?("kind:refactor")
  end

  def docs?
    labels.includes?("kind:docs")
  end

  def specs?
    labels.includes?("kind:specs")
  end

  def performance?
    labels.includes?("performance")
  end

  def infra?
    labels.any?(&.starts_with?("topic:infrastructure"))
  end

  def type
    case
    when feature?     then "feature"
    when fix?         then "fix"
    when docs?        then "docs"
    when specs?       then "specs"
    when performance? then "performance"
    when refactor?    then "refactor"
    else                   nil
    end
  end

  def section
    case
    when breaking? then "breaking"
    when infra?    then "infra"
    else                type || ""
    end
  end
end

response = query_prs(api_token, repository, milestone)
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
array.select! { |pr| pr.merged_at && !changelog.index(pr.permalink) }

sections = array.group_by(&.section)

SECTION_TITLES = {
  "breaking"    => "Breaking changes",
  "feature"     => "Features",
  "fix"         => "Bugfixes",
  "performance" => "Performance",
  "refactor"    => "Refactor",
  "docs"        => "Documentation",
  "specs"       => "Specs",
  "infra"       => "Infrastructure",
  ""            => "Chores",
}

TOPIC_ORDER = %w[lang stdlib compiler tools other]

SECTION_TITLES.each do |id, title|
  prs = sections[id]? || next
  puts "### #{title}"
  puts

  topics = prs.group_by(&.primary_topic)

  topic_titles = topics.keys.sort_by! { |k| TOPIC_ORDER.index(k) || Int32::MAX }

  topic_titles.each do |topic_title|
    topic_prs = topics[topic_title]? || next

    if id == "infra"
      topic_prs.sort_by!(&.infra_sort_tuple)
    else
      topic_prs.sort!
      puts "#### #{topic_title}"
      puts
    end

    topic_prs.each do |pr|
      puts "- #{pr}"
    end
    puts
  end
end
