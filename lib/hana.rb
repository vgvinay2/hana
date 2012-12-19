module Hana
  VERSION = '1.0.1'

  class Pointer
    include Enumerable

    def initialize path
      @path = Pointer.parse path
    end

    def each
      @path.each { |x| yield x }
    end

    def to_a; @path.dup; end

    def eval object
      Pointer.eval @path, object
    end

    def self.eval list, object
      list.inject(object) { |o, part| o[(Array === o ? part.to_i : part)] }
    end

    def self.parse path
      return [''] if path == '/'

      path.sub(/^\//, '').split(/(?<!\^)\//).map { |part|
        part.gsub!(/\^([\/^])/, '\1')
        part.gsub!(/~1/, '/')
        part.gsub!(/~0/, '~')
        part
      }
    end

    def self.parse2 path
      path.sub(/^\//, '').split(/(?<!\^)\//)
    end
  end

  class Patch
    class Exception < StandardError
    end

    class FailedTestException < Exception
      attr_accessor :path, :value

      def initialize path, value
        super "expected #{value} at #{path}"
        @path  = path
        @value = value
      end
    end

    class OutOfBoundsException < Exception
    end

    class ObjectOperationOnArrayException < Exception
    end

    def initialize is
      @is = is
    end

    VALID = Hash[%w{ add move test replace remove copy }.map { |x| [x,x]}] # :nodoc:

    def apply doc
      @is.each_with_object(doc) { |ins, d|
        send VALID.fetch(ins['op'].strip) { |k|
          raise Exception, "bad method `#{k}`"
        }, ins, d
      }
    end

    private

    def copy ins, doc
      raise NotImplementedError
    end

    def add ins, doc
      list = Pointer.parse ins['path']
      key  = list.pop
      dest = Pointer.eval list, doc
      obj  = ins['value']

      add_op dest, key, obj
    end

    def move ins, doc
      from     = Pointer.parse ins['path']
      to       = Pointer.parse ins['to']
      from_key = from.pop
      key      = to.pop

      src  = Pointer.eval(from, doc)

      if Array === src
        obj = src.delete_at from_key.to_i
      else
        obj = src.delete from_key
      end

      dest = Pointer.eval(to, doc)
      add_op dest, key, obj
    end

    def test ins, doc
      expected = Pointer.new(ins['path']).eval doc

      unless expected == ins['value']
        raise FailedTestException.new(ins['value'], ins['path'])
      end
    end

    def replace ins, doc
      list = Pointer.parse ins['path']
      key  = list.pop
      obj  = Pointer.eval list, doc

      if Array === obj
        obj[key.to_i] = ins['value']
      else
        obj[key] = ins['value']
      end
    end

    def remove ins, doc
      list = Pointer.parse ins['path']
      key  = list.pop
      obj  = Pointer.eval list, doc

      if Array === obj
        obj.delete_at key.to_i
      else
        obj.delete key
      end
    end

    def check_index obj, key
      raise ObjectOperationOnArrayException unless key =~ /\A-?\d+\Z/
      idx = key.to_i
      raise OutOfBoundsException if idx > obj.length || idx < 0
      idx
    end

    def add_op dest, key, obj
      if Array === dest
        dest.insert check_index(dest, key), obj
      else
        dest[key] = obj
      end
    end
  end
end
