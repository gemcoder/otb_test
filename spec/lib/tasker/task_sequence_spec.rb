require File.expand_path("../../../spec_helper", __FILE__)

def get_dependencies_context_info(data)
  indentation = " " * 10
  info = ""
  info += "configured with task dependencies:\n"
  info += "#{indentation}-----\n"
  data.strip.split("\n").each do |single_line|
    info += (indentation + single_line.strip + "\n")
  end
  info += "#{indentation}-----\n"
end

describe Tasker::TaskSequence do

  subject {Tasker::TaskSequence}

  describe ".new" do

    it "should accept initial configuration" do
      config = "
        a => b
        b => c
      "
      task_sequence = subject.new(config)
      task_sequence.raw_config.should == config
    end

  end

  describe "#sequence" do

    subject {Tasker::TaskSequence}

    examples = [
    # example 0
    "
      a =>
    ",
    # example 1
    "
      a =>
      b =>
      c =>
    ",
    # example 2
    "
      a =>
      b => c
      c =>
    ",
    # example 3
    "
      a =>
      b => c
      c => f
      d => a
      e => b
      f =>
    ",
    # example 4
    "
      a =>
      b =>
      c => c
    ",
    # example 5
    "
      a =>
      b => c
      c => f
      d => a
      e =>
      f => b
    ",
    # example 6
    "
      a =>
      b => c
      c => f
      d => a
      e =>
      f => x
    "
    ]

    context "configured with an empty string" do

      it "should return an empty collection" do
        subject.new("").sequence.should == []
      end

    end

    context get_dependencies_context_info(examples[0]) do
      it "should return a sequence consisting of a single task a" do
        sequence = subject.new(examples[0]).sequence
        sequence.should == ["a"]
      end
    end


    context get_dependencies_context_info(examples[1]) do
      it "should return a sequence containing all three tasks abc in no significant order" do
        sequence = subject.new(examples[1]).sequence
        sequence.length.should == 3
        ( %w{a b c}.all? {|task| sequence.member?(task)} ).should == true
      end
    end

    context get_dependencies_context_info(examples[2]) do
      it "should return a sequence that positions c before b, containing all three tasks abc" do
        sequence = subject.new(examples[2]).sequence
        sequence.length.should == 3
        ( %w{a b c}.all? {|task| sequence.member?(task)} ).should == true
        sequence.index("c").should < sequence.index("b")
      end
    end

    context get_dependencies_context_info(examples[3]) do
      it "should return a sequence that positions f before c, c before b, b before e and a before d containing all six tasks abcdef." do
        sequence = subject.new(examples[3]).sequence
        sequence.length.should == 6
        ( %w{a b c d e f}.all? {|task| sequence.member?(task)} ).should == true

        sequence.index("f").should < sequence.index("c")
        sequence.index("c").should < sequence.index("b")
        sequence.index("b").should < sequence.index("e")
        sequence.index("a").should < sequence.index("d")
      end
    end

    context get_dependencies_context_info(examples[4]) do
      it "should raise an error stating that tasks can't depend on themselves" do
        lambda {
          subject.new(examples[4]).sequence
        }.should raise_error(::Tasker::SelfDependentTaskError)
      end
    end

    context get_dependencies_context_info(examples[5]) do
      it "should raise an error stating that tasks can't have circular dependencies" do
        lambda {
          subject.new(examples[5]).sequence
        }.should raise_error(::Tasker::CircularDependencyError)
      end
    end

    context get_dependencies_context_info(examples[6]) do
      it "should raise an error stating that tasks can't depend on undefined tasks" do
        lambda {
          subject.new(examples[6]).sequence
        }.should raise_error(::Tasker::DependsOnUndefinedTaskError)
      end
    end

  end

  describe "#get_dependency_path" do

    context "when initial config doesn't have any circular dependencies" do

      subject do
        Tasker::TaskSequence.new("
        a =>
        b => c
        c => f
        d => a
        e => b
        f =>
        ")
      end

      context "when asking for a dependency path of a task without any dependency" do
        it "should return an Array with only status value :no_dependencies" do
          subject.get_dependency_path("f").should == [:no_dependencies]
        end
      end

      context "when asking for a dependency path of a task which has a dependency" do
        it "should return an Array with properly ordered dependency names and status value :correct_dependencies at the end" do
          subject.get_dependency_path("e").should == ["b","c","f", :correct_dependencies]
        end
      end

    end

    context "when initial config has some circular dependencies" do

      subject do
        Tasker::TaskSequence.new("
        a =>
        b => c
        c => e
        d => a
        e => f
        f => b
        g =>
        ")
      end

      context "when asking for a dependency path of a task which is a part of circular dependencies" do
        it "should return an Array with properly ordered dependency names and status value :circular_dependencies at the end" do
          subject.get_dependency_path("f").should == ["b", "c", "e", "f", :circular_dependencies]
        end
      end

    end

    context "when initial config has some self dependent tasks" do

      subject do
        Tasker::TaskSequence.new("
        a =>
        b => c
        c => c
        d => b
        e => d
        ")
      end

      context "when asking for a dependency path of a task which is self dependent" do
        it "should return an Array with only status value :self_dependent_task" do
          subject.get_dependency_path("c").should == [:self_dependent_task]
        end
      end

      context "when asking for a dependency path of a task which is dependent on other self dependent tasks" do
        it "should return an Array with properly ordered dependency names and status value :self_dependent_task at the end" do
          subject.get_dependency_path("e").should == ["d", "b", "c", :self_dependent_task]
        end
      end

    end

    context "when initial config has some tasks which depend on other tasks which are not defined in the initial config" do
      subject do
        Tasker::TaskSequence.new("
        a =>
        b => c
        c => x
        d => b
        ")
      end

      context "when asking for a dependency path of a task which has some undefined dependencies" do
        it "should return an Array with properly ordered dependency names and status value :undefined_dependencies" do
          subject.get_dependency_path("d").should == ["b", "c", :undefined_dependencies]
        end
      end

    end

  end

end