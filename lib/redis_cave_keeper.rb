require "redis_cave_keeper/version"

class RedisCaveKeeper
  attr_reader :lock_time, :redis, :lock_key, :timeout, :key

  class CaveKeeperError < StandardError; end
  class LockError < CaveKeeperError; end
  class UnlockError < CaveKeeperError; end

  def initialize(redis, key, opts = {})
    @redis    = redis
    @key      = key
    @lock_key = "cave-keeper-lock:#{key}"
    @timeout  = opts[:timeout] || 5
  end

  def lock
    raise LockError, "Key '#{key}' is already locked." if has_lock? 
    unless try_to_acquire_lock
      acquire_lock_if_expired
    end
    has_lock?
  end

  def unlock
    raise UnlockError, "Key '#{key}' is not locked." unless has_lock?
    raise UnlockError, "The lock for the key '#{key}' is expired." if lock_expired?
    if redis.getset(lock_key, ( now + timeout + 1 )).to_i < now 
      # Someone else acquired the lock via getset.
      raise UnlockError, "The lock for the key '#{key}' is expired."
    else
      # Our lock is extended by timeout + 1, so we safely can
      # perform a delete.
      redis.del(lock_key)
      reset
      true
    end
  end

  def has_lock?
    @locked  
  end

  protected
  def acquire_lock_if_expired
    if lock_expired?
      # Use getset here to make sure no one else
      # acquired a lock in the meantime.
      acquire_lock if now > secure_set_expiration
    end
    reset_unless_locked
  end

  def lock_expired?
    now > redis.get( lock_key ).to_i
  end

  def secure_set_expiration
    redis.getset( lock_key, expiration_timestamp ).to_i
  end

  def try_to_acquire_lock
    if redis.setnx( lock_key, expiration_timestamp )
      acquire_lock
    end
    reset_unless_locked
  end

  def reset_unless_locked
    reset unless has_lock?
    has_lock?
  end

  def acquire_lock
    @locked = true
  end

  def expiration_timestamp
    Time.now.to_i + timeout + 1 
  end

  def now
    Time.now.to_i
  end

  def reset
    @now = nil
    @locked = false
  end
end
