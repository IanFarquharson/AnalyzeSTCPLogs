//
//  AppDelegate.swift
//  AnalyzeSTCPLogs
//
//  Created by Ian Farquharson on 12/02/2015.
//  Copyright (c) 2015 Ian Farquharson. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // println("Application Delegate Called for Loading")
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    func applicationShouldTerminateAfterLastWindowClosed(_theApplication: NSApplication) -> Bool {
        return (true)
        // Single window, so we can quit fine if user closes this 
    }

}
