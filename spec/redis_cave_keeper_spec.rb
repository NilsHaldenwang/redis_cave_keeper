describe RedisCaveKeeper do
  let(:redis) { Redis.new(db: "redis_cave_keeper_dev") }

  let(:key)       { "key-to-lock"  } 
  let(:lock_key)  { "cave-keeper-lock:#{key}"  } 

  let(:keeper_without_lock) { RedisCaveKeeper.new(redis, key) } 
  let(:keeper_with_lock)    { keeper_without_lock.tap(&:lock) } 

  context "when it has the lock" do
    subject { keeper_with_lock }

    it "should raise an error if one tries to reacquire the lock" do
      expect do
        subject.lock
      end.to raise_error(RedisCaveKeeper::AlreadyLockedError)
    end
  end

  context "when the key is not locked before" do
    subject { keeper_without_lock }

    it "should be able to acquire the lock if the key is not locked" do
      subject.lock.should be_true
    end

    it "should be locked after successfully acquiring a lock" do
      subject.lock
      subject.should have_lock
    end
  end

  context "when the lock key is set but expired" do
    subject { keeper_without_lock }

    before(:each) do
      redis.set lock_key, (Time.now.to_i - 42) 
    end

    it "should be able to get the lock, if the timestamp is expired" do
      subject.lock.should be_true
    end

    it "should set an expiration time in the future" do
      subject.lock
      redis.get(lock_key).to_i.should > Time.now.to_i
    end
  end
  
  context "when the key is locked with a valid timestamp" do
    subject { keeper_without_lock }

    before(:each) do
      redis.set lock_key, ( Time.now.to_i + 10 )
    end

    it "should not have a lock if the locking failed" do
      subject.lock
      subject.should_not have_lock
    end

    it "should return false on #lock if it fails" do
      subject.lock.should be_false
    end
  end

end
