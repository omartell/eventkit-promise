require 'eventkit/promise'

module Eventkit
  RSpec.describe Promise do
    let(:promise) { Promise.new }

    it 'executes on fullfiled handlers when resolved' do
      expect do |block|
        promise.on_fullfiled(&block)
        promise.on_fullfiled(&block)
        promise.on_fullfiled(&block)
        promise.resolve(:foo)
      end.to yield_successive_args(:foo, :foo, :foo)
    end

    it 'executes on fullfiled handlers after resolved' do
      expect do |block|
        promise.resolve(:foo)
        promise.on_fullfiled(&block)
      end.to yield_successive_args(:foo)
    end

    it 'does not execute on fullfiled handler when resolved with a pending promise' do
      promise_b = Promise.new
      expect do |block|
        promise.resolve(promise_b)
        promise.on_fullfiled(&block)
      end.to_not yield_control.once
    end

    it 'only executes on fullfiled handlers once even when resolved multiple times' do
      expect do |block|
        promise.on_fullfiled(&block)
        promise.resolve(:foo)
        promise.resolve(:foo)
      end.to yield_control.once
    end

    it 'executes on fullfiled handlers in the same order as the originating calls' do
      expect do |block|
        promise.on_fullfiled { block.to_proc.call(1) }
        promise.on_fullfiled { block.to_proc.call(2) }
        promise.on_fullfiled { block.to_proc.call(3) }
        promise.resolve(:foo)
      end.to yield_successive_args(1, 2, 3)
    end

    it 'executes on rejected handlers when rejected' do
      expect do |block|
        promise.on_rejected(&block)
        promise.on_rejected(&block)
        promise.on_rejected(&block)
        promise.reject(:error)
      end.to yield_successive_args(:error, :error, :error)
    end

    it 'only executes on rejected handlers once even when rejected multiple times' do
      expect do |block|
        promise.on_rejected(&block)
        promise.reject(:error)
        promise.reject(:error)
      end.to yield_control.once
    end

    it 'executes on rejected handlers in the same order as the originating calls' do
      expect do |block|
        promise.on_rejected { block.to_proc.call(1) }
        promise.on_rejected { block.to_proc.call(2) }
        promise.on_rejected { block.to_proc.call(3) }
        promise.reject(:error)
      end.to yield_successive_args(1, 2, 3)
    end

    it 'executes on rejected handlers when it has been already rejected' do
      expect do |block|
        promise.reject(:error)
        promise.on_rejected(&block)
      end.to yield_successive_args(:error)
    end

    it 'does not execute on fullfiled handlers if it has not been fullfiled' do
      expect do |block|
        promise.on_fullfiled(&block)
      end.to_not yield_with_args(:error)
    end

    it 'does not execute on rejected handlers if it has not been rejected' do
      expect do |block|
        promise.on_rejected(&block)
      end.to_not yield_with_args(:error)
    end

    it 'can not be rejected once it has been fulfilled' do
      expect do |block|
        promise.on_fullfiled(&block)
        promise.resolve(:foo)
        promise.on_rejected(&block)
        promise.reject(:error)
      end.to yield_successive_args(:foo)
    end

    it 'can not be fullfiled once it has been rejected' do
      expect do |block|
        promise.on_rejected(&block)
        promise.on_fullfiled(&block)
        promise.reject(:error)
        promise.resolve(:foo)
      end.to yield_successive_args(:error)
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
        }.to yield_successive_args(2, 7)
      end
    end

    describe '#then' do
      it 'adds on fullfiled handlers' do
        expect do |block|
          promise.then(block)
          promise.resolve(:foo)
        end.to yield_with_args(:foo)
      end

      it 'adds on rejected handlers' do
        expect do |block|
          promise.then(nil, block)
          promise.reject(:error)
        end.to yield_with_args(:error)
      end

      it 'does not require both on fullfiled and on rejected handlers' do
        expect do |block|
          promise.then(nil, block)
          promise.then(block)
          promise.reject(:error)
        end.to yield_with_args(:error)
      end

      it 'pipelines the value from on fullfiled to the returned promise' do
        expect do |block|
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
        end.to yield_successive_args(2, 7, 17)
      end

      it 'pipelines the value from on rejected to the returned promise' do
        expect do |block|
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
        end.to yield_successive_args('bar', 'baz', 'zoo')
      end

      it 'rejects the returned promise when on fullfiled throws an exception' do
        promise_b = promise.then(->(value) { fail ArgumentError })

        promise.resolve('foobar')

        expect(promise_b).to be_rejected
        expect(promise_b.reason).to be_an_instance_of(ArgumentError)
      end

      it 'rejects the returned promise when on rejected throws an exception' do
        promise_b = promise
                      .then(->(value) { fail ArgumentError })
                      .then(nil, ->(value) { fail NoMethodError })

        promise.resolve('foobar')

        expect(promise_b).to be_rejected
        expect(promise_b.reason).to be_an_instance_of(NoMethodError)
      end

      it 'fullfills the returned promise with the same value when on fullfiled is not a function' do
        promise_b = promise.then(nil, -> { })

        promise.resolve(:foo)

        expect(promise_b.value).to eq(:foo)
      end

      it 'rejects the returned promise with the same reason when on rejected is not a function' do
        promise_b = promise.then(-> { }, nil)

        promise.reject(:error)

        expect(promise_b.reason).to eq(:error)
      end
    end

    describe 'resolution procedure' do
      it 'throws a TypeError if promise is resolved with itself' do
        expect { promise.resolve(promise) }.to raise_error(TypeError)
      end

      it 'adopts the given promise state when resolved with a promise'do
        promise_a = Promise.new
        promise_b = Promise.new

        expect do |block|
          promise_a.on_fullfiled(&block)
          promise_a.resolve(promise_b)
          promise_b.resolve(:foobar)
        end.to yield_with_args(:foobar)

        promise_a = Promise.new
        promise_b = Promise.new

        expect do |block|
          promise_a.on_rejected(&block)
          promise_a.resolve(promise_b)
          promise_b.reject(:error)
        end.to yield_with_args(:error)
      end

      it 'remains pending until the other promise is resolved' do
        promise_a = Promise.new
        promise_b = Promise.new

        promise_a.resolve(promise_b)
        promise_a.resolve(:foo)

        expect(promise_a).to be_pending
        expect(promise_a.value).to be_nil

        promise_b.resolve(:bar)

        expect(promise_a).to be_resolved
        expect(promise_a.value).to eq(:bar)
      end

      it 'runs the resolution procedure when resolved with a promise and that promise is resolved' do
        promise_b = Promise.new

        promise.resolve(promise_b)

        promise_b.resolve(:foo)

        expect(promise_b.value).to eq(:foo)
        expect(promise.value).to eq(:foo)
      end

      it 'rejects the promise when resolved with a promise and that promise is rejected' do
        promise_b = Promise.new

        promise.resolve(promise_b)

        promise_b.reject(:error)

        expect(promise.reason).to eq(:error)
        expect(promise_b.reason).to eq(:error)

        expect(promise).to be_rejected
        expect(promise_b).to be_rejected
      end

      it 'rejects the promise if calling then throws an exception' do
        promise_b = Promise.new

        allow(promise_b).to receive(:then).and_raise(NoMethodError)

        promise.resolve(promise_b)

        expect(promise).to be_rejected
        expect(promise.reason).to be_an_instance_of(NoMethodError)
      end
    end
  end
end

