require 'time'
require 'yaml'
require 'json'
require 'active_support'
require 'twitter'
require 'tweetstream'

ARTIST = 'phish'

PROD = false

SONG_LIMIT = 5 * 60
BREAK_LIMIT = SONG_LIMIT * 5
CLUSTER_MIN = 2

CREDENTIALS = YAML::load(File.open(File.join(File.dirname(__FILE__), "../config/credentials.yml")))
Twitter.configure do |config|
  config.consumer_key       = CREDENTIALS['consumer_key']
  config.consumer_secret    = CREDENTIALS['consumer_secret']
  config.oauth_token        = CREDENTIALS['oauth_token']
  config.oauth_token_secret = CREDENTIALS['oauth_token_secret']
end

TweetStream.configure do |config|
  config.consumer_key       = CREDENTIALS['consumer_key']
  config.consumer_secret    = CREDENTIALS['consumer_secret']
  config.oauth_token        = CREDENTIALS['oauth_token']
  config.oauth_token_secret = CREDENTIALS['oauth_token_secret']
  config.auth_method        = :oauth
end

SONGS = YAML::load(File.open(File.join(File.dirname(__FILE__), "../config/#{ARTIST}_songs.yml"))).map do |song|
  song.to_s
end

def normalize(str)
  ActiveSupport::Multibyte::Chars.new(str).normalize(:kd).downcase.to_s
end

NORMALIZED_SONGS = SONGS.map { |w| Regexp.escape(normalize(w)) }
song_to_tweets = Hash[NORMALIZED_SONGS.map {|v| [v,[]]}]
song_regex = /#{NORMALIZED_SONGS.join('|')}/
puts "#{NORMALIZED_SONGS.count} songs loaded"

def output_song(setlist_elem)
  song = SONGS[NORMALIZED_SONGS.index(setlist_elem[0])]
  cluster = setlist_elem[1]

  tweet_urls = cluster.map do |tweet|
    "https://twitter.com/#{tweet['user']['screen_name']}/statuses/#{tweet['id']}"
  end

  output = "#{song}: #{cluster.size} tweets / #{tweet_urls[0..3].join(' ')}"
  if PROD
    Twitter.update(output)
  else
    puts output
  end
end

tweets = IO.readlines(File.join(File.dirname(__FILE__), "../config/#{ARTIST}_tweets.json")).map do |line|
  JSON.parse(line)
end
puts "#{tweets.count} tweets loaded"

# tweets = []
# TweetStream::Client.new.track('twitter') do |tweet|
#   nest if tweet.text =~ /RT|set/ # skip RT's and setlist tweets
#   tweets << tweet.to_hash
# end


# require 'thread'

# queue = Queue.new

# producer = Thread.new do
#  5.times do |i|
#    sleep rand(i) # simulate expense
#    queue << i
#    puts "#{i} produced"
#  end
# end

# consumer = Thread.new do
#  5.times do |i|
#    value = queue.pop
#    sleep rand(i/2) # simulate expense
#    puts "consumed #{value}"
#  end
# end

setlist = []
last_song = ''



tweets.each do |tweet|
  tweet_text = normalize(tweet['text'])
  if (song_regex === tweet_text)
    # song matched via regex, find it
    NORMALIZED_SONGS.each do |song|
      if tweet_text =~ /#{song}/
        song_to_tweets[song] << tweet

        end_time = Time.parse(song_to_tweets[song].last['created_at']).to_i
        start_time = end_time - SONG_LIMIT

        # check for song cluster
        cluster = song_to_tweets[song].select do |tweet|
          t = Time.parse(tweet['created_at']).to_i
          t > start_time && t < end_time
        end

        if (cluster.size > CLUSTER_MIN) && (cluster.size > song_to_tweets[song].count / 2)
          if (last_song == song)
            # more tweets for the current song
            setlist[-1] = [song, cluster]
          else
            # new song starting
            setlist << [song, cluster]

            if (last_song != '')
              output_song(setlist[-2])

              # last_cluster = setlist[-2][1]
              # tweet_ids = last_cluster.map { |tweet| tweet['id'] }

              # output = "#{last_song}: #{last_cluster.size} tweets / #{tweet_ids}"
              # puts output
            end

            last_song = song
          end
        end
      end
    end
  else
    # check to see if there's been no new tweet matches for a while
    if setlist.last && last_song != ''
      cluster = setlist.last[1]

      last_tweet_time = Time.parse(tweet['created_at']).to_i
      last_cluster_time = Time.parse(cluster.last['created_at']).to_i

      if ((last_tweet_time - last_cluster_time) > BREAK_LIMIT)
        # no new relevant tweets, call last song complete
        output_song(setlist[-1])

        # tweet_ids = cluster.map { |tweet| tweet['id'] }
        # output = "#{last_song}: #{cluster.size} tweets / #{tweet_ids}"
        # puts output

        last_song = ''
      end
    end
  end
end

# song_to_tweets.to_a.sort_by { |s| s[1].count }.each do |s|
#   puts "#{s[0]}: #{s[1].count}" if s[1].count > 0
# end

# setlist.each do |s|
#   tweet_ids = s[1].map { |tweet| tweet['id'] }

#   output = "#{s[0]}: #{s[1].size} tweets / #{tweet_ids}"
#   puts output
# end

# puts setlist.inspect
# puts setlist.uniq.inspect

# loop do
#   puts "#{songs.count} songs loaded"
#   puts "#{tweets.count} tweets loaded"
#   sleep(1)
# end
