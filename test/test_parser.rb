
require_relative '../lib/antisync/parser'
require 'test/unit'

module ParserMixin
  def load(target, filename)
    fullname = File.join('test/samples', filename)
    entry = Antisync::Parser.load(target, fullname)
    verify_to_hash(entry)
    content_fullname = fullname.sub(/\.txt$/, '.content')
    if File.exist?(content_fullname)
      content = File.read(content_fullname).strip
      assert_equal(content, entry.content.strip)
    end
    entry
  end

  def verify_to_hash(entry)
    assert_equal(entry.public_id, entry.to_h[:id])
    assert_equal(entry.redirect_url, entry.to_h[:url])
    verify_not_redirect(entry) if entry.redirect_url.nil?
  end

  def verify_not_redirect(entry)
    assert_equal(entry.summary, entry.to_h[:summary])
    assert_equal(entry.content, entry.to_h[:body])
    assert_equal(entry.title, entry.to_h[:title])
  end
end

# rubocop:disable ClassLength
class TestParser < Test::Unit::TestCase
  include ParserMixin

  def test_minimal
    entry = load('dev', 'minimal.txt')
    assert(entry.publish?)
    assert(entry.new?)
    assert_equal('Hello, world', entry.content)
    assert_equal(nil, entry.to_h[:id])
    assert_equal(nil, entry.summary)
  end

  def test_draft
    entry = load('dev', 'draft.txt')
    assert(!entry.publish?)
  end

  def test_two_lines
    entry = load('dev', 'two-lines.txt')
    assert(entry.new?)
    assert_equal(nil, entry.to_h[:id])
  end

  def test_published
    entry = load('prod', 'published.txt')
    assert(!entry.new?)
    assert_equal(333_444, entry.public_id)
  end

  def test_title
    entry = load('prod', 'titled.txt')
    assert_equal('All about stuff', entry.title)

    minimal = load('dev', 'minimal.txt')
    assert_equal(minimal.content, entry.content)
    assert_not_equal(minimal.md5, entry.md5)
  end

  def test_redirect
    prod = load('prod', 'redirect.txt')
    assert_equal('http://example.com/whatever', prod.redirect_url)
    assert_equal('Hello, world', prod.content)
    assert_equal(nil, prod.to_h[:content])

    prod_normal = load('prod', 'titled.txt')
    assert_not_equal(prod_normal.md5, prod.md5)
  end

  def test_no_redirect
    entry = load('dev', 'redirect.txt')
    assert_equal(nil, entry.redirect_url)
    assert_equal('Hello, world', entry.content)
    assert_equal('All about stuff', entry.title)

    entry_normal = load('dev', 'titled.txt')
    assert_equal(entry_normal.md5, entry.md5)
  end

  def test_series
    series = [{ series: 'foobar', index: 123 }]

    entry = load('dev', 'series.txt')
    assert_equal(series, entry.series)
    assert_equal(series, entry.to_h[:series])

    minimal = load('dev', 'minimal.txt')
    assert_equal([], minimal.series)
    assert_not_equal(minimal.md5, entry.md5)
  end

  def test_symlink
    entry = load('dev', 'symlink.txt')
    assert_equal('foobar', entry.symlink)
    assert_equal('foobar', entry.to_h[:symlink])

    minimal = load('dev', 'minimal.txt')
    assert_nil(minimal.symlink)
    assert_not_equal(minimal.md5, entry.md5)
  end

  def test_metalink
    entry = load('dev', 'metalink.txt')
    assert_equal('foobar', entry.metalink)
    assert_equal('foobar', entry.to_h[:metalink])

    minimal = load('dev', 'minimal.txt')
    assert_nil(minimal.metalink)
    assert_not_equal(minimal.md5, entry.md5)
  end

  def test_poem
    load('dev', 'poem.txt')
  end

  def test_poem_mixed
    load('dev', 'haiku.txt')
  end

  def test_footnote
    load('dev', 'footnote.txt')
  end

  def test_summary
    entry = load('dev', 'summary.txt')
    assert_equal("Some summary.\n", entry.summary)

    minimal = load('dev', 'minimal.txt')
    assert_equal(minimal.content, entry.content)
    assert_not_equal(minimal.md5, entry.md5)
  end

  def test_no_content
    assert_raise Antisync::Parser::ParseError do
      load('dev', 'contentless.txt')
    end
  end

  def test_tags
    entry = load('dev', 'tagged.txt')
    assert_equal(%w(some tags), entry.tags)
    assert_equal(%w(some tags), entry.to_h[:tags])

    minimal = load('dev', 'minimal.txt')
    assert_equal(minimal.content, entry.content)
    assert_not_equal(minimal.md5, entry.md5)
  end

  def test_insert_summary
    inline = load('dev', 'inline-summary.txt')
    insert = load('dev', 'insert-summary.txt')
    assert_equal(inline.content, insert.content)
    assert_equal(inline.summary, insert.summary)
    assert_equal(inline.to_h, insert.to_h)
  end

  def test_code
    entry = load('dev', 'code.txt')
    content = File.read('test/samples/code.content').strip
    assert_equal(content, entry.content)
  end

  def test_inject_id
    FileUtils.cp('test/samples/minimal.txt', 'test/samples/minimal.tmp')
    Antisync::Parser.inject_id('prod', 'test/samples/minimal.tmp', 111_222)
    expected = File.open('test/samples/minimal-injected.txt', 'r').readlines
    actual = File.open('test/samples/minimal.tmp', 'r').readlines
    assert_equal(expected, actual)
    FileUtils.rm('test/samples/minimal.tmp')
  end
end
