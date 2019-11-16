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

  class Loader
    def initialize(cache_path)
      binary = File.read(cache_path)

      @loader = RubyVM::InstructionSequence::Loader.new(binary)
      extra = @loader.extra_data()

      @index_table = @loader.load_obj(extra.to_i)
    end

    def load(path)
      index = @index_table[path]
      return nil if index.nil?

      @loader.load_iseq(index)
    end
  end

  module InstructionSequenceMixin
    def load_iseq(path)
      if Nidone.loader.nil?
        # dump mode
        iseq = RubyVM::InstructionSequence::compile_file(path)
        Nidone.dumper.dump(path, iseq)
        iseq
      elsif
        # load mode
        Nidone.loader.load(path)
      end
    end
  end

  class << self
    attr_reader :loader
    attr_reader :dumper

    def setup(cache_path:)
      @loader = Loader.new(cache_path) rescue nil
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
