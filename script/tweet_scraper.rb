require 'rubygems'
require 'yaml'
require 'active_support'
require 'twitter'

ARTIST = 'phish'

CREDENTIALS = YAML::load(File.open(File.join(File.dirname(__FILE__), "../config/credentials.yml")))

Twitter.configure do |config|
  config.consumer_key = CREDENTIALS['consumer_key']
  config.consumer_secret = CREDENTIALS['consumer_secret']
  config.oauth_token = CREDENTIALS['oauth_token']
  config.oauth_token_secret = CREDENTIALS['oauth_token_secret']
end

END_TIME = Time.new(2013, 8, 3, 0, 30, 0, "-07:00")
START_TIME = Time.new(2013, 8, 2, 7, 00, 0, "-07:00")

max_id = 0
tweets = []

loop do
  results = Twitter.search("#{ARTIST} -set -RT", :count => 100, :max_id => max_id).results

  tweets += results.select do |r|
    r.created_at < END_TIME
  end

  max_id = results.last.id
  break if results.last.created_at < START_TIME

  puts "retrieved #{tweets.count} tweets / #{Time.at(results.last.created_at)} / #{START_TIME}"
end

File.open(File.join(File.dirname(__FILE__), "../config/#{ARTIST}_tweets.json"), 'w+') do |f|
  tweets.reverse.each do |t|
    f.puts(t.to_hash.to_json)
  end
end
