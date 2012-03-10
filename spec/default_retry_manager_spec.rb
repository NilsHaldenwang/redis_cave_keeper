include RedisCaveKeeper
describe DefaultRetryManager do
  let(:manager) { DefaultRetryManager.new }

  it "should raise an error after 10 retries" do
    Kernel.stub(:sleep)
    expect do
      11.times do
        manager.run
      end
    end.to raise_error(RetryError)
  end

  it "should sleep the given amount of time and perform the given amount of retries" do
    Kernel.should_receive(:sleep).exactly(42).times.with(2)
    manager = DefaultRetryManager.new(42, 2)
    42.times do
      manager.run
    end
  end

  it "should be resetted after reset" do
    Kernel.stub(:sleep)
    manager.run
    manager.reset
    manager.attempt_count.should == 0
  end
end
