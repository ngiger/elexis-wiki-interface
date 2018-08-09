#encoding : utf-8
require 'spec_helper'

require "elexis/wiki/images"

describe 'Images' do
  NR_PICTURES = 24
  NR_ELEMS_IN_IMAGE_PATTERN = 3
  NR_ELEMS_IN_IMAGE_WITH_SLASH_PATTERN = 4

  before :all do
    @subdir = 'images'
    @originDir = File.expand_path(File.join(File.dirname(__FILE__), 'data', @subdir))
    @dataDir = File.expand_path(File.join(File.dirname(__FILE__), 'run', @subdir))
    FileUtils.rm_rf(File.expand_path(File.join(File.dirname(__FILE__), 'run')))
    FileUtils.makedirs(@dataDir)
    FileUtils.cp_r(@originDir, @dataDir, :preserve => true)
    @images = Elexis::Wiki::Images.new(@dataDir)
  end

  after :all do
#    FileUtils.rm_rf(@dataDir)
  end

  it "should refuse to change the image name in a mediawiki file when we find no corresponding image file" do
    wiki_file = File.join(@dataDir, @subdir, 'ch.elexis.icpc', 'doc', 'test2.mediawiki')
    old_picture_name = 'ch.elexis.icpc:icpc4.png'
    expect(IO.read(wiki_file)).to include old_picture_name
    expect(File.exist?(wiki_file)).to eq true
    expect { @images.change_image_name_in_mediawiki(wiki_file, old_picture_name, 'icpc_should_not_exist.png')}.to raise_error(RuntimeError, /Could not find image/)
  end

  it "should create the pictures.yml and .csv file" do
    expect(@images.yml).to eq File.join(@images.rootDir, 'pictures.yml')
    expect(@images.csv).to eq File.join(@images.rootDir, 'pictures.csv')
    expect(File.exist?(@images.yml)).to eq true
    expect(File.exist?(@images.csv)).to eq true
  end


  it "should read #{NR_PICTURES} pictures" do
    expect(@images.pictures.size).to eq NR_PICTURES
  end

  it "pictures.yml should contain some png" do
    content = IO.read(@images.yml)
    expect(content.index('doc/ch.elexis.icpc_icpc1.png')).not_to eq 0
    expect(content.index('doc/icpc1.png')).not_to eq 0
    expect(content.index('icpc6.png')).not_to eq 0
    expect(content.index('favicon_green.png')).not_to eq 0
  end

  it "should match picture names with a /" do
    res = Elexis::Wiki::ImageWithSlashPattern.match('[[File:At.medevit.elexis.dbcheck/dbcleaningui.png|frame|none]]')
    expect(res.size).to eq NR_ELEMS_IN_IMAGE_WITH_SLASH_PATTERN
    expect(res[2]).to eq 'At.medevit.elexis.dbcheck/'
    expect(res[3]).to eq 'dbcleaningui.png'
  end

  it "should match picture doc_de/settings_agenda-druck1.png" do
    res = Elexis::Wiki::ImageWithSlashPattern.match('[[File:doc_de/settings_agenda-druck1.png|image]]<br />')
    expect(res.size).to eq NR_ELEMS_IN_IMAGE_WITH_SLASH_PATTERN
    expect(res[2]).to eq 'doc_de/'
    expect(res[3]).to eq 'settings_agenda-druck1.png'
  end

  it "should match picture File:dbcleaningui.png" do
    res = Elexis::Wiki::ImagePattern.match('[[File:dbcleaningui.png|frame|none]]')
    expect(res.size).to eq NR_ELEMS_IN_IMAGE_PATTERN
    expect(res[2]).to eq 'dbcleaningui.png'
  end

  examples =  { 'doc_de/settings_agenda-druck1.png' => 'settings_agenda-druck1.png',
                'doc_de/settingsAgendaDruck1.png'   => 'settings_agenda_druck1.png',
                'Ch.elexis.privatrechnung/doc/privatrechnung-3.png' => 'privatrechnung-3.png',
                'CurabillWarning1.png'              => 'curabill_warning1.png',
                'ch.elexis.icpc/Icpc1.png'          => 'icpc-1.png',
                }
  examples.each{
    |picture_name, expected_result|
      it "should return correct get_small_name for #{picture_name}" do
        res = Elexis::Wiki::Images.get_small_name picture_name
        expect(res).to eq expected_result
      end
  }

  it "pictures.csv should contain some png" do
    content = IO.read(@images.csv)
    expect(content.index('icpc6.png')).not_to eq 0
    expect(content.index('favicon_green.png')).not_to eq 0
  end

  def check_rename(wiki_file, old_picture_name, new_picture_name, expected_new_line)
    @images.change_image_name_in_mediawiki(wiki_file, old_picture_name, new_picture_name)
    changed = IO.read(wiki_file)
    expect(changed).to include "tag_one"
    expect(changed).to include "tag_two"
    expect(changed).to include "tag_three"
    changed.index(new_picture_name)
    expect(changed).to include expected_new_line
  end

  describe 'get_name_with_project' do
    tests = {
      'elexis-3-base/ch.elexis.connect.reflotron.v2/doc/test.png' => 'reflotron-test.png',
      'elexis-3-base/ch.elexis.connect.reflotron.v2.feature/doc/test.png' => 'reflotron-test.png',
      'elexis-3-base/ch.elexis.laborimport.viollier.v2_test/doc/test.png' => 'viollier-test.png',
      'org.iatrix/doc/test.png' => 'iatrix-test.png',
      'org.iatrix.test/doc/test.png' => 'iatrix-test.png',
      'org.iatrix.feature/doc/test.png' => 'iatrix-test.png',
      'org.iatrix.tests/doc/test.png' => 'iatrix-test.png',
      'org.iatrix.tests/doc/test.jpg' => 'iatrix-test.jpg',
      'org.iatrix_tests/doc/test.gif' => 'iatrix-test.gif',
      'ch.elexis.connect.abxmicros/doc/abxmicros-kabel.png' => 'abxmicros-kabel.png',
      }
    tests.each {
      |path, expected|
      it "should return #{expected} for #{path}" do
        value = @images.get_name_with_project(path)
        expect(value).to eq expected
      end
    }
  end

  rename_tests = {
#     'Ch.elexis.icpc:Icpc2.png' => [ 'icpc2.png', 'tag_two [[File:icpc-2.png|image]]'],
     'Ch.elexis.icpc:icpc5.png' => [ 'icpc5.png', 'tag_frame_none [[File:icpc5.png|frame|none]]'],
     'ch.elexis.icpc:icpc5.png' => [ 'icpc5.png', 'tag_png [[File:icpc5.png|image]]<br />'],
     'Ch.elexis.icpc:icpc6.png' => [ 'elexis_logo.jpg', 'tag_jpg [[File:icpc6.png|image]]'],
     'Ch.elexis.icpc:icpc7.png' => [ 'disposan.gif', 'tag_gif [[File:icpc7.png|image]]'],
     'Ch.elexis.icpc/favicon_green.png' => [ 'favicon_green.png', 'tag_slash [[File:favicon_green.png|image]]<br />'],
    }
  rename_tests.each {
              |old_picture_name, params|
    it "should go work with #{params[1]}" do
      full_name =  File.join(@dataDir, @subdir, 'ch.elexis.icpc', 'doc', 'test2.mediawiki')
      check_rename(full_name, old_picture_name, params[0], params[1])
    end
  }

  it "should remove UTF-8 chars like <U+200E> after picture names" do
    wiki_file = File.join(@dataDir, @subdir, 'ch.elexis.icpc', 'doc', 'test2.mediawiki')
    expect(File.exist?(wiki_file)).to eq true
    old_picture_name = 'kabel.png'
    new_picture_name =  Elexis::Wiki::Images.get_small_name(old_picture_name)
    expect(IO.read(wiki_file)).to include old_picture_name
    @images.change_image_name_in_mediawiki(wiki_file, old_picture_name, new_picture_name)
    content = IO.read(wiki_file)
    expect(content).to include 'kabel.png]'
  end

  checks = {
    'at.medevit.elexis.swissmedic/fixmedikationaufruf.png'            => 'swissmedic',
    'at.medevit.elexis.swissmedic/doc/fixmedikationaufruf.png'        => 'swissmedic',
    'at.medevit.elexis.swissmedic/doc/images/fixmedikationaufruf.png' => 'swissmedic',
              }
  checks.each{
    |path, expected|
    it "should return correct project name  #{expected} for #{path}" do
      expect(Elexis::Wiki::Images.get_project_abbreviation(path)).to eq expected
    end
  }
  describe "determine_cleanup" do
    before(:all) do
      @images.determine_cleanup
    end

    it "should find duplicates" do
      expect(@images.duplicates.size).not_to eq 0
    end

    it "should find nr_single_sha" do
      expect(@images.nr_single_sha.size).not_to eq 0
    end

    it "should find to_short_names" do
      expect(@images.to_short_names.size).not_to eq 0
    end

    # now the failing ones
    it "should find same_name_but_differen_content" do
      # skip "No example yet"
      expect(@images.dup_non_identical.size).not_to eq 0
    end

    it "should find multiple_names" do
      expect(@images.multiple_names.size).not_to eq 0
    end
    it "should find short_and_sha_okay" do
      expect(@images.short_and_sha_okay.size).not_to eq 0
    end

    it "should find wrong_best_name" do
      expect(@images.wrong_best_name.size).to eq 0
    end

    it "should find new_best_name" do
      expect(@images.new_best_name.size).not_to eq 0
    end
  end
end


describe 'ImagesCleanup' do

  def setup_run
    @subdir = 'images'
    @originDir = File.expand_path(File.join(File.dirname(__FILE__), 'data', @subdir))
    @dataDir = File.expand_path(File.join(File.dirname(__FILE__), 'run'))
    FileUtils.rm_rf(File.expand_path(File.join(File.dirname(__FILE__), 'run')))
    FileUtils.makedirs(@dataDir)
    FileUtils.cp_r(@originDir, @dataDir, :preserve => true, :verbose => true)
    files =  Dir.glob("#{@dataDir}/**/*.png"); files.find{|x| /ch.elexis.icpc_icpc1.png/.match(x)}
    @images = Elexis::Wiki::Images.new(@dataDir)
  end

  before :all do
    setup_run
  end

  describe "execute_cleanup with git" do
    before(:all) do
      setup_run
      system("git init #{@dataDir}")
      @images.determine_cleanup
      @images.execute_cleanup(true)
    end

    it "should fix old names in" do
      wiki_file = File.join(@dataDir, @subdir, 'ch.elexis.agenda', 'doc', 'agenda.mediawiki')
      expect(File.exist?(wiki_file)).to eq true
      @images.cleanup_mediawikis
      content = IO.read(wiki_file)
      expect(content).to include 'tag_one [[File:agenda-2.png|image]]<br />'
      expect(content).to include 'tag_three [[File:agenda-2.png|image]]<br />'
      expect(content).to include 'tag_two [[File:agenda-2.png|frame|none]]<br />'
    end

    it "should remove pseudo UTF-8 chars like <U+200E>" do
      wiki_file =  File.join(@dataDir, @subdir, 'ch.elexis.icpc', 'doc', 'test2.mediawiki')
      content = IO.read(wiki_file)
      expect(File.exist?(wiki_file)).to eq true
      expect(/(<U\+\h\h\h\h>)/.match(content)).to be nil
    end

    it "should add icpc-8.png and icpc-1.png" do
      expect(@images.actions.index("git add -f images/ch.elexis.icpc/doc/icpc-1.png")).not_to eq nil
      expect(@images.actions.index("git add -f images/ch.elexis.icpc/doc/icpc1.png")).to eq nil
      expect(@images.actions.index("git add -f images/ch.elexis.icpc/doc/Icpc1.png")).to eq nil
      expect(@images.actions.index("git add Icpc8.png && git mv Icpc8.png icpc-8.png")).not_to eq nil
      expect(@images.actions.index("git add -f images/ch.elexis.icpc/doc/icpc8.png")).to eq nil
      expect(@images.actions.index("git add -f images/ch.elexis.icpc/doc/Icpc8.png")).to eq nil
    end

    it 'should not contain an picture with uppercase letter' do
      regexp = /git add -f images\/(?:[.\w]+\/)+(?:[a-z0-9]*)([A-Z])/
      @images.actions.each{
        |img|
          if m = regexp.match(img)
            puts "Found uppercase in #{img}"
            expect(m).to eq nil
      end
      }
    end

    it 'should add a "-" if the image name starts with the abbrev' do
      expect(@images.actions.index("git add -f images/ch.elexis.icpc/doc/icpc-1.png")).not_to eq nil
    end

  end

  describe "execute_cleanup" do
    before(:all) do
      setup_run
      @images.determine_cleanup
      @images.execute_cleanup
    end

    it "should change_image_name_in_mediawiki" do
      cmd = 'change_image_name_in_mediawiki test.mediawiki kabel.png icpc-kabel.png'
      expect(@images.actions.index(cmd) >= 0)
    end

    it "should remove obsolete symlinks" do
      cmd = 'rm Ch.elexis.notes'
      expect(@images.actions.index(cmd) >= 0)
    end


    it "should NOT mv medevit_inbox1.png" do
      cmd = 'medevit_inbox1.png'
      expect(@images.actions.index(cmd)).to eq nil
    end

    it "should mv Com.hilotec.elexis.opendocument_anleitung_opendocument_1.png to anleitung_opendocument_1.png" do
      cmd = 'mv Com.hilotec.elexis.opendocument_anleitung_opendocument_1.png anleitung_opendocument_1.png'
      expect(@images.actions.index(cmd) >= 0)
    end

    it "should find mv duplicate-images" do
      cmd = 'mv kabel.png icpc-kabel.png'
      expect(@images.actions.index(cmd) >= 0)
      @images.execute_cleanup
      cmd = 'mv kabel.png icpc-kabel.png'
      expect(@images.actions.index(cmd) >= 0)
    end

    it "should find remove old files" do
      cmd = 'rm -f ch.elexis.icpc_icpc1.png'
      files =  Dir.glob("#{@dataDir}/**/*.png"); 
      origins =  Dir.glob("#{@originDir}/**/*.png");
      if files.find{|x| /ch.elexis.icpc_icpc1.png/.match(x)}
        expect(@images.actions.index(cmd) >= 0)
      end
    end

    it "should find any files with ':' in their names" do
      search = "#{@images.rootDir}/**/*:*"
      files = Dir.glob(search)
      expect(files.size).to eq 0
    end
  end
end

