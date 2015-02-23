//
//  AnalyzeController.swift
//  AnalyzeSTCPLogs
//
//  Created by Ian Farquharson on 12/02/2015.
//  Copyright (c) 2015 Ian Farquharson. All rights reserved.
//

import Cocoa
import Foundation
import AppKit


class AnalyzeController: NSViewController {
    
    
    var outDir:String = ""
    var startTime:NSDate = NSDate()
    
    @IBOutlet weak var sourcePath: NSTextField!


    @IBOutlet weak var progSpinner: NSProgressIndicator!
    
    @IBOutlet var progressText: NSTextView!
    
    @IBOutlet weak var startButton: NSButton!
    
    @IBAction func startPressed(sender: AnyObject) {
    

        progressText.insertText( "Starting\n")
        progSpinner.startAnimation(self)
        var parseValid:Bool = self.doParse(sourcePath.stringValue);
    }
    
    @IBAction func resetPressed(sender: AnyObject) {
        
        sourcePath.stringValue = ""
        progressText.string = "Select File"
        progSpinner.stopAnimation(self)
        startButton.enabled = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func awakeFromNib() {
        //println("View controller instance with view: \(self.view)")
        sourcePath.stringValue = ""
        progressText.string = "Select File\n"
        startButton.enabled = false
    }
    
    @IBAction func browseFile(sender: AnyObject) {

            self.startButton.enabled = false
        
            var openPanel = NSOpenPanel()
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.canCreateDirectories = false
            openPanel.canChooseFiles = true
        
            openPanel.beginWithCompletionHandler { (result) -> Void in
                if result == NSFileHandlingPanelOKButton {
                    var selectedURL:NSURL = openPanel.URL!
                    var path:String = selectedURL.path!

                    if path.hasSuffix(".out") == false
                    {
                        self.progressText.insertText("Selected \(path) without .out suffix, unsuitable file?\n")
                        self.sourcePath.stringValue = ""

                        return
                    }

                    self.sourcePath.stringValue = path
                    self.progressText.insertText("Selected \(path)\n")
                    
                    self.outDir = path.stringByDeletingLastPathComponent

                    self.progressText.insertText("Outputting to \(self.outDir)\n")
                    self.startButton.enabled = true
                    }
            }
    }
    func doParse (path:String) -> Bool {
        
        
        self.progressText.insertText("Parsing \(path)\n")
        self.progSpinner.startAnimation(self)
        
        //deadman counter
        
        let parseErrorCount = 100
        
        startTime = NSDate()
        
        // Set up parsing vars... 
        var YY: Int = 0
        var MM: Int = 0
        var DD: Int = 0
        var HH: Int = 0
        var MI: Int = 0
        var SS: Int = 0
        
        var SF: Double = 0.0
        var RF: Double = 0.0
        var SB: Double = 0.0
        var RB: Double = 0.0
        var RX: Double = 0.0
        
        var DN:NSString = ""
        var SP:NSString = ""
        var MA:NSString = ""
        var IP:NSString = ""
        var MAC:UInt64 = 0
        
        
        var deadManCount:Int = 0
        
        let dateSet:NSCharacterSet = NSCharacterSet(charactersInString:"-_: \n\r")

        let pctSet:NSCharacterSet = NSCharacterSet(charactersInString:"%/ \n\r")
    
        let MACSet:NSCharacterSet = NSCharacterSet(charactersInString:":")

        //Parser states, and the respective strings to look for
        
        enum Parser: Int {
            case    lookForTime, getTime,
                    lookForMAC, getMAC,
                    lookForInterface, getInterface,
                    lookForSpeed, getSpeed,
                    lookForMACSummary,
                    lookForTransFrames, getTransFrames,
                    lookForTransBytes, getTransBytes,
                    lookForRetransmit, getRetransmit,
                    lookForRecFrames, getRecFrames,
                    lookForRecBytes, getRecBytes,
                    lookForLostFrames, getLostFrames
            
            func text() -> String {
                switch self {
                case .lookForTime:
                    return "Timestamp:"

                case .lookForMAC:
                    return "MAC Address:"
                    
                case .lookForInterface:
                    return "Device Name:"
                    
                case .lookForSpeed:
                    return "Line Speed:"
                    
                case .lookForMACSummary:
                    return "MAC Summary:"
                    
                case .lookForTransFrames:
                    return "Transmitted frames         :"
                    
                case .lookForTransBytes:
                    return "Transmitted octets         :"
                    
                case .lookForRetransmit:
                    return "Retransmitted frames       :"
                    
                case .lookForRecFrames:
                    return "Received frames            :"
                    
                case .lookForRecBytes:
                    return "Received octets            :"
                    
                case .lookForLostFrames:
                    return "Total of lost frames       :"
                    
                default:
                    return ""
                }
            }
        }
        
        //Subroutines to manage deadman timer, for less typing
        
        func resetDMC()
        {
            deadManCount = 0
        }
        
        func checkDMC() -> Bool
        {
            return (++deadManCount >= parseErrorCount)
        }
        
        //Functions to manage parse types
        
        func scanForText(aScanner:NSScanner)
        {
            aScanner.charactersToBeSkipped = NSCharacterSet.whitespaceAndNewlineCharacterSet()
            
        }
    
        func scanForDate(aScanner:NSScanner)
        {
            aScanner.charactersToBeSkipped = dateSet
        }
        
        // might not need this one... 
        
        func scanForPct(aScanner:NSScanner)
        {
            aScanner.charactersToBeSkipped = pctSet
        }
        
        func scanForMAC(aScanner:NSScanner)
        {
            aScanner.charactersToBeSkipped = MACSet
        }
        
        var index:Int
        var outPath:String
        var error:NSError?
        var encoding:NSStringEncoding
    
        //read in the passed file.
        
        let data = NSString(contentsOfFile: path, encoding:NSUTF8StringEncoding, error: &error)
        
        
        
        if data == nil  {
            self.progressText.insertText("File load failed with error:\(error?.localizedDescription)\n")
            self.progSpinner.stopAnimation(self)
            return false
        }
        
        
        //Intitialize my scanner and whitespace sets
    
    
        var myScanner: NSScanner = NSScanner(string:data!)
    
        
        //Begin Parsing
        
        var state = Parser.lookForTime
        resetDMC()
        

        while myScanner.atEnd == false
        {

            if checkDMC() == true {
                self.progressText.insertText("Parser aborted after \(deadManCount) searches, last search was \"\(state.text())\"\n")
                self.progSpinner.stopAnimation(self)
                return false
                
            }
           
            switch(state)
            {
                
            case Parser.lookForTime:
                
                scanForText(myScanner)
                if myScanner.scanUpToString(state.text(), intoString: nil) {
                    
                    //found it, discard and advance
                    myScanner.scanString(state.text(), intoString:nil)
                    state = Parser.getTime
                    resetDMC()
                    break
                }
                
            case Parser.getTime:
                
                scanForDate(myScanner)
                if (myScanner.scanInteger (&YY) &&
                    myScanner.scanInteger (&MM) &&
                    myScanner.scanInteger (&DD) &&
                    myScanner.scanInteger (&HH) &&
                    myScanner.scanInteger (&MI) &&
                    myScanner.scanInteger (&SS) == true ) {
                        state = Parser.lookForMAC
                        resetDMC()
                        break
                }
                
            case Parser.lookForMAC:
                scanForText(myScanner)
                if myScanner.scanUpToString(state.text(), intoString: nil) {
                    myScanner.scanString(state.text(), intoString:nil)
                    state = Parser.getMAC
                    resetDMC()
                    break
                }
                
            case Parser.getMAC:
                
                scanForMAC(myScanner)
                
                if (myScanner.scanHexLongLong (&MAC)  == true ) {
                        state = Parser.lookForTime
                        resetDMC()
                        break
                }
                
            // Default case to keep the case statement happy, don't expect to hit it but...
            default:
                progressText.insertText("Parser hit default clause... Probably an error\n")
                progSpinner.stopAnimation(self)
                return false
            }
            scanForText(myScanner)
            
        }
        
        // Parser ended o.k. 
        
        return(true)
        
    }
  
}
