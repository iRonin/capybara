require 'capybara/spec/test_app'
require 'nokogiri'

Dir[File.dirname(__FILE__)+'/session/*'].each { |group| require group }

module Quietly
  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(RbConfig::CONFIG['host_os'] =~ /rmswin|mingw/ ? 'NUL:' : '/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
  end

  def quietly
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        yield
      end
    end
  end
end

shared_examples_for "session" do
  def extract_results(session)
    YAML.load Nokogiri::HTML(session.body).xpath("//pre[@id='results']").first.text.lstrip
  end

  include Quietly

  after do
    @session.reset_session!
  end

  describe '#body' do
    it "should return the unmodified page body" do
      @session.visit('/')
      @session.body.should include('Hello world!')
    end

    if "".respond_to?(:encoding)
      context "encoding of response between ascii and utf8" do
        it "should be valid with html entities" do
          @session.visit('/with_html_entities')
          lambda { @session.body.encode!("UTF-8") }.should_not raise_error
        end

        it "should be valid without html entities" do
          @session.visit('/with_html')
          lambda { @session.body.encode!("UTF-8") }.should_not raise_error
        end
      end
    end
 end

  describe '#html' do
    it "should return the unmodified page body" do
      # html and body should be aliased, but we can't just check for
      # method(:html) == method(:body) because these shared examples get run
      # against the DSL, which uses forwarding methods.  So we test behavior.
      @session.visit('/')
      @session.html.should include('Hello world!')
    end
  end

  describe '#source' do
    it "should return the unmodified page source" do
      @session.visit('/')
      @session.source.should include('Hello world!')
    end
  end

  describe '#reset_session!' do
    it "removes cookies" do
      @session.visit('/set_cookie')
      @session.visit('/get_cookie')
      @session.body.should include('test_cookie')

      @session.reset_session!
      @session.visit('/get_cookie')
      @session.body.should_not include('test_cookie')
    end

    it "resets current url, host, path" do
      @session.visit '/foo'
      @session.current_url.should_not be_empty
      @session.current_host.should_not be_empty
      @session.current_path.should == '/foo'

      @session.reset_session!
      [nil, '', 'about:blank'].should include @session.current_url
      @session.current_host.should be_nil
      @session.current_path.should be_nil
    end

    it "resets page body" do
      @session.visit('/with_html')
      @session.body.should include('This is a test')
      @session.find('.//h1').text.should include('This is a test')

      @session.reset_session!
      @session.body.should_not include('This is a test')
      @session.should have_no_selector('.//h1')
    end

    it "raises any errors caught inside the server" do
      expect do
        quietly { @session.visit("/error") }
        @session.reset_session!
      end.to raise_error(TestApp::TestAppError)
      @session.visit("/")
      @session.current_path.should == "/"
    end
  end

  it_should_behave_like "node"
  it_should_behave_like "visit"
  it_should_behave_like "all"
  it_should_behave_like "first"
  it_should_behave_like "attach_file"
  it_should_behave_like "check"
  it_should_behave_like "choose"
  it_should_behave_like "click_link_or_button"
  it_should_behave_like "click_button"
  it_should_behave_like "click_link"
  it_should_behave_like "fill_in"
  it_should_behave_like "find_button"
  it_should_behave_like "find_field"
  it_should_behave_like "find_link"
  it_should_behave_like "find_by_id"
  it_should_behave_like "find"
  it_should_behave_like "assert_selector"
  it_should_behave_like "has_text"
  it_should_behave_like "has_css"
  it_should_behave_like "has_selector"
  it_should_behave_like "has_xpath"
  it_should_behave_like "has_link"
  it_should_behave_like "has_button"
  it_should_behave_like "has_field"
  it_should_behave_like "has_select"
  it_should_behave_like "has_table"
  it_should_behave_like "select"
  it_should_behave_like "text"
  it_should_behave_like "uncheck"
  it_should_behave_like "unselect"
  it_should_behave_like "within"
  it_should_behave_like "current_url"

  it "should encode complex field names, like array[][value]" do
    @session.visit('/form')
    @session.fill_in('address1_city', :with =>'Paris')
    @session.fill_in('address1_street', :with =>'CDG')
    @session.fill_in('address1_street', :with =>'CDG')
    @session.select("France", :from => 'address1_country')

    @session.fill_in('address2_city', :with => 'Mikolaiv')
    @session.fill_in('address2_street', :with => 'PGS')
    @session.select("Ukraine", :from => 'address2_country')

    @session.click_button "awesome"

    addresses=extract_results(@session)["addresses"]
    addresses.should have(2).addresses

    addresses[0]["street"].should   == 'CDG'
    addresses[0]["city"].should     == 'Paris'
    addresses[0]["country"].should  == 'France'

    addresses[1]["street"].should   == 'PGS'
    addresses[1]["city"].should     == 'Mikolaiv'
    addresses[1]["country"].should  == 'Ukraine'
  end
end

describe Capybara::Session do
  context 'with non-existant driver' do
    it "should raise an error" do
      running {
        Capybara::Session.new(:quox, TestApp).driver
      }.should raise_error(Capybara::DriverNotFoundError)
    end
  end
end
