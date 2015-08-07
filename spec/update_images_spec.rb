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

  it "should return corret canonical_names for a plugin" do
    expected = "ch.elexis.icpc/icpc0.png"
    ["xxxx/icpc0.png",
     "icpc0.png",
     "ch.elexis.icpc/icpc0.png",
      "ch.elexis.icpc_icpc0.png",
      "ch.elexis.icpc:icpc0.png",
     ].each{ |variant|
     res = Elexis::Wiki::Interface.return_canonical_image_name("ch.elexis.icpc", expected)
      expect(res).to eq expected
    }
  end

  it "should return corret canonical_names for a feature" do
    expected = "com.hilotec.elexis.opendocument/anleitung_opendocument_1.png"
    [ "xxx/anleitung_opendocument_1.png",
      "com.hilotec.elexis.opendocument:anleitung_opendocument_1.png",
      "com.hilotec.elexis.opendocument/anleitung_opendocument_1.png",
      "com.hilotec.elexis.opendocument_anleitung_opendocument_1.png",
     ].each{ |variant|
      res = Elexis::Wiki::Interface.return_canonical_image_name("com.hilotec.elexis.opendocument", expected)
      expect(res).to eq expected

      res2 = Elexis::Wiki::Interface.return_canonical_image_name("com.hilotec.elexis.opendocument.feature.feature.group", expected)
      expect(res2).to eq expected
    }
  end

  it "should adapt correctly the image name" do
    wiki_file = File.join(@dataDir, 'ch.elexis.icpc', 'doc', 'test.mediawiki')
    expect(File.exists?(wiki_file)).to eq true
    before =  ['tag_one [[Image:ch.elexis.icpc:icpc1.png|image]]',
      'tag_two [[Image:ch.elexis.icpc:icpc2.png|image]]',
      'tag_three [[Image:icpc3.png|image]]',
      'tag_four [[Datei:ch.elexis.icpc:icpc4.png|image]]',
      'tag_five [[Datei:Ch.elexis.icpc:icpc5.png|image]]',
                ]
    original = IO.read(wiki_file)
    before.each{|string| expect(original).to include string }
    puts Dir.pwd
    Dir.chdir(@dataDir)
    puts Dir.pwd

    Elexis::Wiki::Interface.fix_image_locations(wiki_file, 'ch.elexis.icpc')
    after =['tag_one [[Image:ch.elexis.icpc/icpc1.png|image]]',
      'tag_two [[Image:ch.elexis.icpc/icpc2.png|image]]',
      'tag_three [[Image:ch.elexis.icpc/icpc3.png|image]]',
      'tag_four [[Datei:ch.elexis.icpc/icpc4.png|image]]',
      'tag_five [[Datei:ch.elexis.icpc/icpc5.png|image]]',
                ]
    changed = IO.read(wiki_file)
    after.each{|string| expect(changed).to include string }
  end
end

