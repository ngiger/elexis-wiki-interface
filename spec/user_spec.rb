#encoding : utf-8
require 'spec_helper'

require 'elexis/wiki/interface'
require "elexis/wiki/interface/workspace"
describe 'Plugin' do

  def remove_all_mediawikii
    files2rm = Dir.glob("#{@dataDir}/**/*.mediawiki") + Dir.glob("#{@dataDir}/**/*.png")
    FileUtils.rm(files2rm, :verbose => $VERBOSE) if files2rm.size > 0
  end
  before :all do
    @dataDir =  File.expand_path(File.join(File.dirname(__FILE__), 'data', 'pull'))
  end

  before :each do
    remove_all_mediawikii
  end
  
  after :each do
    remove_all_mediawikii
  end

  it "should show all users" do
    workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
    wiki_users = workspace.mw.users
    puts "We have #{wiki_users.size} wiki users"
    expect wiki_users.size <= 50
    contribs = workspace.mw.contributions(wiki_users.first)
  end

end
