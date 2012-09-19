# EasySH Examples
# 
# Basic usage:
# 
#   require 'easysh'
#   sh = EasySH.instant;
#   
#   sh.ls            # ls
#   sh['/bin/ls']    # /bin/ls
# 
# EasySH automatically convert method names, symbols, hashes to meaningful parameters:
# 
# * `_method` will be converted to `-method`
# * `__method` will be converted to `--method`
# * `:symbol` will be converted to `--symbol`
# * `:s` will be converted to `-s`
# * `{:a => '1', :long => 2}` will be converted to `-a 1`, `--long=2`
# * strings will be left untouched.
#
# Examples:
# 
#   sh.ls('/bin')._l                 # ls /bin -l
#   sh.ls._l '/bin'                  # ls -l /bin
#   sh.ls._l '/bin', color: 'always' # ls /bin -l --color=always
# 
# EasySH supports method chaining and `[params]`, `method(params)`, just write in any form as you like:
# 
#   sh['ls', '-l', :color => :always]
#   sh.ls '/bin', :l, :color => :always
#   sh.ls('/bin')['-l', :color => :always]
#   sh.ls('/bin')._l(:color => :always)
#   sh.ls._l(:color => :always)['/bin']
#   sh.ls('/bin', :color => :always)._l
# 
# You can save command with parameters to variables for later use:
# 
#   myls = sh.ls._l :color => :always;
#   myls['/bin']  # note: myls '/bin' will not work since myls is an object, not a method
# 
# Commands can also be chained freely:
# 
#   sudo = sh.sudo;
#   sudo.whoami
#   
#   lab = sh.ssh.lab;      # or: sh.ssh 'lab', sh.ssh['lab'], sh.ssh('lab')
#   lab.ls._l '/bin'       # ssh lab ls -l /bin
# 
# You can pass arrays or EasySH objects(without pipes) as arguments to another EasySH object:
# 
#   cmd    = sh.ifconfig.eth0;
#   opt    = ['mtu', 1440]
#   sudo[cmd].up           # sudo ifconfig eth0 up
#   sudo[cmd, opt].up      # sudo ifconfig eth0 up mtu 1440
#   # sudo[cmd | sh.cat]   # Error: EasySH objects with pipes are not allowed here.
# 
# EasySH makes full use of Ruby's Enumerable. `each_line` (`lines`), `each_char` (`chars`), `each_byte` (`bytes`) are available like string. For convenience, `each` is an alias of `each_line`.
# 
# Use Enumerable for simple or complex tasks:
# 
#   sh.ls.max
#   sh.ls.sort
#   sh.ls.chars.to_a.sample(5)                               # pick 5 chars randomly from `ls` output
#   sh.ps._e._o('euser,comm').map(&:split).group_by(&:first) # group process names by user name
# 
# EasySH handles endless stream correctly:
# 
#   sh.cat('/dev/urandom').bytes.first(10)
#   sudo[sh.tail._f '/var/log/everything.log'].lines { |l| puts l.upcase }
# 
# You can even omit `lines` or `each` sometimes:
# 
#   sh.cat { |l| puts l.upcase }
#   sudo.tail._f '/var/log/everything.log' do |l| puts l.upcase end
# 
# By not passing a block, you can use external iterator: (Note: in this case, make sure that the iteration does reach the end, otherwise background processes do not exit)
# 
#   iter = sh.ls('/sys/fs').lines
#   iter.next             # 'btrfs'
#   iter.next             # 'cgroup'
#   iter.next             # 'ext4'
#   iter.next             # 'fuse'
#   iter.next             # StopIteration
# 
# Redirects
# ---------
# 
# Use `<` or `>` (Note: only one input redirect and one output redirect is supported currently):
# 
#   sh.echo('hello') > '/tmp/test'
#   sh.cat < '/tmp/test'
#   sh.cat < '/tmp/abc' > '/tmp/def'
# 
# You can also associate file descriptor to file directly by using fd numbers => filename Hash (Note: for more information, see Process.spawn. EasySH will distinct Hash parameters from Hash redirects by
# checking if the Hash has any numeric key):
# 
#   sh.echo 'hello', 1 => '/tmp/stdout', 2 => '/tmp/stderr'
#   sh.cat 0 => '/tmp/test'
# 
# Pipes
# -----
# 
# Use `|` (Note: redirects except the rightmost output and leftmost input will be ignored):
# 
#   (sh.cat | sh.head(n: 5)).each { |l| puts l.upcase }
#   sh.man('ls') | sh.tail(n: 30) | sh.head(:n, 4)       # man ls | tail -n 30 | head -n 4
#   (sh.cat < '/tmp/abc') | sh.cat | sh.cat > '/tmp/def' # cat < /tmp/abc | cat | cat > /tmp/def
# 
# EasySH objects connected with pipes can be saved for later use:
# 
#   grep   = sh['grep'];   # sh.grep does not work because grep is provided by Enumerable
#   filter = grep['problem'] | grep._v['bugs'];
#   sh.man.ls | filter
# 
# Since EasySH does some lazy evaluation. You can add parentheses in anywhere in any order:
# 
#   kat = sh.cat;
#   kat['/tmp/foo'] | (kat | (kat | (kat | kat)) | (kat | kat) | (kat | kat))
# 
# Exit status
# -----------
# 
# Use `exitcode` or `to_i` to get exitcode directly:
# 
#   sh.true.exitcode   # => 0
#   sh.false.to_i      # => 1
# 
# `successful?` is `exitcode == 0` and `failed?` is `exitcode != 0`:
# 
#   grep = sh['grep', :q];
#   (sh.echo.hello | grep['world']).failed?     # => true
#   (sh.echo.world | grep['world']).successful? # => true
# 
# Use `status` method to get a Process::Status object about last run status:
# 
#   p = sh.which('bash')
#   p.status        # => #<Process::Status: pid 5931 exit 0>
#   p = sh.which.nonexists
#   p.status        # => #<Process::Status: pid 6156 exit 1>
# 
# More sugars
# -----------
# 
# An EasySH object behaves like an Array or a String sometimes.
# 
# If you pass arguments like: `[int]`, `[int, int]`, `[range]`; `[regex]`, `[regex, int]`, then `to_a` or `to_s` will be automatically called:
# 
#   # like Array
#   sh.echo("Line 1\nLine 2\nLine 3")[1]    # => "Line 2"
#   sh.echo("Line 1\nLine 2\nLine 3")[-1]   # => "Line 3"
#   sh.echo("Line 1\nLine 2\nLine 3")[0, 2] # => ["Line 1", "Line 2"]
#   sh.echo("Line 1\nLine 2\nLine 3")[1..2] # => ["Line 2", "Line 3"]
#   
#   # like String
#   sh.echo("Hello world\nThis is a test")[/T.*$/]            # => "This is a test"
#   sh.echo("Hello world\nThis is a test")[/T.* ([^ ]*)$/, 1] # => "test"
# 
# Instant mode
# ------------
# EasySH object with `instant = true` will execute command when `inspect` is called, which is useful in REPL environment like pry or irb.
# 
# If you like traditional `inspect` behavior, you can create the `sh` object using:
# 
#   sh = EasySH.new
# 
# or set `instant` to false:
# 
#   sh.instant = false
# 
# With `instant = false`, you need additional `to_s` or `to_a` or `to_i` etc. to get command executed:
# 
#   [1] pry(main)> sh = EasySH.new; sh.uname
#   => #<EasySH: uname>
#   [2] pry(main)> sh.uname.to_s
#   => "Linux"
#
class EasySH < Struct.new(:cmd, :opt, :chain, :instant) # :no-doc:
  include Enumerable

  attr_reader   :status

  def method_missing name, *args, &block # :no-doc:
    begin
      return super(name, *args, &block)
    rescue NoMethodError, ArgumentError => ex
      # continue
    end

    args = [name, *args]
    *args, opt = *args if args.last.is_a?(Hash) && args.last.keys.find{|k| k.is_a? Integer}
    opt ||= {}
    args = args.map.with_index do |a, i|
      case a
      when Symbol
        if i == 0
          a.to_s.gsub(/^_+/) {|s| '-' * s.size}
        else
          "-#{a.length > 1 ? '-' : ''}#{a}"
        end
      when Hash
        a.map { |k,v| k.length > 1 ? "--#{k}=#{v}" : ["-#{k}", v.to_s] }
      when EasySH
        # no Pipe allowed
        raise ArgumentError.new("#{self.class} argument can not be #{self.class} with pipes") if a.chain && !a.chain.empty?
        opt = Hash[[*opt, *a.opt]]
        a.cmd
      when NilClass
        nil
      when Array
        a
      else
        a.to_s
      end
    end.compact.flatten

    r = self.class.new [*cmd, *args], Hash[[*self.opt, *opt]], chain, instant
    block ? r.each(&block) : r
  end

  def to_a;           each.to_a; end
  def to_s(n = "\n"); cmd ? to_a.join(n) : ''; end

  def inspect
    if instant
      s = to_s
      s.empty? ? nil : s
    else
      "#<#{self.class}: #{([*chain, [cmd]]).map(&:first).map {|c| c && c.join(' ')}.compact.join(' | ')}>"
    end
  end

  def |(sh, &block)
    raise TypeError.new("EasySH expected, got #{sh.inspect}") unless sh.is_a? EasySH
    self.class.new sh.cmd, sh.opt, [*chain, cmd && [cmd, opt || {}], *sh.chain].compact, instant
  end

  def < path; self.opt ||= {}; self.opt[0] = path; self; end
  def > path; self.opt ||= {}; self.opt[1] = path; self; end

  def to_io
    return unless cmd

    cur_opt    = opt.clone
    cur_chain  = (chain || []) + [[cmd, cur_opt]]
    pipes      = cur_chain.map { IO.pipe }
    n          = pipes.size
    cur_opt[0] = pipes[n-1][0] if n > 1
    lpid, lopt = nil
    pids       = []

    begin
      cur_chain.reverse.each_with_index do |cmd_opt, i|
        i      = n - 1 - i
        c, o   = *cmd_opt
        o      = o.clone
        o[1]   = nil           if i < n - 1
        o[1] ||= pipes[i][1]
        o[0]   = pipes[i-1][0] if i > 0
        pid = spawn(*c, o)
        pids << pid
        lopt, lpid = o, pid    if i == n - 1
      end

      if lopt[1] == pipes[n-1][1]
        rfd = pipes[n-1][0]
        (pipes.flatten-[rfd]).each { |io| io.close unless io.closed?  }
        yield rfd
      end
    ensure
      pipes.flatten.each { |io| io.close unless io.closed? }
      @status = Process.wait2(lpid)[-1] rescue nil
      ['TERM', 'KILL'].each { |sig| Process.kill sig, *pids rescue nil }
      Process.waitall rescue nil
    end
  end

  def each_line
    return to_enum(:each_line) unless block_given?
    to_io { |i| while l = i.gets; yield l.chomp; end }
  end

  def each_char
    return to_enum(:each_char) unless block_given?
    to_io { |i| while c = i.getc; yield c; end }
  end

  def each_byte
    return to_enum(:each_byte) unless block_given?
    to_io { |i| while b = i.getbyte; yield b; end }
  end

  def [] i, *args
    case i
    when Integer
      return to_a[i] if args.empty?
      return to_a[i, *args] if args.size == 1 && args[0].is_a?(Integer)
    when Range
      return to_a[i] if args.empty?
    when Regexp
      return to_s[i, *args]
    end
    method_missing nil, i, *args
  end

  def to_i
    to_s if status.nil?
    (status && status.exitstatus) || 0
  end

  def successful? 
    to_i == 0
  end

  def failed?
    ! successful?
  end

  def to_ary
    [*cmd]
  end

  alias :call        :method_missing
  alias :lines       :each_line
  alias :each        :each_line
  alias :lines       :each_line
  alias :chars       :each_char
  alias :bytes       :each_byte
  alias :read        :to_s
  alias :!           :to_s
  alias :exitstatus  :status
  alias :exitcode    :to_i

  def pretty_print(q)
    q.text self.inspect
  end

  def self.instant
    new(nil, {}, [], true)
  end
end

