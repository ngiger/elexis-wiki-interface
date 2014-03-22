require 'media_wiki'
require 'fileutils'

module Elexis
  module Wiki
    module Interface
      class Workspace
        attr_reader :info, :views_missing_documentation, :perspectives_missing_documentation, :plugins_missing_documentation
        
        def initialize(dir, wiki = 'http://wiki.elexis.info/api.php')
          @wiki = wiki
          @info =  Eclipse::Workspace.new(dir)
          @info.parse_sub_dirs
          @info.show if $VERBOSE
          @views_missing_documentation        =[]
          @perspectives_missing_documentation =[]
          @plugins_missing_documentation      =[]
        end

        def pull
          @mw = MediaWiki::Gateway.new(@wiki)
          @info.plugins.each{
            |id, info|
              puts "Pulling for #{id}"
              pull_docs_views(info)
          }
#          pull_docs_perspectives
#          pull_docs_plugins
        end

        def perspectiveToPageName(perspective)
          
        end
        private
        def pull_docs_views(plugin)
          pp plugin
          pageName = plugin.id.capitalize
          content = @mw.get(pageName)
          out_name = File.join(@info.workspace_dir, plugin.id, 'doc', pageName + '.mediawiki')
          if content
            dirname = File.dirname(out_name)
            # puts "Dir #{dirname} #{File.directory?(dirname)}"
            FileUtils.makedirs(dirname) unless File.directory?(dirname)
            ausgabe = File.open(out_name, 'w+')
            # puts "content for #{plugin.id} ist #{content.inspect}"
            ausgabe.puts content
            ausgabe.close
          else
            @views_missing_documentation << plugin.id
          end
        end
       def pull_docs_perspectives
          @info.plugins.each{
            |id, plugin|
               next unless id.match(/icpc/i)
              pageName = id.capitalize
              content = @mw.get(pageName)
              out_name = File.join(@info.workspace_dir, id, 'doc', pageName + '.mediawiki')
              if content
                dirname = File.dirname(out_name)
                # puts "Dir #{dirname} #{File.directory?(dirname)}"
                FileUtils.makedirs(dirname) unless File.directory?(dirname)
                ausgabe = File.open(out_name, 'w+')
                # puts "content for #{id} ist #{content.inspect}"
                ausgabe.puts content
                ausgabe.close
            else
              @views_missing_documentation << id
            end
          }
        end
       def pull_docs_plugins(plugin)
          pageName = plugin.id.capitalize
          content = @mw.get(pageName)
          out_name = File.join(@info.workspace_dir, plugin.id, 'doc', pageName + '.mediawiki')
          if content
            dirname = File.dirname(out_name)
            # puts "Dir #{dirname} #{File.directory?(dirname)}"
            FileUtils.makedirs(dirname) unless File.directory?(dirname)
            ausgabe = File.open(out_name, 'w+')
            # puts "content for #{plugin.id} ist #{content.inspect}"
            ausgabe.puts content
            ausgabe.close
          else
            @plugins_missing_documentation << plugin.id
          end
        end
      end
      # Your code goes here...
    end
  end
end
