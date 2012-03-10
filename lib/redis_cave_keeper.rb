require "redis_cave_keeper/version"

class RedisCaveKeeper
  attr_reader :lock_time, :redis, :lock_key, :timeout, :key

  class CaveKeeperError < StandardError;   end
  class LockError       < CaveKeeperError; end
  class UnlockError     < CaveKeeperError; end

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
    if unlock_save?
      # Our lock is extended by timeout + 1, so we safely can
      # release the lock.
      release_lock 
      reset
      true
    else
      # Someone else acquired the lock via getset.
      raise UnlockError, "The lock for the key '#{key}' is expired."
    end
  end

  def has_lock?
    @locked  
  end

  protected
  def unlock_save?
    return false if lock_expired?  
    return false if getset_expiration < now
    true
  end

  def release_lock
    redis.del(lock_key)
  end

  def get_lock_expiration
    redis.get(lock_key).to_i
  end

  def getset_expiration
    redis.getset(lock_key, expiration_timestamp).to_i
  end

  def setnx_expiration
    redis.setnx(lock_key, expiration_timestamp)  
  end

  def acquire_lock_if_expired
    if lock_expired?
      # Use getset here to make sure no one else
      # acquired a lock in the meantime.
      acquire_lock if now > getset_expiration
    end
    reset_unless_locked
  end

  def lock_expired?
    now > get_lock_expiration
  end

  def try_to_acquire_lock
    if setnx_expiration
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
