setlistr
===========

Autogenerate concert setlists via the Twitter streaming API.

Run
---
    # put relevant credentials in config/credentials.yml
    ruby script/setlist.rb
    
Live demo
---------

  https://twitter.com/thesetlistr

Test and mock data
------------------
scrape tweets:

    ruby script/tweet_scraper.rb

scrape songs:

    http://phish.net/song/
    $("tbody tr td:first-child a").each ( function (s, l) { console.log(l.text) })

TODO
----

* gruvr.com integration for concert calendar
* gracenote integration for song lists
* live updating site
