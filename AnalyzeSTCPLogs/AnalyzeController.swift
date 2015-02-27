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
    
    var devNames = NSMutableArray()
    var data = NSMutableArray()
    var interfaceList = NSMutableArray()
    
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
        
        var TF: Double = 0.0
        var RF: Double = 0.0
        var TB: Double = 0.0
        var RB: Double = 0.0
        var RX: Double = 0.0
        var LF: Double = 0.0
        
        var DN:NSString?
        var SP:NSString?
        var MA:NSString?
        var IP:NSString?

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
                    lookForLostFrames, getLostFrames,
                    addSample,
                    lookForSampleTermination
            
            func text() -> String {
                switch self {
                case .lookForTime:
                    return "Timestamp:"

                case .lookForMAC:
                    return "MAC Address:"
                    
                case .lookForInterface:
                    return "Device Name:"
                    
                case .lookForSpeed:
                    return "Line Speed :"
                    
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
                case .lookForSampleTermination:
                    return "==================================="
                    
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
        
        func findName(aName:String) -> Int
        {
            var index:Int = devNames.indexOfObject(aName)

            if index != NSNotFound
            {
                return (index)
            }
            else
            {
                devNames.addObject(aName)
                self.progressText.insertText("Found \(aName)\n")
                
                var newInterface = interface()

                newInterface.MAC = MA!
                newInterface.speed = SP!
                newInterface.deviceName = aName
                
                interfaceList.addObject(newInterface)
                    
                return devNames.count
            }
            
        }
        
        func rateAsString (nowCount:Double, prevCount:Double, interval:Int) -> String
        {
            if interval == 0 {
                return "div/0 error"
            }
            else {
                var retVal = (nowCount - prevCount) / Double(interval)
                
                return ( String(format:"%.2f", (nowCount - prevCount) / Double(interval)))
                
                //return ( String(format:"%.2f", retVal ))
                
            }
        }
        
        var index:Int
        var outPath:String
        var error:NSError?
        var encoding:NSStringEncoding
    
        //read in the passed file.
        
        let dataRead = NSString(contentsOfFile: path, encoding:NSUTF8StringEncoding, error: &error)
        
        if dataRead == nil  {
            self.progressText.insertText("File load failed with error:\(error?.localizedDescription)\n")
            self.progSpinner.stopAnimation(self)
            return false
        }
        
        
        //Intitialize my scanner and whitespace sets
    
    
        var myScanner: NSScanner = NSScanner(string:dataRead!)
    
        
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
                
                if myScanner.scanUpToCharactersFromSet (NSCharacterSet.newlineCharacterSet(), intoString:&MA) {
                        resetDMC()
                        state = Parser.lookForInterface
                        break
                }
                
            case Parser.lookForInterface:
                
                scanForText(myScanner)
                if myScanner.scanString(state.text(), intoString:nil) {
                    state = Parser.getInterface
                    resetDMC()
                    break
                }
                
            case Parser.getInterface:
                
                if myScanner.scanUpToCharactersFromSet (NSCharacterSet.newlineCharacterSet(), intoString:&DN) {
                    resetDMC()
                    state = Parser.lookForSpeed
                    break
                }
            case Parser.lookForSpeed:
                if myScanner.scanString(state.text(), intoString:nil) {
                    state = Parser.getSpeed
                    resetDMC()
                    break
                }
                
            case Parser.getSpeed:
                if myScanner.scanUpToCharactersFromSet (NSCharacterSet.newlineCharacterSet(), intoString:&SP) {
                    resetDMC()
                    state = Parser.lookForMACSummary
                    break
                }
                
            case Parser.lookForMACSummary:
                scanForText(myScanner)
                if myScanner.scanUpToString(state.text(), intoString: nil) {
                    myScanner.scanString(state.text(), intoString:nil)
                    state = Parser.lookForTransFrames
                    resetDMC()
                    break
                }
                
            case Parser.lookForTransFrames:
                
                if  myScanner.scanString(state.text(), intoString:nil) {
                    state = Parser.getTransFrames
                    resetDMC()
                    break
                }
                
            case Parser.getTransFrames:
                
                if (myScanner.scanDouble (&TF) == true ) {
                        state = Parser.lookForTransBytes
                        resetDMC()
                        break
                }
                
            case Parser.lookForTransBytes:
                
                if  myScanner.scanString(state.text(), intoString:nil) {
                    state = Parser.getTransBytes
                    resetDMC()
                    break
                }
                
            case Parser.getTransBytes:
                
                if (myScanner.scanDouble (&TB) == true ) {
                    state = Parser.lookForRetransmit
                    resetDMC()
                    break
                }
                
            case Parser.lookForRetransmit:
                
                if  myScanner.scanString(state.text(), intoString:nil) {
                    state = Parser.getRetransmit
                    resetDMC()
                    break
                }
                
            case Parser.getRetransmit:
                
                if (myScanner.scanDouble (&RX) == true ) {
                    state = Parser.lookForRecFrames
                    resetDMC()
                    break
                }
                
            case Parser.lookForRecFrames:
                
                if  myScanner.scanString(state.text(), intoString:nil) {
                    state = Parser.getRecFrames
                    resetDMC()
                    break
                }
                
            case Parser.getRecFrames:
                
                if (myScanner.scanDouble (&RF) == true ) {
                    state = Parser.lookForRecBytes
                    resetDMC()
                    break
                }
            case Parser.lookForRecBytes:
                
                if  myScanner.scanString(state.text(), intoString:nil) {
                    state = Parser.getRecBytes
                    resetDMC()
                    break
                }
                
            case Parser.getRecBytes:
                
                if (myScanner.scanDouble (&RB) == true ) {
                    state = Parser.lookForLostFrames
                    resetDMC()
                    break
                }
                
            case Parser.lookForLostFrames:
                
                if  myScanner.scanString(state.text(), intoString:nil) {
                    state = Parser.getLostFrames
                    resetDMC()
                    break
                }
                
            case Parser.getLostFrames:
                
                if (myScanner.scanDouble (&LF) == true ) {
                    state = Parser.addSample
                    resetDMC()
                    break
                }
                
            case Parser.addSample:
                
                var thisEntry = netSample()
                var list:NSMutableArray
                
                thisEntry.date = String(format:"%02d/%02d/%02d",YY,MM,DD)
                thisEntry.time = String(format:"%02d:%02d:%02d",HH,MI,SS)
                
                var comps = NSDateComponents()
                comps.year = YY
                comps.month = MM
                comps.day = DD
                comps.hour = HH
                comps.minute = MI
                comps.second = SS
                
                thisEntry.absTime = NSCalendar.currentCalendar().dateFromComponents(comps)!
                
                thisEntry.sentBytes = TB
                thisEntry.sentFrames = TF
                thisEntry.recvBytes = RB
                thisEntry.recvFrames = RF
                thisEntry.reXmit = RX
                thisEntry.lostFrames = LF

                var uniqueName:String = DN! + "_" + MA!
                
                var devIndex = findName(uniqueName)
                
                if (devIndex > data.count)
                {
                    list = NSMutableArray()
                    data.addObject(list)
                }
                else
                {
                    list = data.objectAtIndex(devIndex) as NSMutableArray
                }
                
                list.addObject(thisEntry)
                
                //So we might next have another device, or the end of the sample
                //Save current position
                var currPos = myScanner.scanLocation
                
                state = Parser.lookForMAC
                var foundMac = myScanner.scanUpToString(state.text(), intoString:nil)
                var macPos = myScanner.scanLocation
                
                //reset context... 
                myScanner.scanLocation = currPos
                
                state = Parser.lookForSampleTermination
                var foundTerm  = myScanner.scanUpToString(state.text(), intoString:nil)
                var termPos = myScanner.scanLocation
                
                if foundMac && foundTerm == true {
                    if macPos < termPos {
                        state = Parser.lookForMAC
                    }
                    else {
                        state = Parser.lookForTime
                    }
                }
                else {
                    // Won't find a terminator in last sample...
                    state = Parser.lookForMAC
                    }
                
                    //Back up to where we were... 
                
                    myScanner.scanLocation = currPos

                resetDMC()
                break

            // Default case to keep the case statement happy, don't expect to hit it but...
            default:
                progressText.insertText("Parser hit default clause... Probably an error\n")
                progSpinner.stopAnimation(self)
                return false
            }
            
        }
        
        // Parser ended o.k. 
        self.progressText.insertText("Parser Completed\n")
        
        let elapsed = NSDate().timeIntervalSinceDate (startTime)
        
        var outString = String(format:"Seconds Elapsed %.2f\n",NSDate().timeIntervalSinceDate (startTime))
        
        self.progressText.insertText(outString)
        
        self.progressText.insertText("Constructing Output\n")
        
        for dev:Int in 0...data.count-1  { //Go thru the interfaces found
            
            var outputData:String = "Date,Time,Device,Speed,SendBytes/s,RecvBytes/s,SendFrames/s,RecvFrames/s,ReTrans/s,LostFrame/s\n"
            
            var list:NSMutableArray = data.objectAtIndex(dev) as NSMutableArray  //get the sample list
            var thisInterface:interface = interfaceList.objectAtIndex(dev) as interface
            
            for sample:Int in 1...list.count-1 { //starts at sample 1 as we will delta N from N-1
                
                var thisSample:netSample = list.objectAtIndex(sample) as netSample
                var prevSample:netSample = list.objectAtIndex(sample - 1) as netSample
                
                var seconds = Int(thisSample.absTime.timeIntervalSinceDate(prevSample.absTime))
                
                outputData = outputData + thisSample.date + ","
                outputData = outputData + thisSample.time + ","
                outputData = outputData + thisInterface.deviceName + ","
                outputData = outputData + thisInterface.speed + ","
                
                outputData = outputData + rateAsString(thisSample.sentBytes, prevSample.sentBytes, seconds) + ","
                outputData = outputData + rateAsString(thisSample.recvBytes, prevSample.recvBytes, seconds) + ","
                outputData = outputData + rateAsString(thisSample.sentFrames, prevSample.sentFrames, seconds) + ","
                outputData = outputData + rateAsString(thisSample.recvFrames, prevSample.recvFrames, seconds) + ","
                outputData = outputData + rateAsString(thisSample.reXmit, prevSample.reXmit, seconds) + ","
                outputData = outputData + rateAsString(thisSample.lostFrames, prevSample.lostFrames, seconds) + ","
                
                outputData = outputData + "\n"
                
                }

            var  outputFile = self.outDir + "/" + thisInterface.deviceName + ".csv"
            
            if (outputData.writeToFile(outputFile, atomically:true, encoding:NSUTF8StringEncoding, error:&error)){
                self.progressText.insertText("Wrote: \(outputFile)\n")
            }
            else {
                self.progressText.insertText("File write failed with error:\(error?.localizedDescription)\n")
            }
            
        }
        
        outString = String(format:"Seconds Elapsed %.2f\n",NSDate().timeIntervalSinceDate (startTime))
        
        self.progressText.insertText(outString)
        
        self.progSpinner.stopAnimation(self)
        
        return(true)
        
    }
  
}
