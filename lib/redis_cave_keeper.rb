require "redis_cave_keeper/version"

class RedisCaveKeeper
  attr_reader :lock_time

  def initialize(redis, key, opts = {})
    @redis    = redis
    @lock_key = "lock:#{key}"
    @timeout  = opts[:timeout] || 5
  end

  def lock
    unless try_to_acquire_lock
      acquire_lock_if_expired
    end
    has_lock?
  end

  def has_lock?
    @locked  
  end

  protected
  def acquire_lock_if_expired
    now = Time.now.to_i
    if other_lock_expired?(now)
      acquire_lock if now > secure_set_expiration
    end
    has_lock?
  end

  def other_lock_expired?(now)
    now > @redis.get( @lock_key ).to_i
  end

  def secure_set_expiration
    @redis.getset( @lock_key, expiration_timestamp ).to_i
  end

  def try_to_acquire_lock
    expire_at = expiration_timestamp
    if @redis.setnx( @lock_key, expire_at )
      acquire_lock
    end
    has_lock?
  end

  def acquire_lock
    @locked = true
  end

  def expiration_timestamp
    Time.now.to_i + @timeout + 1 
  end
end
