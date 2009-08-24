#
#  About.rb
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

class About < OSX::NSObject
  ib_outlet :creditWebView
  ib_outlet :versionData

  def awakeFromNib
    # -- Load credits
    creditsPath = OSX::NSBundle.mainBundle().pathForResource_ofType("credits", "html")
    @creditWebView.mainFrame().loadRequest(OSX::NSURLRequest.requestWithURL(OSX::NSURL.fileURLWithPath(creditsPath)))
    
    # -- Load version
    @versionData.setStringValue( "v"+OSX::NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString")+
      " ("+OSX::NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleVersion")+")" )
  end

  # -- deletages
  def windowShouldClose(win)
    alpha = win.alphaValue
    while( win.alphaValue > 0.0 ) do
      win.setAlphaValue( win.alphaValue - 0.2 )
      sleep(0.05)
    end
    win.orderOut(self)
    win.setAlphaValue(alpha)
    return false
  end
  
#  def showGPL(sender)
#    OSX::NSWorkspace.sharedWorkspace().openURL(OSX::NSURL.alloc.initWithString("http://www.gnu.org/copyleft/gpl.html"))
#  end
#  ib_action :showGPL
end
