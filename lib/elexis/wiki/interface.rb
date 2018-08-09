#encoding: utf-8

require 'eclipse/plugin'
require 'mediawiki-butt'
require 'rest-client'
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
          else
            possibleCfgs = [File.join(Dir.pwd, 'config.yml'), '/etc/elexis-wiki-interface/config.yml', ]
            possibleCfgs.each{ |cfg| @config_yml = cfg; break if File.exists?(cfg) }
            raise "need a config file #{possibleCfgs.join(' or ')} for wiki with user/password" unless File.exists?(@config_yml)
            yaml = YAML.load_file(@config_yml)
            @wiki_url = wiki_url
            @wiki_url ||= defined?(RSpec) ? yaml['test_wiki'] : yaml['wiki']
            @user = yaml['user'] if yaml
            @password = yaml['password'] if yaml
            uri = URI(@wiki_url)
            @client = MediaWiki::Butt.new(@wiki_url)
            @client.login(@user, @password)
          end
        end

      public

        def initialize(wiki_url=nil)
          load_config_file(wiki_url)
          $ws_errors = []
        end

        def images(page)
          all =@client.get_all_images().collect{|x| x.gsub(' ','_') }
          all.find_all{|x| /#{page}:/i.match(x) }
        end

        def users
          @client.get_all_users
        end

        def contributions(username)
          @client.get_user_contributions(username)
        end

        def get(page)
          @client.get_text(page)
        end

        def create(page, content, options = {})
          @client.create_page(page, content)
        end

        def edit(page, text, comment = nil)
          if @client.get_text(page)
            @client.edit(page, text, {summary: comment})
          else
            @client.create_page(page, text, {summary: comment})
          end
        end

        def delete(page, reason='')
          @client.delete(page, reason)
        end

        def upload_image(filename, path, comment='', options = "ignorewarnings")
          # fails with mediawiki 1.19 because of missing @tokens
          res = @client.upload(path, filename)
        end
        alias_method :upload, :upload_image
        # alias_method :delete, :delete_page

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
      def download_image_file(image, destination = nil, pageName = nil)
        if not destination or not File.exist? destination
          # first search by pagename and imagename
          if pageName
            json_url = "#{@wiki_url}?action=query&format=json&list=allimages&ailimit=5&aiprefix=#{pageName}&aifrom=#{image.sub(ImagePrefix, '')}"
          else
            json_url = "#{@wiki_url}?action=query&format=json&list=allimages&ailimit=1&aifrom=#{image.sub(File.extname(image), '')}"
          end
          begin
            json = RestClient.get(json_url)
            unless json
              msg = "Could not fetch for image #{image} for #{pageName} using #{json_url}"
              puts "JSON: #{msg}"
              $ws_errors << msg
              return
            end
          rescue => e
            msg =  "download_image_file #{image} failed #{e}"
            puts msg
            puts e.backtrace.join("\n") if $VERBOSE
            $ws_errors << msg
            raise msg
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
            if image_url and /#{image}/i.match(image_url)
              return open(image_url).read unless destination
              File.open(destination, 'w') do |file|
                file.write(open(image_url).read)
              end
              files = Dir.glob(destination, File::FNM_CASEFOLD)
            else
              puts "skipping image #{image} for page #{pageName}" if $VERBOSE
            end
            rescue => e
              puts "JSON: Could not fetch for image #{image} for #{pageName} using #{json_url}"
              FileUtils.rm_f(image) if File.exists?(image) and File.size(image) == 0
              puts "      was '#{json}'"
              puts "      error was #{e.inspect}"
          end
        end
        puts "Downloaded image #{destination} #{File.size(destination)} bytes" if $VERBOSE and File.exists?(destination)
      end
    end
  end
end
