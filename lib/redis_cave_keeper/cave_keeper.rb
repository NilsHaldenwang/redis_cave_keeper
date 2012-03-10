module RedisCaveKeeper
  class CaveKeeper
    attr_reader :lock_time, :redis, :lock_key, :timeout, :key, :retry_manager
    attr_accessor :perform_retry

    def initialize(redis, key, opts = {})
      @redis    = redis
      @key      = key
      @lock_key = "cave-keeper-lock:#{key}"
      @timeout  = opts[:timeout] || 5
      @retry_manager = DefaultRetryManager.new(opts[:max_attempts],
                                               opts[:sleep_time])
      @perform_retry = true
    end

    def lock_for_update(&blk)
      if lock
        begin
          blk.call
        ensure
          unlock
        end
      end
    end

    def lock_and_load_for_update(&blk)
      lock_for_update  do
        blk.call(redis.get(key))
      end
    end

    def lock_and_load_and_save(&blk)
      lock_for_update do
        blk_return = blk.call(redis.get(key))
        unless lock_expired?
          if now < getset_expiration
            redis.set(key, blk_return) 
          else
            raise SaveKeyError, "Can not save key '#{key}', operation took too long." 
          end
        end
      end
    end

    def lock
      raise LockError, "Key '#{key}' is already locked." if has_lock? 
      while !has_lock? && perform_retry
        unless try_to_acquire_lock
          unless acquire_lock_if_expired
            retry_wait_operation
          end
        end
      end
      has_lock?
    end

    def unlock
      raise UnlockError, "Key '#{key}' is not locked." unless has_lock?
      if unlock_save?
        # Our lock is extended by timeout + 1, so we safely can
        # release the lock.
        release_lock_and_reset
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
    def retry_wait_operation
      @retry_manager.run
    end

    def unlock_save?
      return false if lock_expired?  
      return false if getset_expiration < now
      true
    end

    def release_lock_and_reset
      redis.del(lock_key)
      @locked = false
      @retry_manager.reset
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
      has_lock?
    end

    def lock_expired?
      now > get_lock_expiration
    end

    def try_to_acquire_lock
      if setnx_expiration
        acquire_lock
      end
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
  end
end

