module RedisCaveKeeper
  class CaveKeeperError < StandardError;   end
  class LockError       < CaveKeeperError; end
  class UnlockError     < CaveKeeperError; end
  class RetryError      < CaveKeeperError; end
  class SaveKeyError    < CaveKeeperError; end
end
