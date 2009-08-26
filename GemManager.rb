#
#  GemManager.rb
#  GemMenu
#
#  Created by greg on 26/08/09.
#  Copyright (c) 2009 Grégoire Lejeune. All rights reserved.
#
# This file is part of GemMenu.
#
# GemMenu is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GemMenu is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GemMenu.  If not, see <http://www.gnu.org/licenses/>.


require 'osx/cocoa'
require 'Command'

class GemManager < OSX::NSObject

  ib_outlet :searchField
  ib_outlet :gemsList
  ib_outlet :progressIndicator
  ib_outlet :remoteSearch
  ib_outlet :installOrUninstallButton
  
  def initialize
    @gems = []
  end
  
  # -- Actions
  def changeRemoteOrLocal(sender)
    if @remoteSearch.state == OSX::NSOffState
      @installOrUninstallButton.setTitle(OSX::NSLocalizedString("Uninstall", "Uninstall"))
    else
      @installOrUninstallButton.setTitle(OSX::NSLocalizedString("Install", "Install"))
    end
    
    gemQuery()
  end
  ib_action :changeRemoteOrLocal
  
  def installOrUninstall(sender)
    if( @gemsList.selectedRow >= 0 )
      gemName = @gems[@gemsList.selectedRow]['name']
      gemVersion = @gems[@gemsList.selectedRow]['version']
      
      command = nil
      updateLocal = false
      if @remoteSearch.state == OSX::NSOffState
        command = "gem uninstall #{gemName} -v #{gemVersion}"
      else
        command = "gem install #{gemName} -v #{gemVersion} -y"
        updateLocal = true
      end
      
      OSX::NSLog(command)
      
      Command.execute( command, true )
      
      gemQuery() if updateLocal
    end
  end
  ib_action :installOrUninstall
  
  # -- DataSource
  def numberOfRowsInTableView(tableView)
    @gems.size
  end
  
  def tableView_objectValueForTableColumn_row(tableView, tableColumn, row)
    return @gems[row][tableColumn.identifier.to_s]
  end
  
  # -- Window deletages
  def windowShouldClose(win)
    win.orderOut(self)
    return false
  end
  
  # -- Search field delegate
  def control_textView_doCommandBySelector(control, textView, commandSelector)
    if commandSelector == "insertNewline:"
      gemQuery()
    end
    
    return false;
  end
  
  def gemQuery()
    return if @searchField.stringValue().chomp.size < 3
    
    Thread.new do
      @progressIndicator.setHidden(false)
      @progressIndicator.startAnimation(self)
    
      @searchField.setEnabled(false)
      @installOrUninstallButton.setEnabled(false)
      @remoteSearch.setEnabled(false)
  
      term = /#{@searchField.stringValue().chomp}/i
      local = @remoteSearch.state == OSX::NSOffState
      
      dep = Gem::Dependency.new term, Gem::Requirement.default
      
      if local
        specs = Gem.source_index.search dep
        spec_tuples = specs.map do |spec|
          [[spec.name, spec.version, spec.original_platform, spec], :local]
        end
      else
        begin
          fetcher = Gem::SpecFetcher.fetcher
          spec_tuples = fetcher.find_matching dep, false, false, false
        rescue => e
          OSX::NSRunAlertPanel("GemMenu", "Error: #{e.message}", "OK", nil, nil)
          spec_tuples = []
        end
      end

      version = Hash.new { |h,name| h[name] = [] }

      spec_tuples.each do |tuple, uri|
        version[tuple.first] << [tuple, uri] 
      end

      @gems = []
      
      version.each do |name, tuples|
        matching_tuples = tuples.sort_by do |(name, version,_),_|
          version
        end.reverse

        platforms = Hash.new { |h,version| h[version] = [] }

        tuples.map do |(name, version, platform,_),_|
          platforms[version] << platform if platform
        end

        detail_tuple = tuples.first

        spec = if detail_tuple.first.length == 4 then
                detail_tuple.first.last
              else
                uri = URI.parse detail_tuple.last
                Gem::SpecFetcher.fetcher.fetch_spec detail_tuple.first, uri
              end
  
        versions = tuples.map { |(name, version,_),_| version }.uniq.each do |version|
          @gems << {
            "name" => name,
            "plateforms" => platforms[version].uniq.join( ", " ),
            "version" => version.to_s,
            "summary" => spec.summary.split(/\n/).join( " " )
          }
        end
      end

      @gemsList.reloadData()
    
      @remoteSearch.setEnabled(true)
      @installOrUninstallButton.setEnabled(true)
      @searchField.setEnabled(true)

      @progressIndicator.stopAnimation(self)
      @progressIndicator.setHidden(true)
    end
  end
end
