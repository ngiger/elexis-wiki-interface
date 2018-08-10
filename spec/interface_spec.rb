#encoding : utf-8
require 'spec_helper'

require "elexis/wiki/interface"

describe 'Wiki_Interface' do
  match_upload_result = /Success|Warning/i

  before(:all) do
    skip 'does not work under travis-ci' if ENV['TRAVIS']
    @if = Elexis::Wiki::Interface.new
    # expect(@if.wiki_url).to match /localhost/i # we don't want to test with a real wiki
    @test_image = "elexis_api_test.png"
    @test_image_file = File.join(File.join(File.dirname(__FILE__), 'data', 'push', 'elexis_api_test.png'))
    expect(File.exists?(@test_image_file))
    if false
    res = @if.upload_image(@test_image, @test_image_file, 'TestKommentar Niklaus', nil)
    expect(res)
    expect(res.data['result']).to match match_upload_result
    end
  end

  it "should be possible to if.upload an @test_image_file to path without ':' nor '/'" do
    expect(File.exists?(@test_image_file))
    skip "Niklaus does not know why we get sometimes an internal error and sometimes not"
    res = @if.upload("api_test2.png", @test_image_file, 'TestKommentar Niklaus')
    expect(res.class).to eq MediawikiApi::Response
    expect(res.data['result']).to match match_upload_result
    expect(res.data['warnings']['badfilename']).to eq nil
    expect(res.data['warnings']['duplicate']).to_not eq nil # we already if.uploaded via before(:all)
  end

  it "should be possible to if.upload an @test_image_file to a path with ':'" do
    expect(File.exists?(@test_image_file))
    skip("Don't know howto handle permissiondenied")
    res = @if.upload("api_test:api_test2.png", @test_image_file, 'TestKommentar Niklaus')
    expect(res.class).to eq MediawikiApi::Response
    expect(res.data['result']).to match match_upload_result
    expect(res.data['warnings']['badfilename']).to eq 'Api_test-api_test2.png'
    expect(res.data['warnings']['duplicate']).to_not eq nil # we already if.uploaded via before(:all)
  end

  it "should be possible to if.upload an @test_image_file to a path with '/'" do
    expect(File.exists?(@test_image_file))
    skip("Don't know howto handle permissiondenied")
    res = @if.upload("api_test/api_test2.png", @test_image_file, 'TestKommentar Niklaus')
    expect(res.class).to eq MediawikiApi::Response
    expect(res.data['result']).to match match_upload_result
    expect(res.data['warnings']['badfilename']).to eq 'Api_test2.png'
    expect(res.data['warnings']['duplicate']).to_not eq nil # we already if.uploaded via before(:all)
  end

  it "should return all images for icpc" do
    res = @if.images('Ch.elexis.icpc')
    expect(res.size).not_to eq 0
  end

  it "should return all images for icpc" do
    res = @if.images('At.medevit.medelexis.text.msword')
    expect(res.size).not_to eq 0
    res.each{|page| expect(page.index(' ')).to eq nil }
  end

  it "should be able to create, edit and delete a page" do
    test_page = 'api_test_page'
    first_content = 'Some dummy content. First try'
    second_content = 'Some dummy content. second try'
    # remove any laying old test_page if still
    @if.delete(test_page) if @if.get(test_page)
    expect(@if.get(test_page)).to eq nil
    res = @if.create(test_page, first_content, { :comment => 'dummy comment'})
    content = @if.get(test_page)
    expect(content.class).to eq String
    expect(content).to match first_content

    inhalt = @if.get(test_page)
    expect(inhalt).to eq first_content
    res = @if.edit(test_page, second_content)
    inhalt = @if.get(test_page)
    expect(inhalt.class).to eq String
    expect(inhalt).to eq second_content
    res = @if.delete(test_page)
    expect(res).to eq true
    inhalt = @if.get(test_page)
    expect(inhalt).to be_nil
  end

  it "should return mediawiki_text for icpc" do
    res = @if.get('Ch.elexis.icpc')
    expect(res.index('== Einführung ==')).not_to eq 0
    expect(res.index('ICPC-2, die *I*nternational *')).not_to eq 0
  end

  it "should download an image" do
    image = 'Elexis3.0_inst_1.jpg'
    destination = File.join(Dir::tmpdir, 'tst_picture.png')
    FileUtils.rm_f(destination, :verbose => false)
    res = @if.download_image_file(image, destination, 'ch.elexis.icpc')
    expect(res).to eq nil
    expect(File.exists?(destination)).to eq true
    expect(File.size(destination)).not_to eq 0
    FileUtils.rm_f(destination, :verbose => false)
  end


  it "should show all users" do
    wiki_users = @if.users
    puts "We have #{wiki_users.size} wiki users"
    expect wiki_users.size <= 50
    contribs = @if.contributions(wiki_users.first)
  end

  it "should download an image without a pagename" do
    dest = 'tst.png'
    FileUtils.rm_f(dest, :verbose => false)
    name = 'Swelab-kabel.png'
    res = @if.download_image_file(name, dest)
    expect(res).to eq nil
    expect(File.exist?(dest))
    res = @if.download_image_file(name)
    expect(File.size(dest)).to eq res.size
  end
end
