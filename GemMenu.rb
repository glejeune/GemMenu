#
#  GemMenu.rb
#  GemMenu
#
#  Created by greg on 20/07/09.
#  Copyright (c) 2009 __MyCompanyName__. All rights reserved.
#

require 'osx/cocoa'

require 'rubygems'
require 'rubygems/source_index'

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
  
  
  # -- Update Windows
  ib_outlet :updateWindow
  
  # -- About Window
  ib_outlet :aboutWindow
  
  # -- Preference Window
  ib_outlet :prefWindow
  
  ib_outlet :checkTime
  ib_outlet :fireDateValue

  ib_outlet :updateAsRoot
  ib_outlet :showGrowlNotifications
  ib_outlet :gemExecutable  
  ib_outlet :updateInterval
  
  def initialize()
    @gemsItems = []
    @allItem = nil
    @canCheck = true
    @canUpdate = true
  end
  
  def awakeFromNib
    @gemMenuImage = OSX::NSImage.imageNamed("menuImage.gif")
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

    # -- Set the timer
    @timer = OSX::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats( @checkTime.intValue * 60, self, :check, nil, true )
    self.updateFireDateInPrefWindow()

    # -- Initialize Growl Notifications
    @growl = nil
    if @@__GROWL__
      @growl = Growl::Notifier.sharedInstance
      @growl.register('GemMenu', ['updates'])
    end
    
    # -- Initial check!
    self.check(self)
  end
  
  def applicationDidFinishLaunching( aNotification )
    # -- Display menu
    bar = OSX::NSStatusBar.systemStatusBar()
    @gemStatusBarItem = bar.statusItemWithLength(24)
    @gemStatusBarItem.setHighlightMode(true)
    @gemStatusBarItem.setMenu(@gemMenu)
    @gemStatusBarItem.setImage(@gemMenuImage)
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

      # Search outdated Gems
      locals = Gem::SourceIndex.from_installed_gems
      
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
          @allItem = OSX::NSMenuItem.alloc.initWithTitle_action_keyEquivalent("Update all", :updateAll, "")
          @allItem.setEnabled(true)
          @gemsItems << @allItem
          subMenu.addItem(@allItem)
        end

        # Add the gem in the Update submenu
        dynamicItem = OSX::NSMenuItem.alloc.initWithTitle_action_keyEquivalent("#{local.name} (#{local.version} < #{remote.version})", :doUpdate, "")
        strGemList << "\n#{local.name} (#{local.version} < #{remote.version})"
        dynamicItem.setEnabled(true)
        @gemsItems << dynamicItem
        subMenu.addItem(dynamicItem)
      end
    
      # Set the Update menu title
      @updateMenu.setTitle("Updates (#{nbGems})")
      
      # Send growl notification 
      if @@__GROWL__ and @showGrowlNotifications.state == OSX::NSOnState and nbGems > 0
        @growl.notify('updates', 'GemMenu', "#{nbGems} updates found :\n#{strGemList}")
      end
      OSX::NSLog("#{nbGems} updates found :\n#{strGemList}")
      
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
    @timer.invalidate()
    @checkTime.setIntValue(@updateInterval.intValue())
    @timer = OSX::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats( @checkTime.intValue * 60, self, :check, nil, true )
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
        @updateMenu.setTitle("Updates (0)")
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
        @updateMenu.setTitle("Updates (#{@gemsItems.size-1})")
    
        # Remove "Update all" item if there is no more gem to update
        if @gemsItems.size == 1
          @gemsItems.delete(@allItem)
          @updateMenu.submenu.removeItem(@allItem)
          @updateMenu.setTitle("Updates (0)")
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
    
    begin
      privileges = (@updateAsRoot.state == OSX::NSOnState)?" with administrator privileges":""
      cmd = "do shell script \"#{@gemExecutable.stringValue()} update#{gemToUpdate} -y\"#{privileges}"
      #cmd = "do shell script \"#{@gemExecutable.stringValue()} list#{gemToUpdate} -a\"#{privileges}"
      OSX::NSLog(cmd)
      script = OSX::NSAppleScript.alloc.initWithSource(cmd)
      errorInfo = OSX::OCObject.new
      data = script.executeAndReturnError(errorInfo)
      if data.nil?
        OSX::NSRunAlertPanel( "UPDATE ERROR: #{errorInfo.objectForKey(OSX::NSAppleScriptErrorMessage)}")
        rCod = false
      else
        OSX::NSLog(data.stringValue())
      end
    rescue => e
      OSX::NSLog(e.message)
    end

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
      @timer.fireDate().descriptionWithCalendarFormat_timeZone_locale("%H:%M:%S", nil, OSX::NSUserDefaults.standardUserDefaults().dictionaryRepresentation())
    )
  end
  
  # -- deletages
  def windowShouldClose(win)
    win.orderOut(self)
    return false
  end  
end
