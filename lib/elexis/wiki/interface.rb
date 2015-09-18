#encoding: utf-8

require 'eclipse/plugin'
require 'media_wiki'
require 'mediawiki_api'
require 'fileutils'
require 'open-uri'
require 'time'
require 'yaml'

module Elexis
  module Wiki
    ImagePrefix  = /Datei:|Image:/i

    class Interface
      attr_reader :user, :password, :wiki_url, :mw_gw, :mw_api

      private
        def load_config_file(wiki_url)
          if ENV['TRAVIS']
            @user = 'nobody'
            @password = 'nopassword'
            @mw_gw = MediaWiki::Gateway.new(@wiki_url)
            @mw_api = MediawikiApi::Client.new @wiki_url
          else
            possibleCfgs = ['/etc/elexis-wiki-interface/config.yml', File.join(Dir.pwd, 'config.yml'), ]
            possibleCfgs.each{ |cfg| @config_yml = cfg; break if File.exists?(cfg) }
            raise "need a config file #{possibleCfgs.join(' or ')} for wiki with user/password" unless File.exists?(@config_yml)
            yaml = YAML.load_file(@config_yml)
            @wiki_url = wiki_url
            @wiki_url ||= defined?(RSpec) ? yaml['test_wiki'] : yaml['wiki']
            @user = yaml['user'] if yaml
            @password = yaml['password'] if yaml
            @mw_gw = MediaWiki::Gateway.new(@wiki_url)
            @mw_gw.login(@user, @password)
            @mw_api = MediawikiApi::Client.new @wiki_url
            res = @mw_api.log_in(@user, @password)
          end
          puts "MediWiki #{@wiki_url} user #{@user} with password #{@password}" if $VERBOSE
          wiki_url
        end

      public

        def initialize(wiki_url=nil)
          load_config_file(wiki_url)
          $ws_errors = []
        end

        def images(page)
          @mw_gw.images(page)
        end

        def users
          @mw_gw.users
        end

        def contributions(username)
          @mw_gw.contributions(username)
        end

        def get(page)
          @mw_gw.get(page)
        end

        def create(page, content, options = {})
          @mw_api.create_page(page, content)
        end

        def edit(page, text)
          @mw_api.edit({:title => page, :text => text})
        end

        def delete(page, reason='')
          @mw_api.delete_page(page, reason)
        end

        def upload_image(filename, path, comment='', options = {})
          # fails with mediawiki 1.19 because of missing @tokens
          res = @mw_api.upload_image(filename, path, comment, options)
        end
        alias_method :upload, :upload_image

      def Interface.remove_image_ignoring_case(filename)
        files = Dir.glob(filename, File::FNM_CASEFOLD)
        return if files.size == 1
        files.each{
          |file|
            next if File.basename(file).eql?(File.basename(filename))
            cmd = "git rm -f #{file}"
            res = system(cmd)
        }
      end

      def wiki_json_timestamp_to_time(json, page_or_img)
        return nil unless json
        begin
          m = json.match(/timestamp['"]:['"]([^'"]+)/)
          return Time.parse(m[1]) if m
        end
        nil
      end

      # http://wiki.elexis.info/api.php?action=query&format=json&list=allimages&ailimit=5&aiprop=timestamp&aiprefix=Ch.elexis.notes:config.png&*
      def get_image_modification_name(image)
        short_image = image.sub(ImagePrefix, '')
        json_url = "#{@wiki_url}?action=query&format=json&list=allimages&ailimit=5&aiprop=timestamp&iiprop=url&aiprefix=#{short_image}"
        json = RestClient.get(json_url)
        wiki_json_timestamp_to_time(json, image)
      end

      # helper function, as mediawiki-gateway does not handle this situation correctly
      def download_image_file(destination, pageName, image)
        unless File.exist? destination
          # first search by pagename and imagename
          json_url = "#{@wiki_url}?action=query&format=json&list=allimages&ailimit=5&aiprefix=#{pageName}&aifrom=#{image.sub(ImagePrefix, '')}"
          json = RestClient.get(json_url)
          unless json
            puts "JSON: Could not fetch for image #{image} for #{pageName} using #{json_url}"
            return
          end
          begin
            answer = JSON.parse(json)
            image_url = nil
            image_url = answer['query'].first[1].first['url'] if answer['query'] and answer['query'].size >= 1 and answer['query'].first[1].size > 0
            unless image_url
              # as we did not find it search imagename only
              json_url = "#{@wiki_url}?action=query&format=json&list=allimages&ailimit=5&aifrom=#{image.sub(ImagePrefix, '')}"
              json = RestClient.get(json_url)
              if json
                answer = JSON.parse(json)
                image_url = answer['query'].first[1].first['url'] if answer['query'] and answer['query'].size >= 1 and answer['query'].first[1].size > 0
              end
            end
            if image_url
              m = /#{destination}/i.match(image_url)
              # destination = m[0] if m # Sometimes the filename is capitalized
              File.open(destination, 'w') do |file|
                file.write(open(image_url).read)
              end
              files = Dir.glob(destination, File::FNM_CASEFOLD)
              Interface.remove_image_ignoring_case(destination)
            else
              puts "skipping image #{image} for page #{pageName}"
            end
            rescue => e
              puts "JSON: Could not fetch for image #{image} for #{pageName} using #{json_url}"
              puts "      was '#{json}'"
              puts "      error was #{e.inspect}"
          end
        end
        puts "Downloaded image #{destination} #{File.size(destination)} bytes" if $VERBOSE and File.exists?(destination)
      end
    end
  end
end
