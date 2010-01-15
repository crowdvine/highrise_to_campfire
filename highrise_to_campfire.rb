require 'rubygems'
require 'ruby-debug'
require 'tinder'
require 'sequel'
require 'rfeedparser'
require 'open-uri'

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
           "https://#{config['highrise']['subdomain']}.highrisehq.com/recordings.atom",
           :http_basic_authentication => [config['highrise']['token'], 'x']))
  end
  
  def self.campfire_room
    bot = Tinder::Campfire.new(config['campfire']['subdomain'])

    bot.login(config['campfire']['login'],config['campfire']['password'])
    room = bot.find_room_by_name(config['campfire']['room_name'])
    room
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
    bot = campfire_room
    
    bot.speak "#{entry.author_detail.name} did something: #{entry.title}"
    bot.speak "Read more about it here: #{entry.link}"
  end

  def self.run
    return if highrise_feed.entries.empty?
    highrise_feed.entries.to_a.each do |entry|
      if Time.parse(entry.updated) > last_updated_at
        notify(entry) if NOTIFY_ON_NEW_ITEMS
      end
    end
    is_now_updated(highrise_feed.entries.sort{|b,a| a.updated <=> b.updated}.first.updated.to_s)
  end
end

HighriseToCampfire.run()
