require 'eventkit/promise'
require 'eventkit/event_loop'
require 'eventkit/task_scheduler'

module Eventkit
  RSpec.describe Promise do

    class NextTickScheduler < Eventkit::TaskScheduler
      def initialize(event_loop)
        @event_loop = event_loop
      end

      def schedule_execution(&handler)
        @event_loop.on_next_tick(&handler)
      end
    end

    let(:event_loop) {
      EventLoop.new
    }

    let(:task_scheduler) {
       NextTickScheduler.new(event_loop)
    }

    let(:promise) {
      Promise.new(task_scheduler)
    }

    def start_event_loop
      event_loop.register_timer(run_in: 0.1) {
        event_loop.stop
      }
      event_loop.start
    end

    it 'accepts a block when initialized' do
      promise = Promise.new(task_scheduler) { |p|
        p.resolve(:foo)
      }

      expect { |block|
        promise.then(block)

        start_event_loop
      }.to yield_with_args(:foo)
    end

    it 'executes on fullfiled handlers when resolved' do
      expect { |block|
        promise.on_fullfiled(&block)
        promise.on_fullfiled(&block)
        promise.on_fullfiled(&block)
        promise.resolve(:foo)

        start_event_loop
      }.to yield_successive_args(:foo, :foo, :foo)
    end

    it 'executes on fullfiled handlers after resolved' do
      expect { |block|
        promise.resolve(:foo)
        promise.on_fullfiled(&block)

        start_event_loop
      }.to yield_with_args(:foo)
    end

    it 'does not execute on fullfiled handler when resolved with a pending promise' do
      promise_b = Promise.new(task_scheduler)
      expect { |block|
        promise.resolve(promise_b)
        promise.on_fullfiled(&block)

        start_event_loop
      }.to_not yield_control.once
    end

    it 'only executes on fullfiled handlers once even when resolved multiple times' do
      expect { |block|
        promise.on_fullfiled(&block)
        promise.resolve(:foo)
        promise.resolve(:foo)

        start_event_loop
      }.to yield_control.once
    end

    it 'executes on fullfiled handlers in the same order as the originating calls' do
      expect { |block|
        promise.on_fullfiled { block.to_proc.call(1) }
        promise.on_fullfiled { block.to_proc.call(2) }
        promise.on_fullfiled { block.to_proc.call(3) }
        promise.resolve(:foo)

        start_event_loop
      }.to yield_successive_args(1, 2, 3)
    end

    it 'executes on rejected handlers when rejected' do
      expect { |block|
        promise.on_rejected(&block)
        promise.on_rejected(&block)
        promise.on_rejected(&block)
        promise.reject(:error)

        start_event_loop
      }.to yield_successive_args(:error, :error, :error)
    end

    it 'only executes on rejected handlers once even when rejected multiple times' do
      expect { |block|
        promise.on_rejected(&block)
        promise.reject(:error)
        promise.reject(:error)

        start_event_loop
      }.to yield_control.once
    end

    it 'executes on rejected handlers in the same order as the originating calls' do
      expect { |block|
        promise.on_rejected { block.to_proc.call(1) }
        promise.on_rejected { block.to_proc.call(2) }
        promise.on_rejected { block.to_proc.call(3) }

        promise.reject(:error)

        start_event_loop
      }.to yield_successive_args(1, 2, 3)
    end

    it 'executes on rejected handlers when it has been already rejected' do
      expect { |block|
        promise.reject(:error)
        promise.on_rejected(&block)

        start_event_loop
      }.to yield_with_args(:error)
    end

    it 'does not execute on fullfiled handlers if it has not been fullfiled' do
      expect { |block|
        promise.on_fullfiled(&block)

        start_event_loop
      }.to_not yield_with_args(:error)
    end

    it 'does not execute on rejected handlers if it has not been rejected' do
      expect { |block|
        promise.on_rejected(&block)

        start_event_loop
      }.to_not yield_with_args(:error)
    end

    it 'can not be rejected once it has been fulfilled' do
      expect { |block|
        promise.on_fullfiled(&block)
        promise.resolve(:foo)
        promise.on_rejected(&block)
        promise.reject(:error)

        start_event_loop
      }.to yield_with_args(:foo)
    end

    it 'can not be fullfiled once it has been rejected' do
      expect { |block|
        promise.on_rejected(&block)
        promise.on_fullfiled(&block)
        promise.reject(:error)
        promise.resolve(:foo)

        start_event_loop
      }.to yield_with_args(:error)
    end

    describe '#on_fullfiled' do
      it 'behaves the same as on fullfiled passed to then' do
        expect  { |block|
          promise_b = promise.on_fullfiled { |value|
            block.to_proc.call(value + 1)
            value + 1
          }

          promise_b.on_fullfiled { |value|
            block.to_proc.call(value + 5)
            value + 5
          }

          promise.resolve(1)

          start_event_loop
        }.to yield_successive_args(2, 7)
      end
    end

    describe '#on_rejected' do
      it 'behaves the same as on rejected passed to then' do
        expect  { |block|
          promise_b = promise.on_rejected { |value|
            block.to_proc.call(value + 1)
            value + 1
          }

          promise_b.on_fullfiled { |value|
            block.to_proc.call(value + 5)
            value + 5
          }

          promise.reject(1)

          start_event_loop
        }.to yield_successive_args(2, 7)
      end
    end

    describe '#then' do
      it 'adds on fullfiled handlers' do
        expect { |block|
          promise.then(block)
          promise.resolve(:foo)

          start_event_loop
        }.to yield_with_args(:foo)
      end

      it 'adds on rejected handlers' do
        expect { |block|
          promise.then(nil, block)
          promise.reject(:error)

          start_event_loop
        }.to yield_with_args(:error)
      end

      it 'does not require both on fullfiled and on rejected handlers' do
        expect { |block|
          promise.then(nil, block)
          promise.then(block)
          promise.reject(:error)

          start_event_loop
        }.to yield_with_args(:error)
      end

      it 'pipelines the value from on fullfiled to the returned promise' do
        expect { |block|
          promise
            .then(->(value) {
                    block.to_proc.call(value + 1)
                    value + 1
                  })
            .then(->(value) {
                    block.to_proc.call(value + 5)
                    value + 5
                  })
            .then(->(value) {
                    block.to_proc.call(value + 10)
                    value + 10
                  })

          promise.resolve(1)

          start_event_loop
        }.to yield_successive_args(2, 7, 17)
      end

      it 'pipelines the value from on rejected to the returned promise' do
        expect { |block|
          promise
            .then(nil, ->(reason) {
                    block.to_proc.call('bar')
                    'bar'
                  })
            .then(->(reason) {
                    block.to_proc.call('baz')
                    'baz'
                  })
            .then(->(reason) {
                    block.to_proc.call('zoo')
                    'zoo'
                  })

          promise.reject('foo')

          start_event_loop
        }.to yield_successive_args('bar', 'baz', 'zoo')
      end

      it 'rejects the returned promise when on fullfiled throws an exception' do
        promise_b = promise.then(->(value) { fail ArgumentError })

        promise.resolve('foobar')

        expect { |block|
          promise_b.on_rejected(&block)

          start_event_loop
        }.to yield_with_args(an_instance_of(ArgumentError))
      end

      it 'rejects the returned promise when on rejected throws an exception' do
        promise_b = promise
                      .then(->(value) { fail ArgumentError })
                      .then(nil, ->(value) { fail NoMethodError })

        promise.resolve('foobar')

        expect { |block|
          promise_b.on_rejected(&block)

          start_event_loop
        }.to yield_with_args(an_instance_of(NoMethodError))
      end

      it 'fullfills the returned promise with the same value when on fullfiled is not a function' do
        promise_b = promise.then(nil, -> { })

        promise.resolve(:foo)

        expect { |block|
          promise_b.on_fullfiled(&block)

          start_event_loop
        }.to yield_with_args(:foo)
      end

      it 'rejects the returned promise with the same reason when on rejected is not a function' do
        promise_b = promise.then(-> { }, nil)

        promise.reject(:error)

        expect { |block|
          promise_b.on_rejected(&block)

          start_event_loop
        }.to yield_with_args(:error)
      end
    end

    describe 'resolution procedure' do
      it 'throws a TypeError if promise is resolved with itself' do
        expect { promise.resolve(promise) }.to raise_error(TypeError)
      end

      it 'adopts the given promise state when resolved with a promise'do
        promise_a = Promise.new(task_scheduler)
        promise_b = Promise.new(task_scheduler)

        expect { |block|
          promise_a.on_fullfiled(&block)
          promise_a.resolve(promise_b)
          promise_b.resolve(:foobar)

          start_event_loop
        }.to yield_with_args(:foobar)

        promise_a = Promise.new(task_scheduler)
        promise_b = Promise.new(task_scheduler)

        expect { |block|
          promise_a.on_rejected(&block)
          promise_a.resolve(promise_b)
          promise_b.reject(:error)

          start_event_loop
        }.to yield_with_args(:error)
      end

      it 'remains pending until the other promise is resolved' do
        promise_a = Promise.new(task_scheduler)
        promise_b = Promise.new(task_scheduler)

        promise_a.resolve(promise_b)
        promise_a.resolve(:foo)

        expect(promise_a).to be_pending

        promise_b.resolve(:bar)

        start_event_loop

        expect(promise_a).to be_resolved
      end

      it 'runs the resolution procedure when resolved with a promise and that promise is resolved' do
        promise_a = Promise.new(task_scheduler)
        promise_b = Promise.new(task_scheduler)

        promise_a.resolve(promise_b)

        expect { |block|
          promise_b.then(block)

          promise_a.then(block)

          promise_b.resolve(:foo)

          start_event_loop
        }.to yield_successive_args(:foo, :foo)
      end

      it 'rejects the promise when resolved with a promise and that promise is rejected' do
        promise_a = Promise.new(task_scheduler)
        promise_b = Promise.new(task_scheduler)

        promise_a.resolve(promise_b)

        expect { |block|
          promise_b.on_rejected(&block)

          promise_a.on_rejected(&block)

          promise_b.reject(:error)

          start_event_loop
        }.to yield_successive_args(:error, :error)
      end

      it 'rejects the promise if calling then throws an exception' do
        promise_a = Promise.new(task_scheduler)
        promise_b = Promise.new(task_scheduler)

        allow(promise_b).to receive(:then).and_raise(NoMethodError)

        promise_a.resolve(promise_b)

        expect { |block|
          promise_a.on_rejected(&block)

          start_event_loop
        }.to yield_successive_args(an_instance_of(NoMethodError))
      end
    end

    describe 'clean-stack execution ordering tests (fulfillment case)' do
      specify 'when on_fullfiled is added immediately before the promise is fulfilled' do
        on_fullfiled_finished = false

        promise.then(->(_) { on_fullfiled_finished = true })

        promise.resolve(:foobar)

        expect(on_fullfiled_finished).to be_falsy
      end

      specify 'when on fullfiled is added immediately after the promise is fullfiled' do
        on_fullfiled_finished = false

        promise.resolve(:foobar)

        promise.then(->(_) { on_fullfiled_finished = true })

        expect(on_fullfiled_finished).to be_falsy
      end

      specify 'when on fullfiled is added inside another on fullfiled' do
        promise = Promise.new(task_scheduler)
        on_fullfiled_finished = false

        expect { |block|
          promise.then(->(v) {
                         promise.then(->(v) {
                                        block.to_proc.call(on_fullfiled_finished)
                                      })
                         on_fullfiled_finished = true
                       })

          promise.resolve(:foo)

          start_event_loop
        }.to yield_with_args(true)
      end

      specify 'when on fullfiled is added inside on rejected' do
        promise_a = Promise.new(task_scheduler)
        promise_b = Promise.new(task_scheduler)
        on_rejected_finished = false

        expect { |block|
          promise_a.then(nil, ->(v) {
                           promise_b.then(->(v) {
                                            block.to_proc.call(on_rejected_finished)
                                          })
                           on_rejected_finished = true
                         })

          promise_a.reject(:foo)
          promise_b.resolve(:bar)

          start_event_loop
        }.to yield_with_args(true)
      end

      specify 'when the promise is fullfiled asynchronously' do
        on_fullfiled_finished = false

        expect { |block|
          event_loop.register_timer(run_in: 0.1) {
            on_fullfiled_finished = true
            promise.resolve(:foo)
          }

          event_loop.register_timer(run_in: 0.2) {
            event_loop.stop
          }

          promise.then(->(_) { block.to_proc.call(on_fullfiled_finished) })

          event_loop.start
        }.to yield_with_args(true)
      end
    end

    describe 'clean-stack execution ordering tests (rejected case)' do
      specify 'when on rejected is added immediately before the promise is rejected' do
        on_rejected_finished = false

        promise.on_rejected(&->(_) { on_rejected_finished = true })

        promise.reject(:foobar)

        expect(on_rejected_finished).to be_falsy
      end

      specify 'when on rejected is added immediately after the promise is rejected' do
        on_rejected_finished = false

        promise.reject(:foobar)

        promise.then(->(_) { on_rejected_finished = true })

        expect(on_rejected_finished).to be_falsy
      end

      specify 'when on rejected is added inside on fullfiled' do
        promise_a = Promise.new(task_scheduler)
        promise_b = Promise.new(task_scheduler)
        on_rejected_finished = false

        expect { |block|
          promise_a.then(->(v) {
                           promise_b.on_rejected(&->(v) {
                                                   block.to_proc.call(on_rejected_finished)
                                                 })
                           on_rejected_finished = true
                         })

          promise_a.resolve(:foo)
          promise_b.reject(:bar)

          start_event_loop
        }.to yield_with_args(true)
      end

      specify 'when on rejected is added inside on rejected' do
        promise_a = Promise.new(task_scheduler)
        promise_b = Promise.new(task_scheduler)
        on_rejected_finished = false


        expect { |block|
          promise_a.on_rejected(&->(v) {
                                  promise_b.on_rejected(&->(v) {
                                                          block.to_proc.call(on_rejected_finished)
                                                        })
                                  on_rejected_finished = true
                                })

          promise_a.reject(:foo)
          promise_b.reject(:bar)

          start_event_loop
        }.to yield_with_args(true)
      end

      specify 'when the promise is rejected asynchronously' do
        on_rejected_finished = false

        expect { |block|
          event_loop.register_timer(run_in: 0.1) {
            on_rejected_finished = true
            promise.reject(:error)
          }

          event_loop.register_timer(run_in: 0.2) {
            event_loop.stop
          }

          promise.on_rejected(&->(_) { block.to_proc.call(on_rejected_finished) })

          event_loop.start
        }.to yield_with_args(true)
      end
    end
  end
end
