#
#  GemSources.rb
#  GemMenu
#
#  Created by greg on 24/08/09.
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

class GemSources < OSX::NSObject

  ib_outlet :sourceListe
  ib_outlet :textNewSource
  ib_outlet :gemExecutable
  ib_outlet :updateAsRoot

  def numberOfRowsInTableView(tableView)
    return Gem.sources.size
  end

  def tableView_objectValueForTableColumn_row(tableView, tableColumn, row)
    return Gem.sources[row]
  end
  
  def removeSource(sender)
    if( @sourceListe.selectedRow >= 0 )
      OSX::NSLog("Remove source ##{@sourceListe.selectedRow} : #{Gem.sources[@sourceListe.selectedRow]}")
      
      Command.execute( 
        "#{@gemExecutable.stringValue()} source -r #{Gem.sources[@sourceListe.selectedRow]}", 
        (@updateAsRoot.state == OSX::NSOnState)
      ) do 
        Gem.sources.delete Gem.sources[@sourceListe.selectedRow]
        @sourceListe.reloadData()
      end
    end
  end
  ib_action :removeSource

  def addSource(sender)
    OSX::NSLog("Add new source : #{@textNewSource.stringValue}")
    
    Command.execute( 
      "#{@gemExecutable.stringValue()} source -a #{@textNewSource.stringValue}",
      (@updateAsRoot.state == OSX::NSOnState)
    ) do
      Gem.sources << @textNewSource.stringValue
      @sourceListe.reloadData()
      @textNewSource.setStringValue("")
    end
  end
  ib_action :addSource
end
