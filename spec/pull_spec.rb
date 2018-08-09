#encoding : utf-8
require 'spec_helper'

require "elexis/wiki/workspace"
describe 'Plugin' do

  def remove_all_mediawiki
    files2rm = Dir.glob("#{@dataDir}/**/*.mediawiki") + Dir.glob("#{@dataDir}/**/*.png")
    FileUtils.rm(files2rm, :verbose => $VERBOSE) if files2rm.size > 0
    system("git checkout #{@dataDir}")
  end
  before :all do
    @dataDir =  File.expand_path(File.join(File.dirname(__FILE__), 'data', 'pull'))
    skip 'does not work under travis-ci' if ENV['TRAVIS']
    @workspace =  Elexis::Wiki::Workspace.new(@dataDir)
    @workspace.pull
  end

  after :all do
    remove_all_mediawiki
  end

  it "should pull doc.de ch.elexis.core.ui" do
    # TODO: Handle http://wiki.elexis.info/Doc_de
    # TODO: http://wiki.elexis.info/Doc_de
    search = "#{@dataDir}/?oc_??/*.mediawiki"
    mediawikis = Dir.glob(search)
    expect(mediawikis.size).to eq 1
  end

  it "should pull views" do
    expect(@workspace.info.views.size).to eq 9
    expect(@workspace.views_missing_documentation.size).to be <= 9
  end

  it "should pull all mediawiki content for ch.elexis.core.ui" do
    # TODO: http://wiki.elexis.info/Ch.elexis.core.ui.feature.feature.group
      @workspace.info.show
      expect(@workspace.info.preferencePages.size).to eq 8
      expect(@workspace.info.perspectives.size).to eq 2
      expect(@workspace.info.plugins.size).to eq 3
      expect(@workspace.info.features.size).to eq 1
      search = "#{@dataDir}/**/*.mediawiki"
      mediawikis = Dir.glob(search)
      expect(mediawikis.size).to be > 1
      @workspace.show_missing(true)
      expect(@workspace.perspectives_missing_documentation.size).to be <= 1
      if $VERBOSE
        search = "#{@dataDir}/**/*.mediawiki"
        wiki_files = Dir.glob(search)
        puts "We have the pulled the following wiki_files\n#{wiki_files.join("\n")}"
      end
      name = File.join(@dataDir, "ch.elexis.core.application.feature", "Ch.elexis.core.application.feature.feature.group.mediawiki")
      expect(Dir.glob(name).size).to eq 0
      name = File.join(@dataDir, "ch.elexis.agenda", "doc", "Ch.elexis.agenda.mediawiki")
      expect(Dir.glob(name).size).to eq 1
      name = File.join(@dataDir, "ch.elexis.agenda", "*.mediawiki")
      expect(Dir.glob(name).size).to eq(0)

      name = File.join(@dataDir, "ch.elexis.notes", "doc", "Ch.elexis.notes.mediawiki")
      expect(Dir.glob(name).size).to eq 1
  end

  it "should pull everything for DOC_DE" do
      search = "#{@dataDir}/**/doc/*.png"
      images = Dir.glob(search)
      images.each{
        |img|
        expect(/:/.match(img)).to be_nil
      }
      skip('test forimages for doc_de no longer working')
      expect(images.size).to be >= 1
      expect(@workspace.features_missing_documentation.size).to eq 0
  end

  it "should pull everything for ICPC" do
      name = File.join(@dataDir, "ch.elexis.icpc", "doc", "P_ICPC.mediawiki")
      expect(Dir.glob(name).size).to eq 1
      name = File.join(@dataDir, "ch.elexis.icpc", "doc", "ChElexisIcpcViewsEpisodesview.mediawiki")
      expect(Dir.glob(name).size).to eq 1
      name = File.join(@dataDir, "ch.elexis.icpc", "doc", "Ch.elexis.icpc.mediawiki")
      expect(Dir.glob(name).size).to eq 1
      content = IO.read(name)
      skip('test forimages for icpc no longer working')
      m = /(File:[\w\.]+)[:_](\w+.png)/.match(content)
      expect(m).to eq nil
      m = /(File:[\w\.]+)\/(icpc0.png)/i.match(content)
      expect(m[0]).to eq 'File:Ch.elexis.icpc/icpc0.png'
  end

  it "should show all users" do
    @workspace =  Elexis::Wiki::Workspace.new(@dataDir)
    puts "We have #{@workspace.if.users.size} wiki users"
  end unless ENV['TRAVIS']

  it "should check the matrix" do
    @workspace.info.show
    $ws_errors = []
    @workspace.check_page_in_matrix('ch.elexis.notes.feature.feature.group')
    expect($ws_errors.size).to eq 0
    $ws_errors = []
    @workspace.check_page_in_matrix('xxxxxxxxx')
    expect($ws_errors.size).to eq 1
  end

  it "should not create any file containing Datei: in their name" do
    search = "#{@workspace.ws_dir}/**/*Datei:*"
    files = Dir.glob(search)
    expect(files.size).to eq 0
  end

  it "should find any files with ':' in their names" do
    search = "#{@workspace.ws_dir}/**/*:*"
    files = Dir.glob(search)
    expect(files.size).to eq 0
  end
end
