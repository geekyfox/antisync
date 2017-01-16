require_relative '../lib/antisync/parser'
require 'test/unit'

class TestBroken < Test::Unit::TestCase
  def setup
    @parser = Antisync::Parser::Parser.new('foo')
  end

  def test_malformed_meta
    assert_raise Antisync::Parser::ParseError do
      @parser << '~ meta'
    end

    assert_raise Antisync::Parser::ParseError do
      @parser << '~ meta foo bar baz'
    end

    assert_raise Antisync::Parser::ParseError do
      @parser << '~ meta foo' << '~ meta bar'
    end
  end

  def test_malformed_public
    assert_raise Antisync::Parser::ParseError do
      @parser << '~ public foo bar baz'
    end

    assert_raise Antisync::Parser::ParseError do
      @parser << '~ public foo 111111' << '~ public foo 222222'
    end
  end
end
