module RubyInlineHaskell
  def haskell(code)
    code.map(&:strip).
      reject(&:empty?).
      map {|line|
        tokenize_line(line)
      }
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
end

if $0 == __FILE__
  require 'pp'
  class Fib
    extend RubyInlineHaskell
    pp haskell <<-QED
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
  end
end
