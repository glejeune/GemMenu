#
#  GemMenu.rb
#  GemMenu
#
#  Created by greg on 20/07/09.
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

OSX.require_framework 'WebKit'

require 'rubygems'
require 'rubygems/source_index'

require 'open-uri'

begin
  require 'growl'
  @@__GROWL__ = true
rescue LoadError
  @@__GROWL__ = false
end

class GemMenu < OSX::NSObject
  # -- Ze Menu !
  ib_outlet :gemMenu
  ib_outlet :updateMenu
  ib_outlet :checkMenu
  ib_outlet :quitMenu
  ib_outlet :rubygemsMenu
  
  # -- Rubygems Windows
  ib_outlet :rubygemsWindow
  
  # -- About Window
  ib_outlet :aboutWindow
  
  # -- Preference Window
  ib_outlet :prefWindow
  
  ib_outlet :generalPrefsView
  ib_outlet :rubygemsPrefView
  ib_outlet :sourcesPrefView
  
  ib_outlet :checkTime
  ib_outlet :fireDateValue

  ib_outlet :updateAsRoot
  ib_outlet :showGrowlNotifications
  ib_outlet :gemExecutable  
  ib_outlet :updateInterval
  
  ib_outlet :startAtLogin
  
  def initialize()
    @gemsItems = []
    @allItem = nil
    @canCheck = true
    @canUpdate = true
    @networkDown = false
  end
  
  def awakeFromNib
    @gemMenuImage = OSX::NSImage.imageNamed("menuImage.gif")
    @gemMenuImageA = [ 
      OSX::NSImage.imageNamed("menuImageA1.gif"),
      OSX::NSImage.imageNamed("menuImageA2.gif"),
      OSX::NSImage.imageNamed("menuImageA3.gif"),
      OSX::NSImage.imageNamed("menuImageA4.gif")
    ]
    @gemMenuImageNetworkDown = OSX::NSImage.imageNamed("menuImageNetworkDown.gif")
    @updateMenu.submenu.setAutoenablesItems(true)
    
    # -- Preferences
    # Load defaults preferences
    userDefaultsValuesPath=OSX::NSBundle.mainBundle.pathForResource_ofType("UserDefaults", "plist")
    userDefaultsValuesDict=OSX::NSDictionary.dictionaryWithContentsOfFile(userDefaultsValuesPath)

    @userDefaultsPrefs = OSX::NSUserDefaults.standardUserDefaults
    @userDefaultsPrefs.registerDefaults(userDefaultsValuesDict)
    
    # Get user preferences and initialize preference window
    prefUpdateAsRoot = @userDefaultsPrefs.boolForKey("UpdateAsRoot")
    @updateAsRoot.setState(prefUpdateAsRoot)
    
    prefUpdateInterval = @userDefaultsPrefs.integerForKey("UpdateInterval")
    @updateInterval.setIntValue(prefUpdateInterval)
    @checkTime.setIntValue(@updateInterval.intValue())

    prefGemExecutable = @userDefaultsPrefs.objectForKey("GemExecutable")
    @gemExecutable.setStringValue(prefGemExecutable)
    
    prefShowGrowlNotifications = @userDefaultsPrefs.boolForKey("ShowGrowlNotifications")
    @showGrowlNotifications.setState(prefShowGrowlNotifications)
    
    prefStartAtLogin = @userDefaultsPrefs.boolForKey("StartAtLogin")
    @startAtLogin.setState(prefStartAtLogin)

    # -- Set the check timer
    @checkTimer = OSX::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats( @checkTime.intValue * 60, self, :check, nil, true )
    self.updateFireDateInPrefWindow()

    # -- Initialize Growl Notifications
    @growl = nil
    if @@__GROWL__
      @growl = Growl::Notifier.sharedInstance
      @growl.register('GemMenu', ['updates'])
    end    
  end
  
  def applicationDidFinishLaunching( aNotification )
    # -- Display menu
    bar = OSX::NSStatusBar.systemStatusBar()
    @gemStatusBarItem = bar.statusItemWithLength(24)
    @gemStatusBarItem.setHighlightMode(true)
    @gemStatusBarItem.setMenu(@gemMenu)
    self.setDefaultMenuImage() #@gemStatusBarItem.setImage(@gemMenuImage)
    
    # -- Set the network timer
    self.checkNetwork(self)
    @networkTimer = OSX::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats( 60, self, :checkNetwork, nil, true )

    # -- Initial check!
    self.check(self)
  end
  
  # Actions !
  def quit( sender )
    OSX::NSApp.terminate(self)
  end
  ib_action :quit
  
  def about( sender )
    @aboutWindow.makeKeyAndOrderFront(self)
  end
  ib_action :about
  
  def rubygems( sender )
    @rubygemsWindow.makeKeyAndOrderFront(self)
  end
  ib_action :rubygems
  
  def preferences(sender)
    @prefWindow.makeKeyAndOrderFront(self)
  end
  ib_action :preferences
  
  def check(sender)
    return unless @canCheck
    
    Thread.new do
      # Number of gems found
      nbGems = 0
      # String list of gems (for Growl)
      strGemList = ""
      # Update submenu
      subMenu = @updateMenu.submenu

      # Disable "Check now!" Menu
      @canCheck = false
      @checkMenu.setEnabled(false)
      
      # Disable "Update" Menu
      @canUpdate = false
      @updateMenu.setEnabled(false)

      # Start menu image animation
      animationTimer = OSX::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats( 0.3, self, :setAnimationMenuImage, nil, true )
      # self.setAnimationMenuImage(self)

      # Search outdated Gems
      OSX::NSLog("Search outdated Gems")
      locals = Gem::SourceIndex.from_installed_gems
      OSX::NSLog("Update menu...")
      
      # Remove all items in the Update sub menu
      @gemsItems.each do |item|
        subMenu.removeItem(item)
      end
      @gemsItems = []

      # Update "Updates" menu
      locals.outdated.sort.each do |name|
        local = locals.find_name(name).last

        dep = Gem::Dependency.new local.name, ">= #{local.version}"
        remotes = Gem::SpecFetcher.fetcher.fetch dep
        remote = remotes.last.first
      
        nbGems += 1
        
        # We add the "Update all" menu
        if nbGems == 1
          OSX::NSLog("Add `Update all' menu item")
          @allItem = OSX::NSMenuItem.alloc.initWithTitle_action_keyEquivalent(OSX::NSLocalizedString("Update all", "Update all"), :updateAll, "")
          @allItem.setEnabled(true)
          @gemsItems << @allItem
          subMenu.addItem(@allItem)
        end

        # Add the gem in the Update submenu
        OSX::NSLog("Add `#{local.name} (#{local.version} < #{remote.version})' menu item")
        dynamicItem = OSX::NSMenuItem.alloc.initWithTitle_action_keyEquivalent("#{local.name} (#{local.version} < #{remote.version})", :doUpdate, "")
        strGemList << "\n#{local.name} (#{local.version} < #{remote.version})"
        dynamicItem.setEnabled(true)
        @gemsItems << dynamicItem
        subMenu.addItem(dynamicItem)
      end
    
      # Set the Update menu title
      @updateMenu.setTitle(OSX::NSLocalizedString("Updates", "Updates")+" (#{nbGems})")
      
      # Stop menu image animation
      animationTimer.invalidate()
      self.setDefaultMenuImage()
      
      # Stop menu image animation
      animationTimer.invalidate()
      self.setDefaultMenuImage()
      
      # Send growl notification 
      if @@__GROWL__ and @showGrowlNotifications.state == OSX::NSOnState and nbGems > 0
        @growl.notify('updates', 'GemMenu', "#{nbGems} "+OSX::NSLocalizedString("updates found", "updates found")+" :\n#{strGemList}")
      end
      
      # Enable "Check now!" Menu
      @canCheck = true
      @checkMenu.setEnabled(true)
      
      # Enable "Update" Menu
      @canUpdate = true
      @updateMenu.setEnabled(true)

      # Update fire date value in the preference Window
      self.updateFireDateInPrefWindow()
    end
  end
  ib_action :check
  
  # -- Preferences
  
  def showRubyGemsPrefs(sender)    
    @rubygemsPrefView.setHidden(false)
    @sourcesPrefView.setHidden(true)
    @generalPrefsView.setHidden(true)
  end
  ib_action :showRubyGemsPrefs
  
  def showGeneralPrefs(sender)    
    @rubygemsPrefView.setHidden(true)
    @sourcesPrefView.setHidden(true)
    @generalPrefsView.setHidden(false)
  end
  ib_action :showGeneralPrefs
  
  def showSourcesPrefs(sender)
    @rubygemsPrefView.setHidden(true)
    @sourcesPrefView.setHidden(false)
    @generalPrefsView.setHidden(true)
  end
  ib_action :showSourcesPrefs
  
  # -- Preferences actions
  
  def setPrefsUpdateAsRoot(sender)
    @userDefaultsPrefs.setBool_forKey(@updateAsRoot.state == OSX::NSOnState, "UpdateAsRoot")
    @userDefaultsPrefs.synchronize
  end
  ib_action :setPrefsUpdateAsRoot
  
  def setPrefsGemExecutable(sender)
    @userDefaultsPrefs.setObject_forKey(@gemExecutable.stringValue, "GemExecutable")
    @userDefaultsPrefs.synchronize
  end
  ib_action :setPrefsGemExecutable
  
  def setPrefsUpdateInterval(sender)
    @checkTimer.invalidate()
    @checkTime.setIntValue(@updateInterval.intValue())
    @checkTimer = OSX::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats( @checkTime.intValue * 60, self, :check, nil, true )
    self.updateFireDateInPrefWindow()
    
    @userDefaultsPrefs.setInteger_forKey(@updateInterval.intValue(), "UpdateInterval")
    @userDefaultsPrefs.synchronize
  end
  ib_action :setPrefsUpdateInterval
  
  def setPrefsShowGrowlNotifications(sender)
    @userDefaultsPrefs.setBool_forKey(@showGrowlNotifications.state == OSX::NSOnState, "ShowGrowlNotifications")
    @userDefaultsPrefs.synchronize
  end
  ib_action :setPrefsShowGrowlNotifications
  
  def setPrefsStartAtLogin(sender)
    @userDefaultsPrefs.setBool_forKey(@startAtLogin.state == OSX::NSOnState, "StartAtLogin")
    @userDefaultsPrefs.synchronize
    
    myDict = OSX::NSMutableDictionary.alloc.init()
    myDict.setObject_forKey(false, "Hide")
    myDict.setObject_forKey(OSX::NSBundle.mainBundle().bundlePath(), "Path")
    
    defaults = OSX::NSUserDefaults.alloc.init()
    defaults.addSuiteNamed("loginwindow")
    
    loginItems = OSX::NSMutableArray.arrayWithArray(defaults.persistentDomainForName("loginwindow").objectForKey("AutoLaunchedApplicationDictionary"))
        
    if @startAtLogin.state == OSX::NSOnState
      OSX::NSLog("GemMenu start at login...")
      loginItems.addObject(myDict)
    else
      OSX::NSLog("GemMenu don't start at login...")
      loginItems.removeObject(myDict)
    end
    
    newLoginDefaults = OSX::NSMutableDictionary.dictionaryWithDictionary(defaults.persistentDomainForName("loginwindow"))
    newLoginDefaults.setObject_forKey(loginItems, "AutoLaunchedApplicationDictionary")
  	defaults.setPersistentDomain_forName(newLoginDefaults, "loginwindow")
    defaults.synchronize()
  end
  ib_action :setPrefsStartAtLogin
  
  # -- Action for "Update all"
  def updateAll(sender)
    return if @canUpdate == false

    # Initialize authorizations
    OSX::NSLog( "Update all gems..." )
    Thread.new do
      if self.gemUpdate(nil)
        # Update "Update" submenu
        @gemsItems.each do |item|
          @updateMenu.submenu.removeItem(item)
        end
        @updateMenu.setTitle(OSX::NSLocalizedString("Updates", "Updates")+" (0)")
        @gemsItems = []
      end
    end
  end
  
  # -- Action for update
  def doUpdate(sender)
    return if @canUpdate == false
    
    # Initialize authorizations
    Thread.new do
      if self.gemUpdate(sender)
        # Update "Update" submenu
        @gemsItems.delete(sender)
        @updateMenu.submenu.removeItem(sender)
        @updateMenu.setTitle(OSX::NSLocalizedString("Updates", "Updates")+" (#{@gemsItems.size-1})")
    
        # Remove "Update all" item if there is no more gem to update
        if @gemsItems.size == 1
          @gemsItems.delete(@allItem)
          @updateMenu.submenu.removeItem(@allItem)
          @updateMenu.setTitle(OSX::NSLocalizedString("Updates", "Updates")+" (0)")
        end
      end
    end
  end
  
  # -- Gem update 
  # gem is a NSMenuItem or nil
  def gemUpdate(gem)
    rCod = true
    # Disable "Check Now!" Menu
    @canCheck = false
    @checkMenu.setEnabled(false)
    
    # Disable "Updates" menu
    @canUpdate = false
    @updateMenu.setEnabled(false)
    
    # Disable "Quit GemMenu" menu
    @quitMenu.setEnabled(false)
  
    # Get gem name
    gemToUpdate = (gem.nil?)?"":" "+gem.title.gsub( /\(.*/, "" ).strip
    OSX::NSLog( "Update#{gemToUpdate}..." )
    
    rCod = Command.execute( 
      "#{@gemExecutable.stringValue()} update#{gemToUpdate} -y",
      (@updateAsRoot.state == OSX::NSOnState)
    )

    # Enable "Check Now!" Menu
    @canCheck = true
    @checkMenu.setEnabled(true)
    
    # Enable "Updates" menu
    @canUpdate = true
    @updateMenu.setEnabled(true)
    
    # Enable "Quit GemMenu" menu
    @quitMenu.setEnabled(true)
    
    return rCod
  end
  
  def updateFireDateInPrefWindow
    @fireDateValue.setStringValue( 
      @checkTimer.fireDate().descriptionWithCalendarFormat_timeZone_locale("%H:%M:%S", nil, OSX::NSUserDefaults.standardUserDefaults().dictionaryRepresentation())
    )
  end
  
  # -- deletages
  def windowShouldClose(win)
    win.orderOut(self)
    return false
  end
  
  # -- Image animation
  def setAnimationMenuImage(sender)
    img = @gemMenuImageA.push( @gemMenuImageA.shift )[-1]
    @gemStatusBarItem.setImage(img)
  end
  def setDefaultMenuImage
    @gemStatusBarItem.setImage(@gemMenuImage)
  end
  
  # -- check network
  def checkNetwork(sender)
    networkDown = false
    begin
      open( "http://www.google.com" )
    rescue => e
      OSX::NSLog(e.message)
      networkDown = true
    end
    
    if networkDown and @networkDown == false
      OSX::NSLog("Network is down")
      
      # Change menu icon
      @gemStatusBarItem.setImage(@gemMenuImageNetworkDown)
      
      # Disable "Check Now!" Menu
      @canCheck = false
      @checkMenu.setEnabled(false)
    
      # Disable "Updates" menu
      @canUpdate = false
      @updateMenu.setEnabled(false)    
    elsif @networkDown == true
      OSX::NSLog("Network is up")
      
      # Change menu icon
      @gemStatusBarItem.setImage(@gemMenuImage)
      
      # Disable "Check Now!" Menu
      @canCheck = true
      @checkMenu.setEnabled(true)
    
      # Disable "Updates" menu
      @canUpdate = true
      @updateMenu.setEnabled(true)
      
      # check
      # self.check(self)
    end
    
    @networkDown = networkDown
  end  
end
