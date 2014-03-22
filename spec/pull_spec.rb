#encoding : utf-8
require 'spec_helper'

require 'elexis/wiki/interface'
require "elexis/wiki/interface/workspace"

describe 'Plugin' do

  def remove_all_mediawik
    files2rm = Dir.glob("#{@dataDir}/**/*.mediawiki") + Dir.glob("#{@dataDir}/**/*.png")
    FileUtils.rm(files2rm, :verbose => $VERBOSE) if files2rm.size > 0
  end
  before :all do
    @dataDir =  File.expand_path(File.join(File.dirname(__FILE__), 'data', 'pull'))
  end

  before :each do
    remove_all_mediawik
  end
  
  after :each do
    remove_all_mediawik
  end
  
  it "should pull all mediawiki content for ch.elexis.core.ui" do
      workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
      workspace.pull
      workspace.info.show
      workspace.info.views.size.should == 9
      workspace.info.preferencePages.size.should == 8
      workspace.info.perspectives.size.should == 2
      search = "#{@dataDir}/**/*.mediawiki"
      mediawikis = Dir.glob(search)
      workspace.show_missing(true)
      workspace.views_missing_documentation.size.should <= 9
      workspace.plugins_missing_documentation.size.should == 0
      workspace.perspectives_missing_documentation.size.should <= 1
      name = File.join(@dataDir, "ch.elexis.agenda", "doc", "Ch.elexis.agenda.mediawiki")
      Dir.glob(name).size.should == 1
      name = File.join(@dataDir, "ch.elexis.notes", "doc", "Ch.elexis.notes.mediawiki")
      Dir.glob(name).size.should == 1
      name = File.join(@dataDir, "ch.elexis.icpc", "doc", "P_ICPC.mediawiki")
      Dir.glob(name).size.should == 1
      mediawikis.size.should > 1
      name = File.join(@dataDir, "ch.elexis.icpc", "doc", "ChElexisIcpcViewsEpisodesview.mediawiki")
      Dir.glob(name).size.should == 1
      search = "#{@dataDir}/**/doc/*.png"
      images = Dir.glob(search)
      images.size.should >= 2
  end
  it "should show all users" do
    workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
    puts "We have #{workspace.mw.users.size} wiki users"
  end if false
end
