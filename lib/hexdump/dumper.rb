module Hexdump
  class Dumper

    # Widths for formatted numbers
    WIDTHS = {
      :hexadecimal => proc { |word_size| word_size * 2 },
      :decimal => {
        1 => 3,
        2 => 5,
        4 => 10,
        8 => 20
      },
      :octal => {
        1 => 3,
        2 => 6,
        4 => 11,
        8 => 22
      },
      :binary => proc { |word_size| word_size * 8 }
    }

    # Format Strings for the various bases
    FORMATS = {
      :hexadecimal => proc { |width| "%.#{width}x" },
      :decimal => proc { |width| "%#{width}.d" },
      :octal => proc { |width| "%.#{width}o" },
      :binary => proc { |width| "%.#{width}b" }
    }

    UNPRINTABLE = '.'

    # ASCII printable bytes and characters
    PRINTABLE = {
      0x20 => " ",
      0x21 => "!",
      0x22 => "\"",
      0x23 => "#",
      0x24 => "$",
      0x25 => "%",
      0x26 => "&",
      0x27 => "'",
      0x28 => "(",
      0x29 => ")",
      0x2a => "*",
      0x2b => "+",
      0x2c => ",",
      0x2d => "-",
      0x2e => ".",
      0x2f => "/",
      0x30 => "0",
      0x31 => "1",
      0x32 => "2",
      0x33 => "3",
      0x34 => "4",
      0x35 => "5",
      0x36 => "6",
      0x37 => "7",
      0x38 => "8",
      0x39 => "9",
      0x3a => ":",
      0x3b => ";",
      0x3c => "<",
      0x3d => "=",
      0x3e => ">",
      0x3f => "?",
      0x40 => "@",
      0x41 => "A",
      0x42 => "B",
      0x43 => "C",
      0x44 => "D",
      0x45 => "E",
      0x46 => "F",
      0x47 => "G",
      0x48 => "H",
      0x49 => "I",
      0x4a => "J",
      0x4b => "K",
      0x4c => "L",
      0x4d => "M",
      0x4e => "N",
      0x4f => "O",
      0x50 => "P",
      0x51 => "Q",
      0x52 => "R",
      0x53 => "S",
      0x54 => "T",
      0x55 => "U",
      0x56 => "V",
      0x57 => "W",
      0x58 => "X",
      0x59 => "Y",
      0x5a => "Z",
      0x5b => "[",
      0x5c => "\\",
      0x5d => "]",
      0x5e => "^",
      0x5f => "_",
      0x60 => "`",
      0x61 => "a",
      0x62 => "b",
      0x63 => "c",
      0x64 => "d",
      0x65 => "e",
      0x66 => "f",
      0x67 => "g",
      0x68 => "h",
      0x69 => "i",
      0x6a => "j",
      0x6b => "k",
      0x6c => "l",
      0x6d => "m",
      0x6e => "n",
      0x6f => "o",
      0x70 => "p",
      0x71 => "q",
      0x72 => "r",
      0x73 => "s",
      0x74 => "t",
      0x75 => "u",
      0x76 => "v",
      0x77 => "w",
      0x78 => "x",
      0x79 => "y",
      0x7a => "z",
      0x7b => "{",
      0x7c => "|",
      0x7d => "}",
      0x7e => "~"
    }

    PRINTABLE.default = UNPRINTABLE

    #
    # Creates a new Hexdump dumper.
    #
    # @param [Hash] options
    #   Additional options.
    #
    # @option options [Integer] :width (16)
    #   The number of bytes to dump for each line.
    #
    # @option options [Integer] :word_size (1)
    #   The number of bytes within a word.
    #
    # @option options [Symbol, Integer] :base (:hexadecimal)
    #   The base to print bytes in. Supported bases include, `:hexadecimal`,
    #   `:hex`, `16, `:decimal`, `:dec`, `10, `:octal`, `:oct`, `8`,
    #   `:binary`, `:bin` and `2`.
    #
    # @option options [Boolean] :ascii (false)
    #   Print ascii characters when possible.
    #
    # @raise [ArgumentError]
    #   The `:base` value was unknown.
    #
    def initialize(options={})
      @base = case options[:base]
              when :hexadecimal, :hex, 16
                :hexadecimal
              when :decimal, :dec, 10
                :decimal
              when :octal, :oct, 8
                :octal
              when :binary, :bin, 2
                :binary
              when nil
                :hexadecimal
              else
                raise(ArgumentError,"unknown base #{options[:base].inspect}")
              end

      @word_size = options.fetch(:word_size,1)
      @endian = options.fetch(:endian,:little)
      @width = (options.fetch(:width,16) / @word_size)
      @ascii = options.fetch(:ascii,false)

      @format_width = (WIDTHS[@base][@word_size] || 1)
      @format = FORMATS[@base][@format_width]

      if @word_size == 1
        @format_cache = Hash.new do |hash,key|
          hash[key] = sprintf(@format,key)
        end
      end
    end
    
    #
    # Iterates over every word within the data.
    #
    # @param [#each_byte] data
    #   The data containing bytes.
    #
    # @yield [word]
    #   The given block will be passed each word within the data.
    #
    # @yieldparam [Integer]
    #   An unpacked word from the data.
    #
    # @return [Enumerator]
    #   If no block is given, an Enumerator will be returned.
    #
    # @raise [ArgumentError]
    #   The given data does not define the `#each_byte` method.
    #
    # @since 0.2.0
    #
    def each_word(data,&block)
      return enum_for(:each_word,data) unless block

      unless data.respond_to?(:each_byte)
        raise(ArgumentError,"the data to hexdump must define #each_byte")
      end

      if @word_size > 1
        word = 0
        count = 0

        init_shift = if @endian == :big
                       ((@word_size - 1) * 8)
                     else
                       0
                     end
        shift = init_shift

        data.each_byte do |b|
          word |= (b << shift)

          if @endian == :big
            shift -= 8
          else
            shift += 8
          end

          count += 1

          if count >= @word_size
            yield word

            word = 0
            count = 0
            shift = init_shift
          end
        end

        # yield the remaining word
        yield word if count > 0
      else
        data.each_byte(&block)
      end
    end

    #
    # Iterates over the hexdump.
    #
    # @param [#each_byte] data
    #   The data to be hexdumped.
    #
    # @yield [index,hex_segment,print_segment]
    #   The given block will be passed the hexdump break-down of each segment.
    #
    # @yieldparam [Integer] index
    #   The index of the hexdumped segment.
    #
    # @yieldparam [Array<String>] hex_segment
    #   The hexadecimal-byte representation of the segment.
    #
    # @yieldparam [Array<String>] print_segment
    #   The print-character representation of the segment.
    #
    # @return [nil]
    #
    def each(data)
      index = 0
      count = 0

      numeric_buffer = []
      char_buffer = []

      each_word(data) do |word|
        numeric_buffer << format_numeric(word)
        char_buffer << format_char(word)

        count += 1

        if count >= @width
          yield(index,numeric_buffer,char_buffer)

          numeric_buffer.clear
          char_buffer.clear

          index += (@width * @word_size)
          count = 0
        end
      end

      if count > 0
        # yield the remaining data
        yield(index,numeric_buffer,char_buffer)
      end
    end

    #
    # Prints the hexdump.
    #
    # @param [#each_byte] data
    #   The data to be hexdumped.
    #
    # @param [#<<] output
    #   The output to print the hexdump to.
    #
    # @return [nil]
    #
    # @raise [ArgumentError]
    #   The `:output` value does not support the `#<<` method.
    #
    def print(data,output=STDOUT)
      unless output.respond_to?(:<<)
        raise(ArgumentError,"output must support the #<< method")
      end

      bytes_segment_width = ((@width * @format_width) + (@width - 1))
      line_format = "%.8x  %-#{bytes_segment_width}s |%s|\n"

      index = 0
      count = 0

      numeric_buffer = ''
      char_buffer = ''

      each_word(data) do |word|
        numeric_buffer << format_numeric(word) << ' '
        char_buffer << format_char(word)

        count += 1

        if count >= @width
          output << sprintf(line_format,index,numeric_buffer,char_buffer)

          numeric_buffer = ''
          char_buffer = ''

          index += (@width * @word_size)
          count = 0
        end
      end

      if count > 0
        # output the remaining line
        output << sprintf(line_format,index,numeric_buffer,char_buffer)
      end
    end

    protected

    def format_numeric(word)
      if @word_size == 1
        if (@ascii && (word >= 0x20 && word <= 0x7e))
          PRINTABLE[word]
        else
          @format_cache[word]
        end
      else
        sprintf(@format,word)
      end
    end

    def format_char(word)
      if @word_size == 1
        PRINTABLE[word]
      elsif RUBY_VERSION > '1.9.'
        word.chr(Encoding::UTF_8)
      else
        UNPRINTABLE
      end
    end

  end
end
