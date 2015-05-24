# Eventkit::Promise

Promises/A+ for Ruby

[![Build Status](https://travis-ci.org/omartell/eventkit-promise.svg?branch=master)](https://travis-ci.org/omartell/eventkit-promise)

Supported Ruby versions: 1.9.3, 2.0, 2.1, 2.2

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'eventkit-promise'
```

## Configuration

On fullfiled and on rejected handlers should execute asynchronously
according to the [Promises\A+ spec]
(https://promisesaplus.com/#point-67). So, the main dependency
for an `Eventkit::Promise` is the object that provides the execution
context for handlers, which we will be calling the `TaskScheduler`.

In your project, you will need to define an implementation for a
`TaskScheduler`, which sould have a `#schedule_execution` method that
takes a block.

If you're using something like Event Machine, then you could do
something like this:

```ruby
require 'eventkit/task_scheduler'

class EMTaskScheduler < EventKit::TaskScheduler
  def schedule_execution(&block)
    EM::next_tick(&block)
  end
end

task_scheduler = EMTaskScheduler.new

Eventkit::Promise.new(task_scheduler)
```

If you're using `Eventkit::Eventloop`, then you could do:

```ruby
require 'eventkit/task_scheduler'

class NextTickScheduler < Eventkit::TaskScheduler
  def initialize(event_loop)
    @event_loop = event_loop
  end

  def schedule_execution(&block)
    @event_loop.on_next_tick(&block)
  end
end

task_scheduler = NextTickScheduler.new

Eventkit::Promise.new(task_scheduler)
```

## Usage

```ruby
require 'eventkit/promise'

# Resolving a promise

promise = Eventkit::Promise.new(task_scheduler)

promise.then(->(value) { value + 1 })

promise.resolve(1)

# Rejecting a promise

promise = Eventkit::Promise.new(task_scheduler)

promise.then(
  ->(value) {
    value + 1
  },
  ->(error) {
    log(error.message)
  }
)

promise.reject(NoMethodError.new('Undefined method #call'))

# Chaining promises

promise_a = Eventkit::Promise.new(task_scheduler)

promise_b = promise_a
  .then(->(v) { v + 1 })
  .then(->(v) { v + 1 })
  .then(->(v) { v + 1 })

promise_b.catch { |error|
# Handle errors raised by any of the previous handlers
}

promise_a.resolve(1)

# Resolving and fullfiling with another promise

promise_a = Eventkit::Promise.new(task_scheduler)
promise_b = Eventkit::Promise.new(task_scheduler)

promise_a.resolve(promise_b)

promise_b.resolve('foobar')

# Resolving and rejecting with another promise

promise_a = Eventkit::Promise.new(task_scheduler)
promise_b = Eventkit::Promise.new(task_scheduler)

promise_a.resolve(promise_b)

promise_b.reject('Ooops can not continue')

# Initializing with a block

promise = Promise.new(task_scheduler) do |p|
  p.resolve('foobar')
end

```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/eventkit-promise/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
6. Happy hacking!

