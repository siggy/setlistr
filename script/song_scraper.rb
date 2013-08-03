require 'rubygems'
require 'yaml'
require 'twitter'

credentials = YAML::load(File.open(File.join(File.dirname(__FILE__), "../config/credentials.yml")))

Twitter.configure do |config|
  config.consumer_key = credentials['consumer_key']
  config.consumer_secret = credentials['consumer_secret']
  config.oauth_token = credentials['oauth_token']
  config.oauth_token_secret = credentials['oauth_token_secret']
end

END_TIME = Time.new(2013, 8, 3, 0, 30, 0, "-07:00")
START_TIME = Time.new(2013, 8, 2, 7, 00, 0, "-07:00")

max_id = 0
tweets = []

loop do
  results = Twitter.search("phish -RT", :count => 100, :max_id => max_id).results

  tweets += results.select do |r|
    r.created_at < END_TIME
  end.map do |r|
    [r.created_at.to_i, r.text]
  end

  max_id = results.last.id
  break if results.last.created_at < START_TIME

  puts "retrieved #{tweets.count} tweets / #{Time.at(results.last.created_at)} / #{START_TIME}"
end

File.open(File.join(File.dirname(__FILE__), "../config/phish_stream.yml"), 'w+') do |f|
  f.write(tweets.sort_by { |t| t[0] }.to_yaml)
end
