require "nidone/version"
require "digest/md5"

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

      File.binwrite(@path, binary)
    end
  end

  class Loader
    def initialize(cache_path)
      binary = File.binread(cache_path)

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

  module InstructionSequenceMixinUseDumper
    def load_iseq(path)
      if !Nidone.dumper.nil?
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

  module InstructionSequenceMixinWithoutDumper
    def load_iseq(path)
      hash = Digest::MD5.new.update(path)
      cache_path = "#{Nidone.cache_path}/#{hash}"
      bin = File.binread(cache_path) rescue nil
      if bin.nil?
        iseq = RubyVM::InstructionSequence::compile_file(path)
        File.binwrite(cache_path, iseq.to_binary)
        iseq
      else
        RubyVM::InstructionSequence::load_from_binary(bin)
      end
    end
  end

  class << self
    attr_reader :cache_path
    attr_reader :loader
    attr_reader :dumper

    def setup(cache_path: '.cache', use_dumper: true)
      @cache_path = cache_path
      if use_dumper
        @loader = Loader.new(cache_path) rescue nil
        @dumper = Dumper.new(cache_path) if @loader.nil?
      end

      if use_dumper
        class << RubyVM::InstructionSequence
          prepend(InstructionSequenceMixinUseDumper)
        end
      else
        class << RubyVM::InstructionSequence
          prepend(InstructionSequenceMixinWithoutDumper)
        end
      end

      at_exit {
        unless @dumper.nil?
          @dumper.save()
        end
      }
    end
  end
end
