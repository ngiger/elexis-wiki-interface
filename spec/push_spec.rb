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
    fqdn = `hostname -f`
    pending 'do not run push test on travis' if fqdn.match(/travis-ci.org/)
    hasConfig =  File.exists?('/etc/elexis-wiki-interface/config.yml') or File.exists?(File.join(Dir.pwd, 'config.yml'))
    pending 'no config file' unless hasConfig
    search = "#{@dataDir}/**/*.mediawiki"
    mediawikis = Dir.glob(search)
    mediawikis.size.should == 1
    workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
    workspace.push
    content = workspace.mw.get('test')
    content.should_not be nil
  end
  it "should show all users" do
    workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
    users = workspace.mw.users
    puts "We have #{users.size} wiki users"
    users.each{
      |user|
      contrib = workspace.mw.contributions(user, 10)
      puts "#{sprintf("%2d", contrib.size)} contributions for user #{user}"
    }
  end if false

end
