require 'test/unit'
require 'easysh'
require 'fileutils'
require 'tmpdir'

class EasySHTest < Test::Unit::TestCase

  def sh; @sh ||= EasySH.new; end

  def with_tmpfile(content = [*0..5].join("\n"))
    tmppath = File.join(Dir.tmpdir, 'test.txt')
    begin
      File.open(tmppath, 'w') { |f| f.write content }
      yield tmppath, content
    ensure
      FileUtils.rm_f tmppath
    end
  end

  def fd_count
    Dir['/proc/self/fd/*'].count
  end

  def assert_fd_count_equal
    count = fd_count
    yield
    assert_equal fd_count, count
  end

  def test_execute
    with_tmpfile do |tmppath, content|
      assert_equal sh.cat(tmppath).to_s, content
      assert_equal sh.cat[tmppath].to_s, content
      assert_equal sh['cat', tmppath].to_s, content
      kat = sh.cat[tmppath]
      assert_equal kat.to_s, content
    end
  end

  def test_alternatives
    ref_cmd = sh['ls', '-l'].cmd
    assert_equal ref_cmd, sh.ls['-l'].cmd
    assert_equal ref_cmd, sh.ls[:l].cmd
    assert_equal ref_cmd, sh.ls(:l).cmd
    assert_equal ref_cmd, sh.ls._l.cmd
    assert_equal ref_cmd, sh['ls']._l.cmd

    ref_cmd = sh['ls', '--all', '--color=auto'].cmd
    assert_equal ref_cmd, sh.ls.__all[:color => :auto].cmd
    assert_equal ref_cmd, sh.ls.__all(:color => :auto).cmd
    assert_equal ref_cmd, sh.ls[:all][:color => :auto].cmd
    assert_equal ref_cmd, sh.ls(:all)[:color => :auto].cmd

    ref_cmd = sh['tail', '-f', '-n', '3'].cmd
    assert_equal ref_cmd, sh.tail._f._n['3'].cmd
    assert_equal ref_cmd, sh.tail._f._n(3).cmd
    assert_equal ref_cmd, sh.tail._f[n: 3].cmd
    assert_equal ref_cmd, sh.tail._f[:n, 3].cmd
    assert_equal ref_cmd, sh.tail._f(n: 3).cmd
    assert_equal ref_cmd, sh.tail._f(:n, 3).cmd
    assert_equal ref_cmd, sh.tail(:f, n: 3).cmd
    assert_equal ref_cmd, sh.tail(:f, :n, 3).cmd
    assert_equal ref_cmd, sh.tail[:f, n: 3].cmd
    assert_equal ref_cmd, sh.tail[:f, :n, 3].cmd
  end

  def test_enumerator
    with_tmpfile [*10..25].join("\n") do |tmppath, content|
      kat = sh.cat
      kat_t = kat[tmppath]
      assert_equal kat[tmppath].min, '10'
      assert_equal kat_t.max, '25'

      en  = kat_t.each
      assert_equal en.min, '10'
      assert_equal en.max, '25'

      assert_equal kat_t.chars.min, "\n"
      assert_equal kat_t.bytes.min, "\n".ord
    end
  end

  def test_options
    with_tmpfile do |tmppath|
      assert_include sh.ls._l(tmppath).to_s, '-'
      assert_equal sh.ls._l(tmppath).read, sh.ls(:l)[tmppath].to_s
      assert_equal sh.ls._l(tmppath).to_s, sh.ls['-l', tmppath].read
    end
  end

  def test_pipes
    kat = sh.cat

    with_tmpfile do |tmppath, content|
      assert_fd_count_equal do
        assert_equal kat[tmppath].to_s, content
        assert_equal (kat[tmppath] | kat | kat | kat | kat | kat | kat | kat | kat | kat).to_s, content
        assert_equal (kat[tmppath] | kat | (kat | (kat | kat | kat) | kat | kat) | kat | kat).to_s, content
      end
    end
  end

  def test_broken_pipes
    kat = sh.cat
    assert_fd_count_equal do
      assert_equal (sh.echo('hello') | kat | sh.false | kat | kat).read.empty?, true
    end
    assert_raise(TypeError) { sh.echo('hello') | 'abc' }
  end

  def test_instant
    kat = sh.cat
    kat.instant = true

    with_tmpfile do |tmppath, content|
      assert_fd_count_equal do
        assert_equal kat[tmppath].inspect, content
      end
    end
  end

  def test_redirects
    kat = sh.cat
    with_tmpfile do |tmppath, content|
      assert_fd_count_equal do
        assert_equal ((kat < tmppath) | kat).to_s, content
        ((sh.echo('hello') | kat) > tmppath).to_s
        assert_equal File.read(tmppath).chomp, 'hello'
      end
    end
  end

  def test_lines_regex
    assert_fd_count_equal do
      assert_equal sh.echo["a\nb"][1], 'b'
      assert_equal sh.echo["a\nb"][-1], 'b'
      assert_equal sh.echo["a\nb\nc"][0..1], ['a', 'b']
      assert_equal sh.echo["a\nb\nc"][1, 2], ['b', 'c']
      assert_equal sh.echo["a\nb\nc"][1, 2, 3].class, sh.class
      assert_equal sh.echo["a\nb\nc"][1..2, 3].class, sh.class
      assert_equal sh.echo["hello\nabcword"][/b.*o/], 'bcwo'
      assert_equal sh.echo["hello\nabcword"][/b(.*)o/, 1], 'cw'
      assert_equal sh.echo("Hello world\nThis is a test")[/T.*$/], "This is a test"
      assert_equal sh.echo("Hello world\nThis is a test")[/T.* ([^ ]*)$/, 1], "test"
    end
  end

  def test_status
    assert_equal sh.true.exitcode, 0
    assert_not_equal sh.false.exitstatus, 0
    assert_equal sh.true.successful?, true
    assert_equal sh.false.failed?, true
    sh1 = sh.true
    assert_equal sh1.status, nil
    sh1.to_s
    assert_not_equal sh1.status, nil
    assert_equal sh1.exitcode, 0
  end

  def test_sh_in_sh
    sudo = sh.sudo
    cmd  = sh.ifconfig.eth0

    assert_equal sudo[cmd].cmd, sh.sudo.ifconfig.eth0.cmd
    assert_equal sh.sudo(cmd).cmd, sh.sudo.ifconfig.eth0.cmd
    assert_equal sudo[cmd, 'up'].cmd, sh.sudo.ifconfig.eth0.up.cmd
    assert_equal sh.sudo(cmd).up.cmd, sh.sudo.ifconfig.eth0.up.cmd

    assert_raise(ArgumentError) { sudo[cmd | cmd] }

    opt = (sh > '/tmp/output')
    assert_equal sudo.cmd, sudo[opt].cmd
    assert_not_equal sudo.opt, sudo[opt].opt
    assert_equal sudo[opt].opt[1], '/tmp/output'

    mtu = sh.mtu['1440']
    ref_cmd = sh.sudo.ifconfig.eth0.up.mtu['1440'].cmd
    assert_equal ref_cmd, sh.sudo[cmd].up[mtu].cmd
    assert_equal ref_cmd, sh.sudo[cmd, 'up', mtu].cmd
    assert_equal ref_cmd, sh.sudo[cmd, ['up', mtu]].cmd
    assert_equal ref_cmd, sh.sudo(cmd, 'up', mtu).cmd
    assert_equal ref_cmd, sh.sudo(cmd, ['up', 'mtu', '1440']).cmd
  end
end
