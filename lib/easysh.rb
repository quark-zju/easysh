# EasySH examples:
# 
#  sh = EasySH.new
#
#  # basic usage
#  puts sh.ls
#  puts sh['/bin/ls']
#
#  # command parameters
#  puts sh.ls['/bin']._l
#  puts sh.ls._l '/bin'
#  puts sh.ls('/bin', :l, :color => :always)
#  puts sh['/bin/ls', '-l', :color => :always]
#
#  # enumerable
#  sh.ls.max
#  sh.ls.sort
#  sh.ls.chars.to_a.sample(5)
#  sh.cat('/dev/urandom').bytes.first(10)
#  sh.ps._e._o('euser,comm').map(&:split).group_by(&:first)
#  
#  # chaining commands
#  sudo = sh.sudo
#  tail = sh.tail
#  sudo[tail._f '/var/log/everything.log'].lines { |l| puts l.upcase }
#  sudo.tail._f '/var/log/everything.log' do |l| puts l.upcase end
#
#  lab = sh.ssh['lab'] # or, sh.ssh.lab
#  puts lab.ls._l '/bin', color: :always
#  
#  # redirects
#  puts sh.echo('hello') > '/tmp/test'
#  puts sh.echo 'hello', 1 => '/tmp/stdout', 2 => '/tmp/stderr'
#  puts sh.cat < '/tmp/test'
#  puts sh.cat 0 => '/tmp/fffff'
#
#  # pipes
#  puts sh.man('ls') | sh.tail(n: 30) | sh.head(:n, 4)
#
#  grep   = sh['grep']
#  filter = grep['problem'] | grep._v['bugs']
#  puts sh.man.ls | filter
#
#  kat = sh.cat
#  puts kat['/tmp/foo'] | (kat | kat | kat.|(kat) | (kat | kat) | (kat | kat))
#
#  # exit status
#  p = sh.which('bash')
#  puts p
#  p.status        # => #<Process::Status: pid 5931 exit 0>
#  p = sh.which.nonexists
#  puts p
#  p.status        # => #<Process::Status: pid 6156 exit 1>
#
#
#  # instant mode
#  # tired with 'puts' and 'to_s' in REPL? just set instant = true
#  # [2] pry(main)> sh.instant = false; sh.uptime
#  # => #<EasySH: uptime>
#  # [3] pry(main)> sh.instant = true; sh.uptime
#  # =>  22:14:23 up 1 day,  4:02, 12 users,  load average: 0.69, 0.65, 0.67
#  # [4] pry(main)> sh = EasySH.instant; sh.uname
#  # =>  Linux
# 
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

    r = if name.is_a? EasySH
          self.class.new [*cmd, *name.cmd], Hash[*opt, *name.opt], chain, instant
        else
          args = [name && name.to_s.gsub(/^_+/) {|s| '-' * s.size}, *args].compact
          *args, opt = *args if args.last.is_a?(Hash) && args.last.keys.find{|k| k.is_a? Integer}
          args = args.map do |a|
            case a
            when Symbol
              "-#{a.length > 1 ? '-' : ''}#{a}"
            when Hash
              a.map { |k,v| k.length > 1 ? "--#{k}=#{v}" : ["-#{k}", v.to_s] }
            else
              a.to_s
            end
          end.flatten
          self.class.new [*cmd, *args], Hash[[*self.opt, *opt]], chain, instant
        end
    block ? r.each(&block) : r
  end

  def to_a;           each.to_a; end
  def to_s(n = "\n"); cmd ? to_a.join(n) : ''; end

  def inspect
    instant ? to_s : "#<#{self.class}: #{([*chain, [cmd]]).map(&:first).map {|c| c && c.join(' ')}.compact.join(' | ')}>"
  end

  def |(sh, &block)
    raise TypeError.new("EasySH expected, got #{sh.inspect}") unless sh.is_a? EasySH
    self.class.new sh.cmd, sh.opt, [*chain, cmd && [cmd, opt || {}], *sh.chain].compact, instant
  end

  def < path; self.opt[0] = path; self; end
  def > path; self.opt[1] = path; self; end

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

  alias :call        :method_missing
  alias :to_ary      :to_a
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

