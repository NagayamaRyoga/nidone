require "nidone/version"

module Nidone
  class Dumper
    def initialize(cache_path)
      @path = cache_path
      @dumper = RubyVM::InstructionSequence::Dumper.new()
      @index_table = {}
    end

    def dump(path, iseq)
      iseq_index = @dumper.dump_iseq(iseq)
      @index_table[path] = iseq_index
    end

    def save()
      index = @dumper.dump_obj(@index_table)
      binary = @dumper.binary(index.to_s)

      File.write(@path, binary)
    end
  end

  module InstructionSequenceMixin
    def load_iseq(path)
      return nil if Nidone.dumper.nil?

      iseq = RubyVM::InstructionSequence::compile_file(path)
      Nidone.dumper.dump(path, iseq)
      iseq
    end
  end

  class << self
    attr_reader :dumper

    def setup(cache_path:)
      @dumper = Dumper.new(cache_path)

      class << RubyVM::InstructionSequence
        prepend(InstructionSequenceMixin)
      end

      at_exit {
        unless @dumper.nil?
          @dumper.save()
        end
      }
    end
  end
end
