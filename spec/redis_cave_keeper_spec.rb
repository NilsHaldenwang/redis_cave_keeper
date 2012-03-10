describe RedisCaveKeeper do
  let(:redis) { Redis.new(db: "redis_cave_keeper_dev") }

  let(:key)       { "key-to-lock"  } 
  let(:lock_key)  { "cave-keeper-lock:#{key}"  } 

  let(:keeper_without_lock) { RedisCaveKeeper.new(redis, key) } 
  let(:keeper_with_lock)    { keeper_without_lock.tap(&:lock) } 

  context "#lock" do
    context "when it has the lock" do
      subject { keeper_with_lock }

      it "should raise an error if one tries to reacquire the lock" do
        expect do
          subject.lock
        end.to raise_error(RedisCaveKeeper::LockError)
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

      it "should not acquire the lock if someone else acquires it in the middle of the expiration process" do
        subject.stub(:lock_expired?) do
          redis.set(lock_key, (Time.now.to_i + 42))
          true
        end
        subject.lock.should be_false
        subject.should_not have_lock
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

  context "#unlock" do
    context "when locked and not expired" do
      subject { keeper_with_lock }

      it "unlocks successfully" do
        subject.unlock.should be_true      
        subject.should_not have_lock
      end  

      it "should not unlock if someone else gets a lock in the middle of #unlock_save?" do
        subject.stub(:lock_expired?) do
          redis.set lock_key, ( Time.now.to_i - 10)
          false
        end

        expect do
          subject.unlock
        end.to raise_error(RedisCaveKeeper::UnlockError)
      end
    end

    context "when not locked" do
      subject { keeper_without_lock }

      it "should raise an error if trying to unlock without lock" do
        expect do
          subject.unlock 
        end.to raise_error(RedisCaveKeeper::UnlockError)
      end
    end

    context "when the lock is expired" do
      subject { keeper_with_lock }

      before(:each) do
        subject
        redis.set lock_key, (Time.now.to_i - 42) 
      end

      it "should raise an error" do
        expect  do
          subject.unlock
        end.to raise_error(RedisCaveKeeper::UnlockError)
      end
    end
  end
end
