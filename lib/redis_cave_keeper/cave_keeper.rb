module RedisCaveKeeper
  class CaveKeeper
    attr_reader :lock_time, :redis, :lock_key, :timeout, :key, :retry_manager,
      :perform_retry


    # Valid configuration options:
    #   :timeout      - interval how long the lock will be valid [seconds]
    #   :max_attempts - number of retries if the lock can not be acquired immediately 
    #   :sleep_time   - time to sleep between retries [seconds]
    #
    # @param [Redis] redis an active redis connection
    # @param [String] key the key to lock
    # @param [Hash] opts configuration options
    def initialize(redis, key, opts = {})
      @redis    = redis
      @key      = key
      @lock_key = "cave-keeper-lock:#{key}"
      @timeout  = opts[:timeout] || 5
      @retry_manager = DefaultRetryManager.new(opts[:max_attempts],
                                               opts[:sleep_time])
      @perform_retry = true # needed to test the race conditions
    end

    # Locks the key, executes the given block and unlocks it afterwards.
    #
    # See #lock! for more information on the retry behaviour.
    #
    # Raises RedisCaveKeeper::LockError unless the lock can be acquired.
    # Raises RedisCaveKeeper::UnlockError unless the key can be unlocked.
    def lock_for_update!(&blk)
      if lock!
        begin
          blk.call
        ensure
          unlock!
        end
      end
    end

    # Behaves widely like #lock_for_update.
    #
    # Additionally it loads the value for the key and yields it to the block.
    def lock_and_load_for_update!(&blk)
      lock_for_update! do
        blk.call(redis.get(key))
      end
    end

    # Behaves widely like #lock_and_load_for_update.
    #
    # Additionally it tries to save the return value of the block as new
    # value for the key to redis. It makes sure the lock did not time out
    # before saving.
    #
    # Instead of raising RedisCaveKeeper::UnlockError it raises
    # RedisCaveKeeper::SaveKeyError when the lock expired during the execution
    # of the given block.
    def lock_and_load_and_save!(&blk)
      dont_ensure_unlock = false

      if lock!
        begin
          value = redis.get(key)

          blk_return = blk.call(value)

          if lock_still_valid_and_extended?
            redis.set(key, blk_return) 
          else
            reset # our lock is no longer valid if we get here
            dont_ensure_unlock = true
            raise SaveKeyError, "Cannot save key '#{key}', operation took too long." 
          end
        ensure
          unlock! unless dont_ensure_unlock
        end
      end
    end

    # Tries to acquire the lock. Performs the configured number of retries (default: 25)
    # and sleeps sleep_time (default: 0.25s) in between.
    #
    # See #initialize for the configuration options.
    #
    # Raises RedisCaveKeeper::LockError unless the lock can be acquired.
    def lock!
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

    def unlock!
      raise UnlockError, "Key '#{key}' is not locked." unless has_lock?
      if unlock_save?
        # Our lock is extended by timeout + 1, so we safely can
        # release the lock.
        release_lock_and_reset
        true
      else
        # Someone else acquired the lock via getset since we first
        # checked if the lock is still valid via get.
        raise UnlockError, "The lock for the key '#{key}' is expired."
      end
    end

    # Indicates if the CaveKeeper had been able to
    # acquire a lock. This should NOT be used to check
    # if the lock is expired, because it is does not
    # check this.
    def has_lock?
      @locked  
    end

    # Checks if the lock of the key is expired.
    def lock_expired?
      now > get_lock_expiration
    end

    # Returns false if the lock is expired.
    # If it is still valid it tries to extend the expiration time
    # with an getset operation. If this fails it returns false.
    #
    # The key can be safely unlocked within the timeout interval if this
    # method returns true.
    def unlock_save?
      lock_still_valid_and_extended?
    end

    protected
    def lock_still_valid_and_extended?
      if lock_expired?
        false
      elsif getset_expiration < now
        false
      else
        true
      end
    end

    def retry_wait_operation
      @retry_manager.run
    end

    def release_lock_and_reset
      redis.del(lock_key)
      reset
    end

    def reset
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

