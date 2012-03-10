module RedisCaveKeeper
  class DefaultRetryManager
    attr_reader :attempt_count

    def initialize(max_attempts = 10, sleep_time = 0.25)
      @max_attempts  = max_attempts || 10
      @sleep_time    = sleep_time   || 0.25
      @attempt_count = 0
    end

    def run
      check_max_attempts_reached!
      increment_attempts	
      Kernel.sleep @sleep_time
    end

    def reset
      @attempt_count = 0		
    end

    protected
    def increment_attempts
      @attempt_count += 1	
    end

    def check_max_attempts_reached!
      if @attempt_count >= @max_attempts
        raise RetryError, "Have not been able to acquire lock with #{@attempt_count} retries."		
      end
    end
  end
end
