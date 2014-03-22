#encoding : utf-8
require 'spec_helper'

require 'elexis/wiki/interface'
require "elexis/wiki/interface/workspace"

describe 'Plugin' do

  before :all do
    @dataDir =  File.expand_path(File.join(File.dirname(__FILE__), 'data', 'push'))
  end

  before :each do
  end
  
  it "should push a test page to the wiki.elexis.info" do
      search = "#{@dataDir}/**/*.mediawiki"
      mediawikis = Dir.glob(search)
      mediawikis.size.should == 1
      workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
      workspace.push
      content = workspace.mw.get('test')
      content.should_not be nil
  end

end
