require "redis_cave_keeper/version"

class RedisCaveKeeper
  attr_reader :lock_time, :redis, :lock_key, :timeout

  class CaveKeeperError < StandardError; end
  class AlreadyLockedError < CaveKeeperError; end

  def initialize(redis, key, opts = {})
    @redis    = redis
    @lock_key = "cave-keeper-lock:#{key}"
    @timeout  = opts[:timeout] || 5
  end

  def lock
    raise AlreadyLockedError, "Key is already locked." if has_lock? 
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
    if other_lock_expired?
      acquire_lock if now > secure_set_expiration
    end
    reset unless has_lock?
    has_lock?
  end

  def other_lock_expired?
    now > redis.get( lock_key ).to_i
  end

  def secure_set_expiration
    redis.getset( lock_key, expiration_timestamp ).to_i
  end

  def try_to_acquire_lock
    if redis.setnx( lock_key, expiration_timestamp )
      acquire_lock
    end
    reset unless has_lock?
    has_lock?
  end

  def acquire_lock
    @locked = true
    @locked_until = expiration_timestamp
  end

  def expiration_timestamp
    @expiration_timestamp ||= ( Time.now.to_i + timeout + 1 ) 
  end

  def now
    @now ||= Time.now.to_i
  end

  def reset
    @expiration_timestamp = nil
    @locked_until = nil
    @now = nil
    @locked = false
  end
end
