require "bundler"
Bundler.require(:development)

require "redis_cave_keeper"

RSpec.configure do |config|
  config.before(:each) do
    Redis.new(db: "redis_cave_keeper_dev").flushdb
  end
end
