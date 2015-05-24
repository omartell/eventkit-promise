module Eventkit
  class TaskScheduler
    def schedule_execution(&handler)
      fail NotImplementedError, <<-DOC
Implement #schedule_execution in your class to schedule
the execution of on_fullfiled and on_rejected handlers
DOC
    end
  end
end
