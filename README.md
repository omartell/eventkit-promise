# Eventkit::Promise

Promises/A+ for Ruby

[![Build Status](https://travis-ci.org/omartell/eventkit-promise.svg?branch=master)](https://travis-ci.org/omartell/eventkit-promise)

Supported Ruby versions: 1.9.3, 2.0, 2.1, 2.2

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'eventkit-promise'
```

## Usage

```ruby
require 'eventkit/promise'

# Resolving a promise

promise = Eventkit::Promise.new

promise.then(->(value) { value + 1 })

promise.resolve(1)

promise.value # => 1

# Rejecting a promise

promise = Eventkit::Promise.new

promise.then(
  ->(value) {
    value + 1
  },
  ->(error) {
    log(error.message)
  }
)

promise.reject(NoMethodError.new('Undefined method #call'))

promise.reason # => <NoMethodError: undefined method #call>

# Chaining promises

promise_a = Eventkit::Promise.new

promise_b = promise_a
  .then(->(v) { v + 1 })
  .then(->(v) { v + 1 })
  .then(->(v) { v + 1 })

promise_b.catch { |error|
# Handle errors raised by any of the previous handlers
}

promise_a.resolve(1)

promise_a.value # => 1
promise_b.value # => 4

# Resolving and fullfiling with another promise

promise_a = Eventkit::Promise.new
promise_b = Eventkit::Promise.new

promise_a.resolve(promise_b)

promise_b.resolve('foobar')

promise_a.value # => foobar

# Resolving and rejecting with another promise

promise_a = Eventkit::Promise.new
promise_b = Eventkit::Promise.new

promise_a.resolve(promise_b)

promise_b.reject('Ooops can not continue')

promise_a.reason # => 'Ooops can not continue'

# Initializing with a block

promise = Promise.new do |p|
  p.resolve('foobar')
end

promise.value # => 'foobar'

```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/eventkit-promise/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
6. Happy hacking!

