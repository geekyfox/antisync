require_relative '../lib/antisync'
require 'test/unit'

class TestBroken < Test::Unit::TestCase
  def make(*args)
    args += ['--config=test/samples/antisync.conf']
    app = Antisync::App.new(args)
    app.headless = true
    app
  end

  def test_init_status
    app = make('status', 'dummy')
    assert_equal('N/A', app.config.base_url)
    assert_equal('N/A', app.config.api_key)
  end

  def test_init_missing_section
    assert_raise do
      app = make('status', 'foobar')
      app.config.base_url
    end
  end

  def test_scanning
    scanner = Antisync::FileSet.new.tap { |x| x << 'test/samples' }
    counter = 0
    scanner.each do |x|
      assert(!File.directory?(x), "#{x} is a directory")
      counter += 1
    end
    assert(counter > 0)
  end

  def test_repeated_scanning
    files = Set.new
    fs = Antisync::FileSet.new << 'test' << 'test/samples'
    fs.each { |x| assert(files.add?(x)) }
    fs = Antisync::FileSet.new << 'test'
    fs.each { |x| assert(files.delete?(x)) }
    assert_equal([], files.to_a)
  end

  def test_help
    make('help').run
  end
end
