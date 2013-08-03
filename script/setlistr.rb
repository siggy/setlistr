require 'yaml'
require 'active_support'

def normalize(str)
  ActiveSupport::Multibyte::Chars.new(str).normalize(:kd).downcase.to_s
end

songs = YAML::load(File.open(File.join(File.dirname(__FILE__), "../config/phish_songs.yml"))).map do |s|
  normalize(s.to_s)
end
puts "#{songs.count} songs loaded"

tweets = YAML::load(File.open(File.join(File.dirname(__FILE__), "../config/phish_stream.yml"))).map do |t|
  [t[0], normalize(t[1])]
end
puts "#{tweets.count} tweets loaded"

escaped_songs = songs.map { |w| Regexp.escape(w) }
song_hash = Hash[escaped_songs.map {|v| [v,0]}]
song_regex = /#{escaped_songs.join('|')}/

tweets.each do |tweet|
  puts tweet
  next if !(song_regex === tweet[1])

  escaped_songs.each do |song|
    if tweet[1] =~ /#{song}/
      puts tweet[1]

      song_hash[song] += 1
    end
  end
end

song_hash.to_a.sort_by { |s| s[1] }.each do |s|
  puts "#{s[0]}: #{s[1]}" if s[1] > 0
end


# loop do
#   puts "#{songs.count} songs loaded"
#   puts "#{tweets.count} tweets loaded"
#   sleep(1)
# end
