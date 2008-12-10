require 'rubygems'
require 'sequel'
require 'rfeedparser'
require 'open-uri'
require File.dirname(__FILE__) + '/lib/marshmallow'

module HighriseToCampfire
  NOTIFY_ON_NEW_ITEMS = true
  CONFIG_FILE = File.dirname(__FILE__) + '/config.yml'
  LAST_UPDATED_AT_FILE = File.dirname(__FILE__) + '/last_updated_at'

  def self.config
    @@config ||= YAML.load(File.read(CONFIG_FILE))
  end

  def self.highrise_feed 
    @@feed ||= FeedParser.parse(
         open(
           "http://#{config['highrise']['subdomain']}.highrisehq.com/recordings.atom",
           :http_basic_authentication => [config['highrise']['token'], 'x']))
  end
  
  def self.campfire_bot
    bot = Marshmallow.new(
              :domain => config['campfire']['subdomain'], 
              :ssl => false)

    bot.login(:method => :login,
              :username => config['campfire']['login'],
              :password => config['campfire']['password'],
              :room => config['campfire']['room_id']
           )
    bot
  end

  def self.last_updated_at
    @@last_updated_at ||= begin
      str = File.read(LAST_UPDATED_AT_FILE) rescue nil
      (str.blank? ? nil : Time.parse(str))
    end
  end

  def self.is_now_updated(time)
    @@last_updated_at = time
    File.open(LAST_UPDATED_AT_FILE, 'w+') do |file|
      file.write(@@last_updated_at.to_s)
    end
    true
  rescue
    false
  end
  
  def self.notify(entry)
    bot = campfire_bot
    
    bot.say "#{entry.author_detail.name} did something: #{entry.title}"
    bot.say "Read more about it here: #{entry.link}"
  end

  def self.run
    return if highrise_feed.entries.empty?

    highrise_feed.entries.each do |entry|
      if Time.parse(entry.updated) > last_updated_at
        notify(entry) if NOTIFY_ON_NEW_ITEMS
      end
    end
    is_now_updated(Time.parse(highrise_feed.entries.first))
  end
end

HighriseToCampfire.run()
