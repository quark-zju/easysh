Make shell task easier for ruby script.

Inspired by [sh (for Python)](http://amoffat.github.com/sh/index.html).

Examples
========

Basic usage
-----------

```ruby
require 'easysh'
sh = EasySH.instant;

sh.ls            # ls
sh['/bin/ls']    # /bin/ls
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
sh.ls('/bin')._l                 # ls /bin -l
sh.ls._l '/bin'                  # ls -l /bin
sh.ls._l '/bin', color: 'always' # ls /bin -l --color=always
```

EasySH supports method chaining and `[params]`, `method(params)`, just write in any form as you like:

```ruby
sh['ls', '-l', :color => :always]
sh.ls '/bin', :l, :color => :always
sh.ls('/bin')['-l', :color => :always]
sh.ls('/bin')._l(:color => :always)
sh.ls._l(:color => :always)['/bin']
sh.ls('/bin', :color => :always)._l
```

You can save command with parameters to variables for later use:

```ruby
myls = sh.ls._l :color => :always;
myls['/bin']  # note: myls '/bin' will not work since myls is an object, not a method
```

Commands can also be chained freely:

```ruby
sudo = sh.sudo;
sudo.whoami

lab = sh.ssh.lab;      # or: sh.ssh 'lab', sh.ssh['lab'], sh.ssh('lab')
lab.ls._l '/bin'       # ssh lab ls -l /bin
```

You can pass arrays or EasySH objects(without pipes) as arguments to another EasySH object:

```ruby
cmd    = sh.ifconfig.eth0;
opt    = ['mtu', 1440]
sudo[cmd].up           # sudo ifconfig eth0 up
sudo[cmd, opt].up      # sudo ifconfig eth0 up mtu 1440
# sudo[cmd | sh.cat]   # Error: EasySH objects with pipes are not allowed here.
```

Ruby Enumerable
---------------

EasySH makes full use of Ruby's Enumerable. `each_line` (`lines`), `each_char` (`chars`), `each_byte` (`bytes`) are available like string. For convenience, `each` is an alias of `each_line`.

Use Enumerable for simple or complex tasks:

```ruby
sh.ls.max
sh.ls.sort
sh.ls.chars.to_a.sample(5)                               # pick 5 chars randomly from `ls` output
sh.ps._e._o('euser,comm').map(&:split).group_by(&:first) # group process names by user name
```

EasySH handles endless stream correctly:

```ruby
sh.cat('/dev/urandom').bytes.first(10)
sudo[sh.tail._f '/var/log/everything.log'].lines { |l| puts l.upcase }
```

You can even omit `lines` or `each` sometimes:

```ruby
sh.cat { |l| puts l.upcase }
sudo.tail._f '/var/log/everything.log' do |l| puts l.upcase end
```

By not passing a block, you can use external iterator: (Note: in this case, make sure that the iteration does reach the end, otherwise background processes do not exit)

```ruby
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
sh.echo('hello') > '/tmp/test'
sh.cat < '/tmp/test'
sh.cat < '/tmp/abc' > '/tmp/def'
```

You can also associate file descriptor to file directly by using fd numbers => filename Hash (Note: for more information, see Process.spawn. EasySH will distinct Hash parameters from Hash redirects by
checking if the Hash has any numeric key):

```ruby
sh.echo 'hello', 1 => '/tmp/stdout', 2 => '/tmp/stderr'
sh.cat 0 => '/tmp/test'
```

Pipes
-----

Use `|` (Note: redirects except the rightmost output and leftmost input will be ignored) :

```ruby
(sh.cat | sh.head(n: 5)).each { |l| puts l.upcase }
sh.man('ls') | sh.tail(n: 30) | sh.head(:n, 4)       # man ls | tail -n 30 | head -n 4
(sh.cat < '/tmp/abc') | sh.cat | sh.cat > '/tmp/def' # cat < /tmp/abc | cat | cat > /tmp/def
```

EasySH objects connected with pipes can be saved for later use:

```ruby
grep   = sh['grep'];   # sh.grep does not work because grep is provided by Enumerable
filter = grep['problem'] | grep._v['bugs'];
sh.man.ls | filter
```

Since EasySH does some lazy evaluation. You can add parentheses in anywhere in any order:

```ruby
kat = sh.cat;
kat['/tmp/foo'] | (kat | kat | kat.|(kat) | (kat | kat) | (kat | kat))
```

Exit status
-----------

Use `exitcode` or `to_i` to get exitcode directly:

```ruby
sh.true.exitcode   # => 0
sh.false.to_i      # => 1
```

`successful?` is `exitcode == 0` and `failed?` is `exitcode != 0`

```ruby
grep = sh['grep', :q];
(sh.echo.hello | grep['world']).failed?     # => true
(sh.echo.world | grep['world']).successful? # => true
```

Use `status` method to get a Process::Status object about last run status:

```ruby
p = sh.which('bash')
p.status        # => #<Process::Status: pid 5931 exit 0>
p = sh.which.nonexists
p.status        # => #<Process::Status: pid 6156 exit 1>
```

More sugars
-----------

An EasySH object behaves like an Array or a String sometimes.

If you pass arguments like: `[int]`, `[int, int]`, `[range]`; `[regex]`, `[regex, int]`, then `to_a` or `to_s` will be automatically called.

```ruby
# like Array
sh.echo("Line 1\nLine 2\nLine 3")[1]    # => "Line 2"
sh.echo("Line 1\nLine 2\nLine 3")[-1]   # => "Line 3"
sh.echo("Line 1\nLine 2\nLine 3")[0, 2] # => ["Line 1", "Line 2"]
sh.echo("Line 1\nLine 2\nLine 3")[1..2] # => ["Line 2", "Line 3"]

# like String
sh.echo("Hello world\nThis is a test")[/T.*$/]            # => "This is a test"
sh.echo("Hello world\nThis is a test")[/T.* ([^ ]*)$/, 1] # => "test"
```

Instant mode
------------
EasySH object with `instant = true` will execute command when `inspect` is called, which is useful in REPL environment like pry or irb.

If you like traditional `inspect` behavior, you can create the `sh` object using:

```ruby
sh = EasySH.new
```

or set `instant` to false:

```ruby
sh.instant = false
```

With `instant = false`, you need additional `to_s` or `to_a` or `to_i` etc. to get command executed.

```ruby
[2] pry(main)> sh = EasySH.new; sh.uname
=> #<EasySH: uname>
[2] pry(main)> sh.uname.to_s
=> "Linux"
```

Installation
============

```bash
gem install easysh
```

You may want to put these lines in `.pryrc` or `.irbrc`:

```ruby
require 'easysh'
sh = EasySH.instant
```
