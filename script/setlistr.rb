require 'time'
require 'yaml'
require 'json'
require 'thread'
require 'active_support'
require 'twitter'
require 'tweetstream'

PROD = false
ARTIST = 'phish'

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
song_regex = /(#{NORMALIZED_SONGS.join('|')})/
puts "#{NORMALIZED_SONGS.count} songs loaded"

def output_song(setlist_elem)
  song = SONGS[NORMALIZED_SONGS.index(setlist_elem[0])]
  cluster = setlist_elem[1]

  tweet_urls = cluster.map do |tweet|
    "https://twitter.com/#{tweet['user']['screen_name']}/statuses/#{tweet['id']}"
  end

  if PROD
    Twitter.update("#{ARTIST} / #{song}: #{cluster.size} tweets / #{tweet_urls[0..3].join(' ')}")
  else
    puts "#{ARTIST} / #{song}: #{cluster.size} tweets / #{cluster.map { |t| t['id']}}"
  end
end

# read tweets either from twitter streaming api or file
tweets = Queue.new
if PROD
  Thread.new do
    TweetStream::Client.new.track(ARTIST) do |tweet|
      next if tweet.text =~ /RT|set/ # skip RT's and setlist tweets
      next if tweet.user.id == CREDENTIALS['twitter_user_id'] # skip tweets belonging to the user that is tweeting
      puts tweet.to_hash
      tweets << JSON.parse(tweet.to_hash.to_json)
    end
  end
else
  IO.readlines(File.join(File.dirname(__FILE__), "../config/#{ARTIST}_tweets.json")).map do |line|
    tweets << JSON.parse(line)
  end
  puts "#{tweets.size} tweets loaded"
end

setlist = []
last_song = ''

# main consumer loop
loop do
  break if !PROD && tweets.size == 0

  tweet = tweets.pop
  tweet_text = normalize(tweet['text'])
  song = Regexp.escape(tweet_text.match(song_regex).to_s)
  if (song != '')
    # song matched
    puts "#{song}\n#{tweet['text']}" if PROD
    song_to_tweets[song] << tweet

    end_time = Time.parse(song_to_tweets[song].last['created_at']).to_i
    start_time = end_time - SONG_LIMIT

    # check for song cluster
    cluster = song_to_tweets[song].select do |tweet|
      t = Time.parse(tweet['created_at']).to_i
      t >= start_time && t <= end_time
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
        end

        last_song = song
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
        last_song = ''
      end
    end
  end
end
