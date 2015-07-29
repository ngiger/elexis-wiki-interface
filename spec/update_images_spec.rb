#encoding : utf-8
require 'spec_helper'

require 'elexis/wiki/interface'
require "elexis/wiki/interface/workspace"

describe 'ImageHandling' do

  before :all do
    @originDir = File.expand_path(File.join(File.dirname(__FILE__), 'data', 'push', 'ch.elexis.icpc'))
    @dataDir = File.expand_path(File.join(File.dirname(__FILE__), 'run', 'push'))
    FileUtils.rm_rf(@dataDir)
    FileUtils.makedirs(@dataDir)
    FileUtils.cp_r(@originDir, @dataDir, :verbose => true, :preserve => true)
  end

  it "should shorten images files correctly" do
    @dataDir =  File.expand_path(File.join(File.dirname(__FILE__), 'data', 'pull'))
    workspace =  Elexis::Wiki::Interface::Workspace.new(@dataDir)
    image = File.join(@dataDir, 'ch.elexis.icpc', 'doc', 'ch.elexis.ch/icpc1.png')
    expect(workspace.shorten_wiki_image('/dummy/Ch.elexis.ch:icpc4.png')).to eq 'icpc4.png'
    expect(workspace.shorten_wiki_image('/dummy/ch.elexis.ch:icpc3.png')).to eq 'icpc3.png'
    expect(workspace.shorten_wiki_image('/dummy/ch.elexis.ch/icpc2.png')).to eq 'icpc2.png'
    expect(workspace.shorten_wiki_image('/dummy/ch.elexis.ch_icpc1.png')).to eq 'icpc1.png'
  end

  it "should adapt correctly the image name" do
    wiki_file = File.join(@dataDir, 'ch.elexis.icpc', 'doc', 'test.mediawiki')
    puts wiki_file
    expect(File.exists?(wiki_file)).to eq true
    before =  ['tag_one [[Image:ch.elexis.icpc:icpc1.png|image]]',
      'tag_two [[Image:ch.elexis.icpc:icpc2.png|image]]',
      'tag_three [[Image:icpc3.png|image]]',
      'tag_four [[Datei:ch.elexis.icpc:icpc4.png|image]]',
      'tag_five [[Datei:Ch.elexis.icpc:icpc5.png|image]]',
                ]
    original = IO.read(wiki_file)
    before.each{|string| expect(original).to include string }
    Elexis::Wiki::Interface.fix_image_locations(wiki_file, 'ch.elexis.icpc')
    after =  ['tag_one [[Image:ch.elexis.icpc/icpc1.png|image]]',
      'tag_two [[Image:ch.elexis.icpc/icpc2.png|image]]',
      'tag_three [[Image:icpc3.png|image]]',
      'tag_four [[Datei:ch.elexis.icpc/icpc4.png|image]]',
      'tag_five [[Datei:Ch.elexis.icpc/icpc5.png|image]]',
                ]
    changed = IO.read(wiki_file)
    after.each{|string| expect(changed).to include string }
  end
end

