Make shell task easier for ruby script.

Examples
========

Basic usage
-----------

```ruby
sh = EasySH.new

puts sh.ls
puts sh['/bin/ls']
```

Command-line parameters
-----------------------

```ruby
puts sh.ls['/bin']._l
puts sh.ls._l '/bin'
puts sh.ls('/bin', :l, :color => :always)
puts sh['/bin/ls', '-l', :color => :always]
```

Ruby Enumerable
---------------

```ruby
sh.ls.max
sh.ls.sort
sh.ls.chars.to_a.sample(5)
sh.cat('/dev/urandom').bytes.first(10)
sh.ls._l.map{|l| l.split}
sh.ps._e._o('euser,comm').map(&:split).group_by(&:first)
```

Chaining command and parameters
-------------------------------

```ruby
sudo = sh.sudo
tail = sh.tail
sudo[tail._f '/var/log/everything.log'].lines { |l| puts l.upcase }
sudo.tail._f '/var/log/everything.log' do |l| puts l.upcase end

lab = sh.ssh['lab'] # or, sh.ssh.lab
puts lab.ls._l '/bin', color: :always
```

Redirects
---------

```ruby
puts sh.echo('hello') > '/tmp/test'
puts sh.echo 'hello', 1 => '/tmp/stdout', 2 => '/tmp/stderr'
puts sh.cat < '/tmp/test'
puts sh.cat 0 => '/tmp/fffff'
```

Pipes
-----

```ruby
puts sh.man('ls') | sh.tail(n: 30) | sh.head(:n, 4)

grep   = sh['grep']
filter = grep['problem'] | grep._v['bugs']
puts sh.man.ls | filter

kat = sh.cat
puts kat['/tmp/foo'] | (kat | kat | kat.|(kat) | (kat | kat) | (kat | kat))
```

Exit status
-----------
```ruby
p = sh.which('bash')
puts p
p.exitstatus        # => #<Process::Status: pid 5931 exit 0>
p = sh.which.nonexists
puts p
p.exitstatus        # => #<Process::Status: pid 6156 exit 1>
```


Instant mode
------------
Tired with `puts` and `to_s` in REPL? Then set `instant = true`

```
[2] pry(main)> sh.instant = false; sh.uptime
=> #<EasySH: uptime>
[3] pry(main)> sh.instant = true; sh.uptime
=>  22:14:23 up 1 day,  4:02, 12 users,  load average: 0.69, 0.65, 0.67
[4] pry(main)> sh = EasySH.instant; sh.uname
=>  Linux
```

Installation
============

```bash
gem install easysh
```


