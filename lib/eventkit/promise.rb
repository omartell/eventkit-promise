module Eventkit
  class Promise
    VERSION = '1.0'
    attr_reader :value, :task_scheduler
    private :value

    def initialize(task_scheduler)
      @on_fullfiled = []
      @on_rejected  = []
      @state = :pending
      @task_scheduler = task_scheduler
      @resolved_with_promise = false
      yield self if block_given?
    end

    def pending?
      @state == :pending
    end

    def resolved?
      @state == :resolved
    end

    def rejected?
      @state == :rejected
    end

    def then(on_fullfiled_handler = nil, on_rejected_handler = nil)
      promise = Promise.new(task_scheduler)

      add_on_fullfiled { |value|
        begin
          if on_fullfiled_handler
            promise.resolve(on_fullfiled_handler.to_proc.call(value))
          else
            promise.resolve(value)
          end
        rescue => error
          promise.reject(error)
        end
      }

      add_on_rejected { |value|
        begin
          if on_rejected_handler
            promise.resolve(on_rejected_handler.to_proc.call(value))
          else
            promise.reject(value)
          end
        rescue => error
          promise.reject(error)
        end
      }

      promise
    end

    def resolve(value)
      fail TypeError, 'Promised resolved with itself' if self == value

      return unless pending? && !@resolved_with_promise

      run_resolution(value)
      self
    end

    def reject(value)
      return unless pending? && !@resolved_with_promise

      run_rejection(value)
      self
    end

    def on_fullfiled(&handler)
      self.then(handler)
    end

    def on_rejected(&handler)
      self.then(nil, handler)
    end

    def catch(&handler)
      self.then(nil, handler)
    end

    private

    def add_on_fullfiled(&handler)
      if resolved?
        schedule_execution(handler)
      else
        @on_fullfiled << handler
      end
    end

    def add_on_rejected(&handler)
      if rejected?
        schedule_execution(handler)
      else
        @on_rejected << handler
      end
    end

    def run_resolution(value)
      if value.respond_to?(:then)
        begin
          value.then(->(v) { run_resolution(v) },
                     ->(v) { run_rejection(v) })
          @resolved_with_promise = true
        rescue => e
          reject(e)
        end
      else
        @state = :resolved
        @value = value
        @on_fullfiled.each(&method(:schedule_execution))
      end
    end

    def run_rejection(value)
      @value = value
      @on_rejected.each(&method(:schedule_execution))
      @state = :rejected
    end

    def schedule_execution(handler)
      task_scheduler.schedule_execution { handler.call(value) }
    end
  end
end
