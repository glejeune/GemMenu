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

begin
  require 'rosxauth'
  @@__ROSXAUTH__ = true
rescue LoadError
  @@__ROSXAUTH__ = false
end

class GemMenu < OSX::NSObject
  # -- Ze Menu !
  ib_outlet :gemMenu
  ib_outlet :updateMenu
  ib_outlet :checkMenu
  
  
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
    @canCheck = true
    @canUpdate = true
  end
  
  def awakeFromNib
    @gemMenuImage = OSX::NSImage.imageNamed("menuImage.gif")
    @updateMenu.submenu.setAutoenablesItems(true)
    
    # -- Preferences
    # Load defaults
    userDefaultsValuesPath=OSX::NSBundle.mainBundle.pathForResource_ofType("UserDefaults", "plist")
    userDefaultsValuesDict=OSX::NSDictionary.dictionaryWithContentsOfFile(userDefaultsValuesPath)

    @userDefaultsPrefs = OSX::NSUserDefaults.standardUserDefaults
    @userDefaultsPrefs.registerDefaults(userDefaultsValuesDict)
    
    # Set
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
    @fireDateValue.setStringValue( 
      @timer.fireDate().descriptionWithCalendarFormat_timeZone_locale("%H:%M:%S", nil, OSX::NSUserDefaults.standardUserDefaults().dictionaryRepresentation())
    )

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
    
    # -- Warning for ROSXAuth
    if @@__ROSXAUTH__ == false
      OSX::NSRunAlertPanel("GemMenu", "You must install ROSXAuth if you want to be able to update your gems.\n\nOpen a term and run 'sudo gem install rosxauth'", "OK", nil, nil)
    end
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
    
    @canCheck = false
    @checkMenu.setEnabled(false)
    
    Thread.new do
      nbGems = 0
      strGemList = ""
      subMenu = @updateMenu.submenu

      # -- Search outdated Gems
      locals = Gem::SourceIndex.from_installed_gems
      
      # -- Remove all items
      @gemsItems.each do |item|
        subMenu.removeItem(item)
      end
      @gemsItems = []

      locals.outdated.sort.each do |name|
        local = locals.find_name(name).last

        dep = Gem::Dependency.new local.name, ">= #{local.version}"
        remotes = Gem::SpecFetcher.fetcher.fetch dep
        remote = remotes.last.first
      
        nbGems += 1

        dynamicItem = OSX::NSMenuItem.alloc.initWithTitle_action_keyEquivalent_("#{local.name} (#{local.version} < #{remote.version})", :doUpdate, "")
        strGemList << "\n#{local.name} (#{local.version} < #{remote.version})"
        dynamicItem.setEnabled(true)
        @gemsItems << dynamicItem
        subMenu.addItem(dynamicItem)
      end
    
      @updateMenu.setTitle("Updates (#{nbGems})")
      if @@__GROWL__ and @showGrowlNotifications.state == OSX::NSOnState and nbGems > 0
        @growl.notify('updates', 'GemMenu', "#{nbGems} updates found :\n#{strGemList}")
      end
      @checkMenu.setEnabled(true)
      @canCheck = true

      @fireDateValue.setStringValue( 
        @timer.fireDate().descriptionWithCalendarFormat_timeZone_locale("%H:%M:%S", nil, OSX::NSUserDefaults.standardUserDefaults().dictionaryRepresentation())
      )
    end
  end
  ib_action :check
  
  def setPrefsUpdateAsRoot(sender)
    @userDefaultsPrefs.setBool_forKey(@updateAsRoot.state == OSX::NSOnState, "UpdateAsRoot")
    @userDefaultsPrefs.synchronize
  end
  ib_action :setPrefsUpdateAsRoot
  
  def setPrefsGemExecutable(sender)
    puts "Change gem exec to #{@gemExecutable.stringValue}"
    @userDefaultsPrefs.setObject_forKey(@gemExecutable.stringValue, "GemExecutable")
    @userDefaultsPrefs.synchronize
  end
  ib_action :setPrefsGemExecutable
  
  def setPrefsUpdateInterval(sender)
    @timer.invalidate()
    @checkTime.setIntValue(@updateInterval.intValue())
    @timer = OSX::NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats( @checkTime.intValue * 60, self, :check, nil, true )
    @fireDateValue.setStringValue( 
      @timer.fireDate().descriptionWithCalendarFormat_timeZone_locale("%H:%M:%S", nil, OSX::NSUserDefaults.standardUserDefaults().dictionaryRepresentation())
    )
    
    @userDefaultsPrefs.setInteger_forKey(@updateInterval.intValue(), "UpdateInterval")
    @userDefaultsPrefs.synchronize
  end
  ib_action :setPrefsUpdateInterval
  
  def setPrefsShowGrowlNotifications(sender)
    @userDefaultsPrefs.setBool_forKey(@showGrowlNotifications.state == OSX::NSOnState, "ShowGrowlNotifications")
    @userDefaultsPrefs.synchronize
  end
  ib_action :setPrefsShowGrowlNotifications
  
  def doUpdate(sender)
    return unless @canUpdate
    return if @@__ROSXAUTH__ == false
    
    # -- Disable Check
    @canCheck = false
    
    # -- Disable Update
    @canUpdate = false
    
    # -- Initialize Authorizations
    autz = ROSXAuth.new()
    if( autz.auth == ROSXAuth::ErrAuthorizationSuccess and autz.auth? )
      Thread.new do
        output = autz.exec( "/usr/bin/sudo", [@gemExecutable.stringValue().to_s, "update", "-y" ] )
        if output.nil?
          OSX::NSRunCriticalAlertPanel("GemMenu", "Update faild!", "OK", nil, nil)
        else
          IO.for_fd( output ).each do |outtext|
            OSX::NSLog(outtext)
          end
        end
        
        @canUpdate = true
        @canCheck = true
        self.check(self)
      end
    else
      OSX::NSLog("Autorization update faild with status #{autz.auth}")
    end
  end
  
  # -- deletages
  
  def windowShouldClose(win)
    win.orderOut(self)
    return false
  end  
end
