#
#  CmdExecute.rb
#  GemMenu
#
#  Created by greg on 24/08/09.
#  Copyright (c) 2009 Grégoire Lejeune. All rights reserved.
#
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

class Command < OSX::NSObject
  def self.execute(command, withRootPrivileges = false)
    rCod = true
    
    begin
      privileges = (withRootPrivileges)?" with administrator privileges":""
      cmd = "do shell script \"#{command}\"#{privileges}"
      OSX::NSLog(cmd)
      script = OSX::NSAppleScript.alloc.initWithSource(cmd)
      errorInfo = OSX::OCObject.new
      data = script.executeAndReturnError(errorInfo)
      if data.nil?
        OSX::NSRunAlertPanel("GemMenu", "Error: #{errorInfo.objectForKey(OSX::NSAppleScriptErrorMessage)}", "OK", nil, nil)
        OSX::NSLog("Error: #{errorInfo.objectForKey(OSX::NSAppleScriptErrorMessage)}")
        rCod = false
      else
        OSX::NSLog(data.stringValue())
      end
      
      yield() if block_given?
    rescue => e
      OSX::NSLog(e.message)
      rCod = false
    end
    
    return( rCod )
  end
end
