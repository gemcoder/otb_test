module Tasker

  class CircularDependencyError < StandardError
    def initialize(msg = "Tasks can't have circular dependencies")
      super(msg)
    end
  end

  class SelfDependentTaskError < StandardError
    def initialize(msg = "Tasks can't depend on them selves")
      super(msg)
    end
  end

  class DependsOnUndefinedTaskError < StandardError
    def initialize(msg = "Tasks can't depend on undefined tasks")
      super(msg)
    end
  end

  class TaskSequence

    attr_accessor :raw_config
    attr_reader :config_data

    def initialize(config = nil)
      reconfigure_sequence config
    end

    def reconfigure_sequence(config)
      @raw_config = config.to_s
      @config_data = parse_config config.to_s
    end

    def sequence

      task_sequence = get_all_task_names

      @config_data.each do |task_data|
        task_dependency_path = get_dependency_path(task_data[:name])

        raise CircularDependencyError.new if task_dependency_path.last == :circular_dependencies
        raise SelfDependentTaskError.new if task_dependency_path.last == :self_dependent_task
        raise DependsOnUndefinedTaskError.new if task_dependency_path.last == :undefined_dependencies

        task_sequence.delete(task_data[:name])
        dependency_index = task_sequence.index(task_data[:dependency])
        if dependency_index
          task_sequence.insert( dependency_index.to_i , task_data[:name] )
        else
          task_sequence << task_data[:name]
        end

      end

      task_sequence.reverse

    end

    # Returns an Array with all task names
    def get_all_task_names
      @config_data.collect {|el| el[:name] }
    end

    # Returns an Array with a dependency chain of selected task and a status at the end of the Array.
    #
    # Given the following task structure:
    # { "a" => "b", "b" => "d" , "d"=> "f", "f" => "z", "z" => nil }
    #
    # get_dependency_path("b")     #=>   ["d", "f", "z", :correct_dependencies]
    # get_dependency_path("z")     #=>   [:no_dependencies]
    #
    # Given the following task structure:
    # { "a" => "x"}
    #
    # get_dependency_path("z")     #=>   [:undefined_task]
    # get_dependency_path("a")     #=>   [:undefined_dependencies]
    #
    # Given the following task structure:
    # { "a" => "b", "b" => "c", "c" => "c"}
    #
    # get_dependency_path("c")     #=>   [:self_dependent_task]
    # get_dependency_path("a")     #=>   ["b", "c", :self_dependent_task]
    #
    # Given the following task structure:
    # { "a" => "b", "b" => "c", "c" => "a"}
    #
    # get_dependency_path("a")     #=>   ["b", "c", :circular_dependencies]
    #
    # Given the following task structure:
    # { "a" => "b", "b" => "c", "c" => "a"}
    #
    # Possible statuses are:
    # - :correct_dependencies
    # - :no_dependencies
    # - :undefined_task
    # - :undefined_dependencies
    # - :self_dependent_task
    # - :circular_dependencies
    #
    def get_dependency_path(task_name, current_path = [])
      task_data = ( @config_data.select {|el| el[:name] == task_name } ).first
      return [:undefined_task] if current_path == [] && !task_data
      return current_path[0...-1] + [:undefined_dependencies] if task_name.nil? || (!task_name.nil? && !task_data)
      return [:no_dependencies] if current_path == [] && task_data[:dependency] == nil
      return current_path + [:self_dependent_task] if task_data && task_data[:name] == task_data[:dependency]

      if current_path.member?(task_data[:dependency])
        current_path + [:circular_dependencies]
      else
        if task_data[:dependency]
          updated_path = current_path + [task_data[:dependency]]
          get_dependency_path( task_data[:dependency], updated_path )
        else
          current_path + [:correct_dependencies]
        end
      end
    end

    protected

      def parse_config(config)
        tasks = []
        config.strip.split("\n").each do |single_task|
          task_data = parse_config_line(single_task)
          tasks << { name: task_data[0], dependency: task_data[1] }
        end
        tasks
      end

      def parse_config_line(data)
        single_task_data = data.to_s.strip.split("\n").first.to_s.split("=>")
        single_task_data.map! do |element|
          element.strip
        end
      end

  end
end