require "bundler"
Bundler.require(:defaults, :development)

RSpec.configure do |config|
  config.before(:each) do
    Redis.new(db: "redis_cave_keeper_dev").flushdb
  end
end
