require 'eclipse/plugin'
require 'media_wiki'
require 'fileutils'
require 'open-uri'

module Elexis
  module Wiki
    module Interface
      class Workspace
        attr_reader :info, :mw, :wiki, :views_missing_documentation, :perspectives_missing_documentation, :plugins_missing_documentation
        def initialize(dir, wiki = 'http://wiki.elexis.info/api.php')
          possibleCfgs = ['/etc/elexis-wiki-interface/config.yml', File.join(Dir.pwd, 'config.yml'), ]
          possibleCfgs.each{ |cfg| @config_yml = cfg; break if File.exists?(cfg) }
          raise "need a config file #{possibleCfgs.join(' or ')} for wiki with user/password" unless File.exists?(@config_yml)
          yaml = YAML.load_file(@config_yml)
          @user = yaml['user']
          @password = yaml['password']
          @wiki = yaml['wiki']
          puts "MediWiki #{@wiki} user #{@user} with password #{@password}" if $VERBOSE
          @mw = MediaWiki::Gateway.new(@wiki)
          @info =  Eclipse::Workspace.new(dir)
          @info.parse_sub_dirs
          @info.show if $VERBOSE
          @views_missing_documentation        =[]
          @perspectives_missing_documentation =[]
          @plugins_missing_documentation      =[]
        end
        def show_missing(details = false)
          if views_missing_documentation.size and
              plugins_missing_documentation.size == 0 and
              perspectives_missing_documentation.size == 0
            puts "Eclipse-Workspace #{@info.workspace_dir} seems to have documented all views, plugins and perspectives"
          else
            puts "Eclipse-Workspace #{@info.workspace_dir} needs documenting "
            if views_missing_documentation.size > 0
              puts "  #{views_missing_documentation.size} views"
              puts "    #{views_missing_documentation.inspect}" if details
            end
            if plugins_missing_documentation.size > 0
              puts "  #{plugins_missing_documentation.size} plugins"
              puts "    #{plugins_missing_documentation.inspect}" if details
            end
            if perspectives_missing_documentation.size > 0
              puts "  #{perspectives_missing_documentation.size} perspectives"
              puts "    #{perspectives_missing_documentation.inspect}" if details
            end
          end
        end
        def push
          raise "must define wiki with user and password in #{@config_yml}" unless @user and @password and @wiki
          @mw.login(@user, @password)
          @info.plugins.each{
            |id,plugin|
              to_push = Dir.glob("#{plugin.jar_or_src}/doc/*.mediawiki")
              to_push.each{
                           |file|
                            my_new_content = File.new(file).read
                            to_verify = my_new_content.gsub(/\n+/,"\n").chomp
                            pagename = File.basename(file, '.mediawiki')
                            @mw.create(pagename, my_new_content,{:overwrite => true, :summary => "pushed by #{File.basename(__FILE__)}" })
                            got = @mw.get(pagename).gsub(/\n+/,"\n")
                            success = got == to_verify
                            puts "Failed to upload #{file} to #{pagename}" unless success
                       }
              if to_push.size > 0
            # upload also all *.png files
              files_to_push = Dir.glob("#{plugin.jar_or_src}/doc/*.png")
              files_to_push.each {
                                  |image|
                                 pp image
              @mw.upload(image)
                                 }
          end
          }
        end

        def pull
          @info.plugins.each{
            |id, info|
              puts "Pulling for #{id}" if $VERBOSE
              pull_docs_views(info)
              pull_docs_plugins(info)
              pull_docs_perspectives(info)
          }
          saved = Dir.pwd
        end

        def perspectiveToPageName(perspective)
          # http://wiki.elexis.info/P_Abrechnungen
          name = 'P_'+ perspective.id.gsub(' ', '')
          puts "perspectiveToPageName for #{perspective.inspect} is '#{name}'" if $VERBOSE
          name
        end
        def viewToPageName(plugin_id, view)
          # für ch.elexis.agenda.views.TagesView (= view.id)
          # http://wiki.elexis.info/ChElexisAgendaViewsTagesview
          # wurde unter http://wiki.elexis.info/Hauptseite ein Link Agenda (= view.name) angelegt.
          # evtl. sollten wir testen, ob dieser Link vorhanden ist
          # http://wiki.elexis.info/ChElexisIcpcViewsEpisodesview
          comps = view.id.split('.')
          pageName = comps[0..-2].collect{|x| x.capitalize}.join + 'Views'+view.id.split('.').last.capitalize
          puts "viewToPageName for #{plugin_id}/#{view.id} is #{pageName}" if $VERBOSE
          pageName
        end
        
        private
        def get_from_wiki_if_exists(plugin_id, pageName)
          content = @mw.get(pageName)
          out_dir  = File.join(@info.workspace_dir, plugin_id, 'doc')
          out_name = File.join(out_dir, pageName + '.mediawiki')
          if content
            dirname = File.dirname(out_name)
            FileUtils.makedirs(dirname) unless File.directory?(dirname)
            ausgabe = File.open(out_name, 'w+')
            ausgabe.puts content
            ausgabe.close
            @mw.images(pageName).each{
              |image|
                downloaded_image = File.join(out_dir, image.split(':')[1..-1].join(':'))
                unless File.exist? image
                  json_url = "#{@wiki}?action=query&list=allimages&ailimit=5&aiprop=url&format=json&aiprefix=#{image.split(':')[1..-1].join(':')}"
                  json = RestClient.get(json_url)
                  image_url = JSON.parse(json)['query'].first[1].first['url']
                  File.open(downloaded_image, 'w') do |file|
                    file.write(open(image_url).read)
                  end
                end
                puts "Downloaded image #{downloaded_image} #{File.size(downloaded_image)} bytes" if $VERBOSE
                break if defined?(RSpec) # speed up rspec
            }
          else
            puts "Could not fetch #{pageName} from #{@mw}" unless defined?(RSpec)
          end
          content
        end
        def pull_docs_views(plugin)
          id = plugin.symbolicName
          plugin.views.each{
            |id, view|
            pageName = viewToPageName(plugin.symbolicName, view)
            content = get_from_wiki_if_exists(plugin.symbolicName, pageName)
            @views_missing_documentation << pageName unless content
          }
        end
       def pull_docs_perspectives(plugin)
          id = plugin.symbolicName
          plugin.perspectives.each{
            |id, perspective|
            pageName = perspectiveToPageName(perspective)
            content = get_from_wiki_if_exists(plugin.symbolicName, pageName)
            @perspectives_missing_documentation << pageName unless content
          }
        end
        def pull_docs_plugins(plugin)
          id = plugin.symbolicName
          pageName = id.capitalize
          content = get_from_wiki_if_exists(plugin.symbolicName, pageName)
          @perspectives_missing_documentation << pageName unless content
        end
      end
    end
  end
end
