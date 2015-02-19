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

  it "should pull doc.de ch.elexis.core.ui" do
    # TODO: Handle http://wiki.elexis.info/Doc_de
    # TODO: http://wiki.elexis.info/Doc_de
    # Nach elexis-3-base?
    @dataDir =  File.expand_path(File.join(File.dirname(__FILE__), 'data', 'doc'))
      workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
      workspace.pull
      search = "#{@dataDir}/doc_??/*.mediawiki"
      mediawikis = Dir.glob(search)
      mediawikis.size.should > 0
  end

  it "should pull all mediawiki content for ch.elexis.core.ui" do
    # TODO: http://wiki.elexis.info/Ch.elexis.core.ui.feature.feature.group
      workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
      workspace.pull
      workspace.info.show
      expect workspace.info.views.size == 8
      expect workspace.info.preferencePages.size == 8
      expect workspace.info.perspectives.size == 2
      expect workspace.info.plugins.size == 3
      expect workspace.info.features.size == 1
      search = "#{@dataDir}/**/*.mediawiki"
      mediawikis = Dir.glob(search)
      workspace.show_missing(true)
      expect workspace.views_missing_documentation.size <= 9
      expect workspace.plugins_missing_documentation.size == 0
      expect workspace.perspectives_missing_documentation.size <= 1
      name = File.join(@dataDir, "ch.elexis.core.application.feature", "doc", "Ch.elexis.core.application.feature.feature.group.mediawiki")
      expect Dir.glob(name).size == 1
      name = File.join(@dataDir, "ch.elexis.agenda", "doc", "Ch.elexis.agenda.mediawiki")
      expect Dir.glob(name).size == 1
      name = File.join(@dataDir, "ch.elexis.notes", "doc", "Ch.elexis.notes.mediawiki")
      expect Dir.glob(name).size == 1
      name = File.join(@dataDir, "ch.elexis.icpc", "doc", "P_ICPC.mediawiki")
      expect Dir.glob(name).size == 1
      expect mediawikis.size > 1
      name = File.join(@dataDir, "ch.elexis.icpc", "doc", "ChElexisIcpcViewsEpisodesview.mediawiki")
      expect Dir.glob(name).size == 1
      search = "#{@dataDir}/**/doc/*.png"
      images = Dir.glob(search)
      expect images.size >= 2
      expect workspace.features_missing_documentation.size == 0
      name = File.join(@dataDir, "ch.elexis.core.application.feature", "doc", "*mediawiki")
      Dir.glob(name).size == 1
  end  #if false
  it "should show all users" do
    workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
    puts "We have #{workspace.mw.users.size} wiki users"
  end

end
