require 'time'
require 'yaml'
require 'json'
require 'active_support'

def normalize(str)
  ActiveSupport::Multibyte::Chars.new(str).normalize(:kd).downcase.to_s
end

songs = YAML::load(File.open(File.join(File.dirname(__FILE__), "../config/phish_songs.yml"))).map do |song|
  normalize(song.to_s)
end
puts "#{songs.count} songs loaded"

tweets = []
File.open(File.join(File.dirname(__FILE__), "../config/phish_tweets.json")).each do |line|
  tweets << JSON.parse(line)
end
puts "#{tweets.count} tweets loaded"

escaped_songs = songs.map { |w| Regexp.escape(w) }
song_hash = Hash[escaped_songs.map {|v| [v,[]]}]
song_regex = /#{escaped_songs.join('|')}/

tweets.each do |tweet|
  next if !(song_regex === tweet['text'])

  escaped_songs.each do |song|
    if tweet['text'] =~ /#{song}/
      song_hash[song] << Time.parse(tweet['created_at']).to_i
    end
  end
end

song_hash.to_a.sort_by { |s| s[1].count }.each do |s|
  puts "#{s[0]}: #{s[1].count}" if s[1].count > 0
end


# loop do
#   puts "#{songs.count} songs loaded"
#   puts "#{tweets.count} tweets loaded"
#   sleep(1)
# end
