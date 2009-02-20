module RubyInlineHaskell
  def haskell(code)
    tokens = code.map(&:strip).
      reject(&:empty?).
      map {|line|
        tokenize_line(line)
      }
    hash = hashize(tokens)
    rubyize(hash)
  end
  private :haskell

  def tokenize_line(line)
    if /::/ =~ line
      name, right = line.split(/\s*::\s*/, 2)
      rights = right.split(/\s*->\s*/).
        map {|i| eval i }
      [name, [:typedef, rights]]
    else
      left, right = line.split(/\s*=\s*/, 2)
      name, *args = left.split(/\s+/)
      case
      when args.empty?
        [name, [:noarg, right]]
      when literal?(args.first)
        [name, [:litarg, eval(args.first), right]]
      else
        [name, [:vararg, args.first.scan(/\w+/), right]]
      end
    end
  end
  private :tokenize_line

  def literal?(arg)
    /^([0-9]+|\[\])$/ =~ arg
  end
  private :literal?

  def hashize(tokens)
    hash = {}
    tokens.map(&:first).uniq.each do |name|
      tmp = {:litarg => {}, :vararg => []}
      tokens.select {|i| i.first == name }.
        each do |_, (type, *vars)|
          case type
          when :typedef
            tmp[:typedef] = vars[0]
          when :litarg
            tmp[:litarg].update(vars[0] => vars[1])
          when :vararg
            tmp[:vararg] = vars[0]
            tmp[:def] = vars[1]
          when :noarg
            tmp[:def] = vars
          end
        end
      hash[name.intern] = tmp
    end
    hash
  end
  private :hashize

  def rubyize(hash)
    tmp = hash.map {|key, value|
      if value[:vararg].empty?
        "  def #{key}\n    #{value[:def]}\n  end"
      else
        inside = ''
        if value[:vararg].size == 2 # FIXME
          inside << "    #{value[:vararg][0]}, *#{value[:vararg][1]} = #{value[:vararg][0]}\n"
        end
        inside << "    case #{value[:vararg].first}\n"
        value[:litarg].each do |k, v|
          inside << "    when #{k.inspect}\n" <<
            "      #{v}\n"
        end
        inside << "    else\n"
        inside << "      #{value[:def]}\n"
        inside << '    end'
        "  def #{key}(#{value[:vararg].first})\n#{inside}\n  end"
      end
    }.join("\n\n")
    return <<-QED # {{{
class #{self}
#{tmp}
end
    QED
    # }}}
  end
  private :rubyize
end

if $0 == __FILE__
  require 'pp'
  class Fib
    extend RubyInlineHaskell
    puts haskell <<-QED # {{{
      fib :: Fixnum -> Fixnum
      fib 0 = 0
      fib 1 = 1
      fib n = fib(n-2) + fib(n-1)

      sum :: [Fixnum] -> Fixnum
      sum [] = 0
      sum (x:xs) = x + sum xs

      zero :: Fixnum
      zero = 0
    QED
    # }}}
  end
end
# vim: foldmethod=marker
