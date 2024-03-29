include RedisCaveKeeper
describe CaveKeeper do
  let(:redis) { Redis.new(db: "redis_cave_keeper_dev") }

  let(:key)       { "key-to-lock"  } 
  let(:lock_key)  { "cave-keeper-lock:#{key}"  } 

  let(:keeper_without_lock) { CaveKeeper.new(redis, key) } 
  let(:keeper_with_lock)    { keeper_without_lock.tap(&:lock!) } 

  context "#lock_for_update" do
    context "when lock can be acquired" do
      subject { keeper_without_lock }

      it "should execute the given block" do
        test_var = "test"
        subject.lock_for_update!  do
          test_var = "foo"
        end
        test_var.should == "foo"
      end

      it "should lock the key during execution" do
        subject.lock_for_update! do
          subject.should have_lock
        end
      end

      it "should ensure unlock if the block raises an error" do
        expect do
          subject.lock_for_update! do
            raise StandardError, "Just a test raise."
          end
        end.to raise_error(StandardError, "Just a test raise.")
        subject.should_not have_lock
      end

      it "runs the block but raises an error if the unlock fails" do
        test_var = "test"
        expect do
          subject.lock_for_update! do
            redis.del(lock_key)     
            test_var = "foo"
          end
        end.to raise_error(UnlockError) 
        test_var.should == "foo"
      end
    end

    context "#lock_and_load_for_update" do
      subject { keeper_without_lock }

      it "should load the value for the key and hand it into the block" do
        redis.set key, "hello world" 
        subject.lock_and_load_for_update! do |value|
          value.should == "hello world"
        end
      end
    end

    context "#lock_and_load_and_save" do
      subject { keeper_without_lock }

      before(:each) do
        value = "hello world"
        redis.set key, value
      end

      it "should load the value and overwrite it with the return value of the block" do
        subject.lock_and_load_and_save! do |val|
          val.should == "hello world"
          "foo"
        end
        redis.get(key).should == "foo"
      end

      context "when SaveKeyError is raised" do
        before(:each) do
          subject.stub(:getset_expiration).and_return(Time.now.to_i - 10)
          expect do
            subject.lock_and_load_and_save! do |val|
              "foo"
            end
          end.to raise_error(SaveKeyError)
        end

        it "should not save when the lock expired while the block was working" do
          redis.get(key).should == "hello world"
        end

        it "should perform a reset when a SaveKeyError occurs" do
          subject.should_not have_lock 
          subject.retry_manager.attempt_count.should == 0
        end
      end

    end

    context "when lock can not be acquired" do
      subject { keeper_with_lock } 

      it "should not run the block and raise" do
        test_var = "foo"
        expect do
          subject.lock_for_update! do
            test_var = "var" 
          end
        end.to raise_error(LockError)
        test_var.should == "foo"
      end
    end
  end

  context "#lock" do
    context "when it has the lock" do
      subject { keeper_with_lock }

      it "should raise an error if one tries to reacquire the lock" do
        expect do
          subject.lock!
        end.to raise_error(LockError)
      end
    end

    context "when the key is not locked before" do
      subject { keeper_without_lock }

      it "should be able to acquire the lock if the key is not locked" do
        subject.lock!.should be_true
      end

      it "should be locked after successfully acquiring a lock" do
        subject.lock!
        subject.should have_lock
      end
    end

    context "when the lock key is set but expired" do
      subject { keeper_without_lock }

      before(:each) do
        redis.set lock_key, (Time.now.to_i - 42) 
      end

      it "should be able to get the lock, if the timestamp is expired" do
        subject.lock!.should be_true
      end

      it "should set an expiration time in the future" do
        subject.lock!
        redis.get(lock_key).to_i.should > Time.now.to_i
      end

      it "should not acquire the lock if someone else acquires it in the middle of the expiration process" do
        subject.stub(:retry_wait_operation)
        subject.stub(:perform_retry).and_return(false)
        subject.stub(:lock_expired?) do
          redis.set(lock_key, (Time.now.to_i + 42))
          true
        end
        subject.lock!.should be_false
        subject.should_not have_lock
      end
    end

    context "when the key is locked with a valid timestamp" do
      subject { keeper_without_lock }

      before(:each) do
        Kernel.stub(:sleep)
      end

      before(:each) do
        redis.set lock_key, ( Time.now.to_i + 10 )
      end

      it "should not have a lock if the locking failed" do
        expect do
          subject.lock!
        end.to raise_error(RetryError)
        subject.should_not have_lock
      end
    end
  end

  context "#unlock" do
    context "when locked and not expired" do
      subject { keeper_with_lock }

      it "unlocks successfully" do
        subject.unlock!.should be_true      
        subject.should_not have_lock
      end  

      it "should not unlock if someone else gets a lock in the middle of #unlock_save?" do
        subject.stub(:lock_expired?) do
          redis.set lock_key, ( Time.now.to_i - 10)
          false
        end

        expect do
          subject.unlock!
        end.to raise_error(UnlockError)
      end
    end

    context "when not locked" do
      subject { keeper_without_lock }

      it "should raise an error if trying to unlock without lock" do
        expect do
          subject.unlock! 
        end.to raise_error(UnlockError)
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
          subject.unlock!
        end.to raise_error(UnlockError)
      end
    end
  end
end
