setlistr
===========

test and mock data
------------------
scrape songs:

  http://phish.net/song/
  $("tbody tr td:first-child a").each ( function (s, l) { console.log(l.text) })

scrape tweets:

  ruby script/tweet_scraper.rb

run
---
Run:

  ruby script/setlist.rb

TODO
----

  twitter streaming
  gruvr.com integration for concert calendar
  gracenote integration for song lists
  live updating site
