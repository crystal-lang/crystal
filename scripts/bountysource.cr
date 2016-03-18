require "http/client"
require "json"

module BountySource
  class API
    def initialize(@team : String, @token : String)
      @client = HTTP::Client.new("api.bountysource.com", ssl: true)
    end

    def support_levels
      headers = HTTP::Headers{
        "Accept":        "application/vnd.bountysource+json; version=2",
        "Authorization": "token #{@token}",
        "User-Agent":    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36",
        "Referer":       "https://salt.bountysource.com/teams/crystal-lang/admin/supporters",
        "Origin":        "https://salt.bountysource.com",
      }
      response = @client.get("/support_levels?supporters_for_team=#{@team}", headers: headers).body
      Array(SupportLevel).from_json(response)
    end

    def user(slug)
      headers = HTTP::Headers{
        "Accept":     "application/vnd.bountysource+json; version=1",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36",
      }
      response = @client.get("/users/#{slug}?access_token=#{@token}", headers: headers).body
      User.from_json(response)
    end
  end

  class SupportLevel
    JSON.mapping({
      id:     Int64,
      amount: Float64,
      status: String,
      owner:  Owner,
      reward: {type: Reward, nilable: true},
    })

    class Owner
      JSON.mapping({
        display_name: String,
        slug:         {type: String, nilable: true},
      })
    end

    class Reward
      JSON.mapping({
        id:          Int64,
        title:       String,
        description: String,
        amount:      Float64,
      })
    end
  end

  class User
    JSON.mapping({
      id:              Int64,
      slug:            String,
      display_name:    String,
      url:             {type: String, nilable: true},
      github_account:  {type: Account, nilable: true},
      twitter_account: {type: Account, nilable: true},
    })

    class Account
      JSON.mapping({
        display_name: String,
      })
    end
  end
end

module GitHub
  class API
    def initialize
      @client = HTTP::Client.new("api.github.com", ssl: true)
    end

    def user(username)
      response = @client.get("/users/#{username}").body
      User.from_json(response)
    end

    class User
      JSON.mapping({
        name: {type: String, nilable: true},
        blog: {type: String, nilable: true},
      })
    end
  end
end

record Sponsor, name, url

token = ARGV[0]?
unless token
  puts <<-USAGE
  Usage: bountysource <token>

  To find out your <token> check the Network traffic in a browser when hitting
  BountySource and look for an Authorization header or access_token parameter
  in JSON requests.
  USAGE
  exit
end

team = "crystal-lang"
bountysource = BountySource::API.new(team, token)

github = GitHub::API.new

support_levels = bountysource.support_levels
support_levels.select! { |s| s.status == "active" && s.owner.display_name != "Anonymous" }
support_levels.sort_by! &.amount

sponsors = [] of Sponsor

support_levels.each do |support_level|
  name = support_level.owner.display_name
  url = nil
  if slug = support_level.owner.slug
    user = bountysource.user(slug)
    url = user.url
    unless url
      if (github_account = user.github_account)
        github_user = github.user(github_account.display_name)
        name = github_user.name || name
        url = github_user.blog || "https://github.com/#{github_account.display_name}"
      elsif (twitter_account = user.twitter_account)
        url = "http://twitter.com/#{twitter_account.display_name}"
      end
    end
  end

  if url && !(url.starts_with?("http://") || url.starts_with?("https://"))
    url = "http://#{url}"
  end

  amount = support_level.amount

  if !url || amount < 5
    sponsors << Sponsor.new(name, "")
  else
    sponsors << Sponsor.new(name, url.not_nil!)
  end
end

sponsors.sort_by! { |s| {s.name.downcase, s.url} }.uniq!

puts "- sponsors = [nil,"
sponsors.each do |sponsor|
  if sponsor.url.empty?
    puts %(              [#{sponsor.name.inspect}],)
  else
    puts %(              [#{sponsor.name.inspect}, #{sponsor.url.inspect}],)
  end
end
puts "             ].compact.sort { |x, y| cmp = x.length <=> y.length; cmp == 0 ? x.dup.tap { |z| z[0] = z[0].downcase } <=> y.dup.tap { |z| z[0] = z[0].downcase } : -cmp }"
