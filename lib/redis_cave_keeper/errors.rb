module RedisCaveKeeper
  class CaveKeeperError < StandardError;   end
  class LockError       < CaveKeeperError; end
  class UnlockError     < CaveKeeperError; end
end
