require File.expand_path('../test_helper', __FILE__)

class TemplateTest < Test::Unit::TestCase
  def setup
    @view = @template = nil
  end

  def view
    @view ||= ActionView::Base.new(VIEW_PATH).tap do |view|
      view.output_buffer = ActiveSupport::SafeBuffer.new rescue ''
    end
  end

  def template
    @template ||= Minimal::Template.new(view)
  end

  test "capturing a block" do
    result = view.with_output_buffer do
      view.concat('foo')
      view.concat('bar')
      'baz'
    end
    assert_equal 'foobar', result
  end

  test "capturing a helper with a block" do
    block = lambda do
      view.concat('foo')
      view.concat('bar')
      'baz'
    end
    result = view.content_tag(:div, &lambda { view.with_output_buffer(&block) })
    assert_equal '<div>foobar</div>', result
  end

  test "call_view calling a non-concating helper without a block" do
    result = template.send(:call_view, :number_with_precision, 1234)
    assert_equal '1234.000', result
  end

  test "call_view calling a non-concating helper with a block" do
    template.send(:call_view, :content_tag, :div) do
      template << 'foo'
      template << 'bar'
      'baz'
    end
    assert_equal '<div>foobar</div>', view.output_buffer.gsub("\n", '')
  end

  test "call_view calling a concating helper with a block" do
    template.send(:call_view, :form_for, 'foo', :url => '/foo') do |f|
      template << f.text_field('foo')
      template << f.text_field('bar')
      'baz'
    end
    html = '<form accept-charset="UTF-8" action="/foo" method="post">' +
      '<div style="margin:0;padding:0;display:inline"><input name="utf8" type="hidden" value="&#x2713;" /></div>' +
      '<input id="foo_foo" name="foo[foo]" size="30" type="text" />' +
      '<input id="foo_bar" name="foo[bar]" size="30" type="text" />' +
      '</form>'
    assert_equal html, view.output_buffer.gsub("\n", '')
  end

  # test "does not buffer but returns a helper's result when :capture => true was passed'" do
  #   result = template.a('foo', :href => '#', :capture => true)
  #   assert_equal '<a href="#">foo</a>', result
  #   assert_equal '', view.output_buffer
  # end

  test "simple render with local assigns" do
    html = '<html><head></head><body><h1>plain</h1><p>local</p><div><div>nested</div></div></body></html>'
    assert_equal html, view.render(:file => 'foo/simple', :locals => { :local => 'local' }).gsub("\n", '')
  end

  test "accessing an assigned instance_variable" do
    view.assign(:foo => 'foo')
    assert_equal '<p>foo</p>', view.render(:file => 'foo/ivar').gsub("\n", '')
  end

  test "partial rendering" do
    html = '<div><p>foo</p><p>bar</p></div><p>baz</p>'
    assert_equal html, view.render(:file => 'foo/partial').gsub("\n", '')
  end

  test "table" do
    html = '<table><tr><td>foo</td><td>bar</td><td>baz</td></tr></table>'
    assert_equal html, view.render(:file => 'foo/table').gsub("\n", '')
  end

  test "form_tag with input_tags" do
    html = '<div>foo</div>' +
      '<form accept-charset="UTF-8" action="/foo" method="post">' +
      '<div style="margin:0;padding:0;display:inline"><input name="utf8" type="hidden" value="&#x2713;" /></div>' +
      '<div><input id="bar" name="bar" type="text" /></div>' +
      '<input id="baz" name="baz" type="text" />' +
      '</form>'
    assert_equal html, view.render(:file => 'foo/form_tag').gsub("\n", '')
  end

  test "form_for" do
    html = '<div>foo</div>' +
      '<form accept-charset="UTF-8" action="/foo" method="post">' +
      '<div style="margin:0;padding:0;display:inline"><input name="utf8" type="hidden" value="&#x2713;" /></div>' +
      '<div><input id="foo_bar" name="foo[bar]" size="30" type="text" /></div>' +
      '<input id="foo_baz" name="foo[baz]" size="30" type="text" />' +
      '</form>'
    assert_equal html, view.render(:file => 'foo/form_for').gsub("\n", '')
  end

  test "form_for with nested fields_for" do
    html = '<form accept-charset="UTF-8" action="/foo" method="post">' +
    '<div style="margin:0;padding:0;display:inline"><input name="utf8" type="hidden" value="&#x2713;" /></div>' +
    '<select id="form_foo" name="form[foo]"><option value="1">1</option></select>' +
    '<select id="form_outer_bar" name="form[outer][bar]"><option value="1">1</option></select>' +
    '<select id="form_outer_inner_baz" name="form[outer][inner][baz]"><option value="1">1</option></select>' +
    '</form>'
    assert_equal html, view.render(:file => 'foo/fields_for').gsub("\n", '')
  end

  test "misc_helpers" do
    html = '<img alt="Rails" src="http://no-asset-host.com/rails.png" />' +
      "<pre class='debug_dump'>--- foo</pre>" +
      '<script type="text/javascript">//<![CDATA[alert(\'All is good\')//]]></script>' +
      # '<div class="record" id="record_1">content</div>' +
      '<br />' +
      '<p>Hello world!</p>' +
      '<p>Hello world!</p>' +
      '<p><em>Hello world!</em></p>' +
      '<p><em>Hello world!</em></p>' +
      '<a href="#">foo</a>'
    html
    assert_equal html, view.render(:file => 'foo/misc_helpers').gsub("\n", '')
  end

  test "yielding in layouts works" do
    html = '<html><head></head><body><div>content</div><div>sidebar</div></body></html>'
    assert_equal html, view.render(:file => 'foo/content', :layout => 'foo/layout').gsub("\n", '')
  end

  test "responds to methods the view responds to" do
    assert template.respond_to?(:form_for)
  end

  test "responds to instance_variable names set on the view" do
    view.instance_variable_set(:@foo, 'bar')
    assert template.respond_to?(:foo)
  end

  test "responds to local variable names" do
    template.instance_variable_set(:@locals, :foo => 'bar')
    assert template.respond_to?(:foo)
  end

  test "autobuffers expected methods" do
    methods = %w(
      error_messages_for
    )
    methods.each do |method|
      assert_match Minimal::Template::AUTO_BUFFER, method
    end
  end
end
