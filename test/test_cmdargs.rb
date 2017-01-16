
require_relative '../lib/antisync/cmdargs'
require 'test/unit'

class TestCmdArgs < Test::Unit::TestCase
  def parse(*args)
    Antisync::CmdArgs.parse(args)
  end

  def test_status_local
    opts = parse('status', 'dev')
    assert_equal(:status, opts.command)
    assert_equal('dev', opts.target)
    assert_equal(['.'], opts.files)
    assert_equal('~/.antisync.conf', opts.config)
  end

  def test_status_dirs
    opts = parse('status', 'dev', 'foo', 'bar')
    assert_equal(:status, opts.command)
    assert_equal('dev', opts.target)
    assert_equal(%w(foo bar), opts.files)
  end

  def test_help
    opts = parse('help')
    assert_equal(:help, opts.command)
  end

  def test_no_arguments
    opts = parse
    assert_equal(:help, opts.command)
  end

  def test_bad_command
    assert_raise Antisync::CmdArgs::ParseError do
      parse('weird', 'stuff')
    end
  end

  def test_verbose
    opts = parse('status', '--verbose', 'dev')
    assert_equal(:status, opts.command)
    assert(opts.verbose)
  end

  def test_push_local
    opts = parse('push', 'dev')
    assert_equal(:push, opts.command)
    assert_equal('dev', opts.target)
    assert_equal(['.'], opts.files)
    assert_equal('~/.antisync.conf', opts.config)
  end

  def test_odd_verbose
    opts = parse('status', 'dev', 'foo', '--verbose')
    assert_equal(:status, opts.command)
    assert_equal(['foo'], opts.files)
    assert(opts.verbose)
  end

  def test_config_file
    opts = parse('status', 'dev', '--config=/foo/bar/baz.conf')
    assert_equal('/foo/bar/baz.conf', opts.config)
    assert_equal(['.'], opts.files)
  end
end
