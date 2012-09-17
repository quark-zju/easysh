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
        ((sh.echo('hello') | kat) > tmppath).!
        assert_equal File.read(tmppath).chomp, 'hello'
      end
    end
  end
end
