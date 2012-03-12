# Redis Cave Keeper

This gem provides some convenient methods for locking and updating redis keys.

## Installation

You can install the gem by hand:

    gem install redis_cave_keeper

Or add the following to your `Gemfile`:

    gem "redis_cave_keeper" 

## Usage

The necessary class ```CaveKeeper``` lives within the module ```RedisCaveKeeper```, so you have to use it as ```RedisCaveKeeper::CaveKeeper``` or ```include RedisCaveKeeper```, which is assumed in the following examples.

### Configuration
The ```CaveKeeper``` needs to be instantiated and can be configured through a hash, given to its constructor.

```ruby
keeper = CaveKeeper.new(
            redis,           # redis instance to work on
            'key-to-lock',   # redis key that should be locked
            timeout: 10      # the time the lock will be valid [seconds],
                             # default: 5
            max_attempts: 42 # number of retries if the lock can not be acquired immediately,
                             # default: 25
            sleep_time: 5    # wait time between retries [seconds],
         )                   # default: 0.25
         
```

### Lock a key to do an update

**Attention**: You have to make sure your operation does not take longer than the timeout, otherwise you may cause race conditions or lost updates with the operations within the block (because they are executed no matter what, even if the unlock fails).

#### Just lock
```ruby
keeper.lock_for_update! do
  # do some crazy stuff here.
end
```

The method will bang with a ```RedisCaveKeeper::LockError``` if the lock can not be acquired and with a ```RedisCaveKeeper:UnlockError``` if the timeout is exceeded and hence the key can not safely be unlocked.

#### Lock and load
Because you usually want to load the key you are locking there is a method for this as well:

```ruby
keeper.lock_and_load_for_update! do |value|
  # value will contain what redis.get("key-to-lock") returned
end
```

The bang behaviour is the same as for #lock_for_update!.

#### Lock and load and save

Finally there is a method that also manages the save for you:

```ruby
keeper.lock_and_load_and_save! do |value|
  # value will contain what redis.get("key-to-lock") returned
  # the return value of the given block will be saved back via redis.set("key-to-lock")
  "new-value"
end
# redis.get("key-to-lock") will be "new-value" now
```

This one bangs with ```RedisCaveKeeper::LockError``` as well if it can not acquire the lock. Before it does the save, it checks
if the lock is still valid and bangs with ```RedisCaveKeeper::SaveKeyError``` unless the lock is valid.
**Attention:** No ```RedisCaveKeeper::UnlockError``` is raised in this case.

#### Handle lock and unlock manually

Of course you can handle the locking and unlocking manually.

```ruby
keeper.lock!   # Bangs with RedisCaveKeeper::LockError if it fails
# do some stuff
keeper.unlock! # Bangs with RedisCaveKeeper::UnlockError if it fails (e.g. because of timeout)
```

See the API documentation for more information about some helpful methods for manually handling the locking.

#### Error handling

All the errors inherit from ```RedisCaveKeeper::CaveKeeperError```, so if you
do not care which one it is you can do something like:

```ruby
begin
  # your stuff here
rescue RedisCaveKeeper::CaveKeeperError => e
  # do something with the error here
end
```
Since any kind of Pokemon-Exception-Handling is bad you should not do this, but it may
sometimes be necessary and is still better than ```rescue Exception```.

## Credits

This gem basically implements the locking algorithm described on the reference page
of the redis command [SETNX](http://redis.io/commands/setnx "Redis#SETNX").

It is inspired by [@PatrickTulskie](https://github.com/PatrickTulskie)'s [redis-lock](https://github.com/PatrickTulskie/redis-lock "Original redis-lock")
and [@crowdtap](https://github.com/crowdtap)'s [fork](https://github.com/crowdtap/redis-lock "Fork of redis-lock") with the refactorings of [@joshuaclayton](https://github.com/joshuaclayton).

## Authors
Nils Haldenwang (http://www.nils-haldenwang.de)
