describe RedisCaveKeeper do
  let(:redis) { Redis.new(db: "redis_cave_keeper_dev") }

  let(:key)       { "key-to-lock"  } 
  let(:lock_key)  { "lock:#{key}"  } 

  let(:keeper) { RedisCaveKeeper.new(redis, key) }

  context "when the key is not locked before" do
    it "should be able to acquire lock if the key is not locked" do
      keeper.lock.should be_true
    end

    it "should be locked after successfully acquiring a lock" do
      keeper.lock
      keeper.should have_lock
    end
  end

  context "when the lock key is set but expired" do
    before(:each) do
      redis.set lock_key, ( Time.now.to_i - 42) 
      keeper.lock
    end

    it "should be able to get the lock, if the timestamp is expired" do
      keeper.should have_lock
    end

    it "should set an expiration time in the future" do
      redis.get(lock_key).to_i.should > Time.now.to_i
    end
  end
  
  context "when the key is locked with a valid timestamp" do
    before(:each) do
      redis.set lock_key, ( Time.now.to_i + 10 )
    end

    it "should not have a lock if the locking failed" do
      keeper.lock
      keeper.should_not have_lock
    end

    it "should return false on #lock if it fails" do
      keeper.lock.should be_false
    end
  end

end
