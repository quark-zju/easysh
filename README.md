Make shell task easier for ruby script.

Inspired by [sh (for Python)](http://amoffat.github.com/sh/index.html).

Examples
========

Basic usage
-----------

```ruby
sh = EasySH.new

puts sh.ls            # ls
puts sh['/bin/ls']    # /bin/ls
```

Command-line parameters
-----------------------

EasySH automatically convert method names, symbols, hashes to meaningful parameters:

* `_method` will be converted to `-method`
* `__method` will be converted to `--method`
* `:symbol` will be converted to `--symbol`
* `:s` will be converted to `-s`
* `{:a => '1', :long => 2}` will be converted to `-a 1`, `--long=2`
* strings will be left untouched.


```ruby
puts sh.ls('/bin')._l # ls /bin -l
puts sh.ls._l '/bin'  # ls -l /bin
puts sh.ls._l '/bin', color: 'always'
                      # ls /bin -l --color=always
```

EasySH supports method chaining and `[params]`, `method(params)`, just write in any form as you like:

```ruby
puts sh['ls', '-l', :color => :always]
puts sh.ls '/bin', :l, :color => :always
puts sh.ls('/bin')['-l', :color => :always]
puts sh.ls('/bin')._l(:color => :always)
puts sh.ls._l(:color => :always)['/bin']
puts sh.ls('/bin', :color => :always)._l
```

You can save command with parameters to variables for later use:

```ruby
myls = sh.ls._l :color => :always
puts myls['/bin']     # note: myls '/bin' will not work since myls is an object, not an method
```

Commands can also be chained freely:

```ruby
sudo = sh.sudo
puts sudo.whoami

lab = sh.ssh.lab      # or: sh.ssh 'lab', sh.ssh['lab'], sh.ssh('lab')
puts lab.ls._l '/bin' # ssh lab ls -l /bin
```

You can pass an EasySH object as parameter to another EasySH object:

```ruby
cmd = ifconfig.eth0
puts sudo[cmd].up     # sudo ifconfig eth0 up
```

Ruby Enumerable
---------------

EasySH makes full use of Ruby's Enumerable, every EasySH object has `each_line` (`lines`), `each_char` (`chars`), `each_byte` (`bytes`) available like string. `each` is the same as `each_line`.

Use Enumerable for simple or complex tasks:

```ruby
sh.ls.max
sh.ls.sort
sh.ls.chars.to_a.sample(5)
                      # pick 5 chars randomly from `ls`
sh.ps._e._o('euser,comm').map(&:split).group_by(&:first)
                      # group process names by user name
```

EasySH handles endless stream correctly:

```ruby
sh.cat('/dev/urandom').bytes.first(10)
sudo[sh.tail._f '/var/log/everything.log'].lines { |l| puts l.upcase }
```

You can even omit `lines` or `each` sometimes:

```ruby
sudo.tail._f '/var/log/everything.log' do |l| puts l.upcase end
```

By not passing a block, you can use external iterator: (Note: in this case, make sure that the iteration does reach the end, otherwise background processes do not exit)

```ruby
sh.cat < '/tmp/abc' > '/tmp/def'
iter = sh.ls('/sys/fs').lines
iter.next             # 'btrfs'
iter.next             # 'cgroup'
iter.next             # 'ext4'
iter.next             # 'fuse'
iter.next             # StopIteration
```

Redirects
---------

Use `<` or `>` (Note: only one input redirect and one output redirect is supported currently):

```ruby
puts sh.echo('hello') > '/tmp/test'
puts sh.cat < '/tmp/test'
puts sh.cat < '/tmp/abc' > '/tmp/def'

```

You can also associate file descriptor to file directly by using fd numbers => filename Hash (Note: for more information, see Process.spawn. EasySH will distinct Hash parameters from Hash redirects by
checking if the Hash has any numeric key):

```ruby
puts sh.echo 'hello', 1 => '/tmp/stdout', 2 => '/tmp/stderr'
puts sh.cat 0 => '/tmp/test'
```

Pipes
-----

Use `|` (Note: redirects except the rightmost output and leftmost input will be ignored) :

```ruby
puts sh.man('ls') | sh.tail(n: 30) | sh.head(:n, 4)
                      # man ls | tail -n 30 | head -n 4
puts (sh.cat < '/tmp/abc') | sh.cat | sh.cat > '/tmp/def'
                      # cat < /tmp/abc | cat | cat > /tmp/def
```

EasySH objects connected with pipes can be saved for later use:

```ruby
grep   = sh['grep']   # sh.grep does not work because grep is provided by Enumerable
filter = grep['problem'] | grep._v['bugs']
puts sh.man.ls | filter
```

Since EasySH does some lazy evaluation. You can add parentheses in anywhere in any order:

```ruby
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

You may want to put these lines in `.pryrc` or `.irbrc`:

```ruby
require 'easysh'
sh = EasySH.instant
```

Installation
============

```bash
gem install easysh
```


