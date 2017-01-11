//
//  AnalyzeController.swift
//  AnalyzeSTCPLogs
//
//  Created by Ian Farquharson on 12/02/2015.
//  Copyright (c) 2015 Ian Farquharson. All rights reserved.
//  Updated 2016 - Swift 2 and async parsing

import Cocoa
import Foundation
import AppKit


class AnalyzeController: NSViewController {
    
    var startTime:Date = Date()
    
    var devNames = NSMutableArray()
    var data = NSMutableArray()
    var interfaceList = NSMutableArray()
    
    var outDir = NSString()
    
    @IBOutlet weak var sourcePath: NSTextField!

    @IBOutlet weak var progSpinner: NSProgressIndicator!
    
    @IBOutlet var progressText: NSTextView!
    
    @IBOutlet weak var startButton: NSButton!
    
//    @IBAction func startPressed(sender: AnyObject) {
//
//
//        progressText.insertText( "Starting\n")
//        progSpinner.startAnimation(self)
//        self.doParse(sourcePath.stringValue);
//    }

    @IBAction func startPressed(_ sender: AnyObject) {

        progressText.insertText( "Starting\n")
        progSpinner.startAnimation(self)
//
//        DispatchQueue.main.async {
//            /*self.*/
//            doParse(self.sourcePath.stringValue)
//        }
        if doParse(self.sourcePath.stringValue) != true {progressText.insertText ( "Parse Fault\n")}

    }
    
    @IBAction func resetPressed(_ sender: AnyObject) {
        
        sourcePath.stringValue = ""
        progressText.string = "Select File"
        progSpinner.stopAnimation(self)
        startButton.isEnabled = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override func awakeFromNib() {

        sourcePath.stringValue = ""
        progressText.string = "Select File\n"
        startButton.isEnabled = false
    }
    
    @IBAction func browseFile(_ sender: AnyObject) {

            self.startButton.isEnabled = false
        
            let openPanel = NSOpenPanel()
            openPanel.allowsMultipleSelection = false
            openPanel.canChooseDirectories = false
            openPanel.canCreateDirectories = false
            openPanel.canChooseFiles = true
        
            openPanel.begin { (result) -> Void in
                if result == NSFileHandlingPanelOKButton {
                    
                    if openPanel.url!.pathExtension != "out"
                    {
                        self.progressText.insertText("Selected \(openPanel.url!) without .out suffix, unsuitable file?\n")
                        self.sourcePath.stringValue = ""
                        return
                    }
                    
                    let path = openPanel.url?.path

                    self.sourcePath.stringValue = path!
                    self.progressText.insertText("Selected \(path)\n")

                    self.outDir = (openPanel.url?.deletingLastPathComponent().path)! as NSString
                    
                    self.progressText.insertText("Outputting to \(path!)\n")
                    self.startButton.isEnabled = true
                    }
            }
    }
    
    func doParse (_ path:String) -> Bool {
        
        self.progressText.insertText("Parsing \(path)\n")
        self.progSpinner.startAnimation(self)
        
        //deadman counter
        
        let parseErrorCount = 100
        
        startTime = Date()
        
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
        
        let dateSet:CharacterSet = CharacterSet(charactersIn:"-_: \n\r")

        let pctSet:CharacterSet = CharacterSet(charactersIn:"%/ \n\r")
    
        let MACSet:CharacterSet = CharacterSet(charactersIn:":")

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
            deadManCount += 1
            return (deadManCount >= parseErrorCount)
        }
        
        //Functions to manage parse types
        
        func scanForText(_ aScanner:Scanner)
        {
           aScanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines
            
        }
    
        func scanForDate(_ aScanner:Scanner)
        {
            aScanner.charactersToBeSkipped = dateSet
        }
        
        func findName(_ aName:String) -> Int
        {
            let index:Int = devNames.index(of: aName)

            if index != NSNotFound
            {
                return (index)
            }
            else
            {
                devNames.add(aName)
                self.progressText.insertText("Found \(aName)\n")
                
                let newInterface = interface()

                newInterface.MAC = MA! as String
                newInterface.MAC = newInterface.MAC.replace(":", withString:"")
                newInterface.speed = SP! as String
                newInterface.deviceName = aName
                
                interfaceList.add(newInterface)
                    
                return devNames.count
            }
        }

        func rateAsString (_ nowCount:Double, prevCount:Double, interval:Int) -> String
        {
            var retVal:Double
            if interval == 0 {
                return "div/0 error"
            }
            else {
                
                if nowCount >= prevCount {
                
                    retVal = (nowCount - prevCount) / Double(interval)
                }
                
                else {
                    retVal = (((Double(UINT32_MAX) + 1.0) - prevCount) + nowCount) / Double(interval)
                }
                return String(format:"%.2f", retVal)
            }
        }
    
        //read in the passed file.
        
        let dataRead: NSString?
        do {
            dataRead = try NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
        } catch let error as NSError {
            print(error.localizedDescription)
            self.progressText.insertText("File load failed with error:\(error)\n")
            self.progSpinner.stopAnimation(self)
            dataRead = nil
            return false
        }
        
        //Intitialize my scanner and whitespace sets

        let myScanner: Scanner = Scanner(string:dataRead! as String)
        
        //Declare position trackers
        
        var currPos:Int
        var macPos:Int
        var termPos:Int
        var foundMac:Bool
        var foundTerm:Bool
        
        //Begin Parsing
        
        var state = Parser.lookForTime
        resetDMC()

        while myScanner.isAtEnd == false
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
                if myScanner.scanUpTo(state.text(), into: nil) {
                    
                    //found it, discard and advance
                    myScanner.scanString(state.text(), into:nil)
                    state = Parser.getTime
                    resetDMC()
                    break
                }
                
            case Parser.getTime:
                
                scanForDate(myScanner)
                if (myScanner.scanInt (&YY) &&
                    myScanner.scanInt (&MM) &&
                    myScanner.scanInt (&DD) &&
                    myScanner.scanInt (&HH) &&
                    myScanner.scanInt (&MI) &&
                    myScanner.scanInt (&SS) == true ) {
                        state = Parser.lookForMAC
                        resetDMC()
                        break
                }
                
            case Parser.lookForMAC:
                scanForText(myScanner)
                if myScanner.scanUpTo(state.text(), into: nil) {
                    myScanner.scanString(state.text(), into:nil)
                    state = Parser.getMAC
                    resetDMC()
                    break
                }
                
            case Parser.getMAC:
                
                if myScanner.scanUpToCharacters (from: CharacterSet.newlines, into:&MA) {
                        resetDMC()
                        state = Parser.lookForInterface
                        break
                }
                
            case Parser.lookForInterface:
                
                scanForText(myScanner)
                if myScanner.scanString(state.text(), into:nil) {
                    state = Parser.getInterface
                    resetDMC()
                    break
                }
                
            case Parser.getInterface:
                
                if myScanner.scanUpToCharacters (from: CharacterSet.newlines, into:&DN) {
                    resetDMC()
                    state = Parser.lookForSpeed
                    break
                }
            case Parser.lookForSpeed:
                if myScanner.scanString(state.text(), into:nil) {
                    state = Parser.getSpeed
                    resetDMC()
                    break
                }
                
            case Parser.getSpeed:
                if myScanner.scanUpToCharacters (from: CharacterSet.newlines, into:&SP) {
                    resetDMC()
                    state = Parser.lookForMACSummary
                    break
                }
                
            case Parser.lookForMACSummary:
                scanForText(myScanner)
                if myScanner.scanUpTo(state.text(), into: nil) {
                    myScanner.scanString(state.text(), into:nil)
                    state = Parser.lookForTransFrames
                    resetDMC()
                    break
                }
                
            case Parser.lookForTransFrames:
                
                if  myScanner.scanString(state.text(), into:nil) {
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
                
                if  myScanner.scanString(state.text(), into:nil) {
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
                
                if  myScanner.scanString(state.text(), into:nil) {
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
                
                if  myScanner.scanString(state.text(), into:nil) {
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
                
                if  myScanner.scanString(state.text(), into:nil) {
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
                
                if  myScanner.scanString(state.text(), into:nil) {
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
                
                let thisEntry = netSample()
                var list:NSMutableArray

                thisEntry.date = String(format:"%02d/%02d/%02d",DD,MM,YY)  //yy,dd,mm before...
                thisEntry.time = String(format:"%02d:%02d:%02d",HH,MI,SS)
                
                var comps = DateComponents()
                comps.year = YY
                comps.month = MM
                comps.day = DD
                comps.hour = HH
                comps.minute = MI
                comps.second = SS
                
                thisEntry.absTime = Calendar.current.date(from: comps)!
                
                thisEntry.sentBytes = TB
                thisEntry.sentFrames = TF
                thisEntry.recvBytes = RB
                thisEntry.recvFrames = RF
                thisEntry.reXmit = RX
                thisEntry.lostFrames = LF

                var uniqueName:String = (DN! as String) + "_" + (MA! as String)
                
                uniqueName = uniqueName.replace(":", withString:"")
                
                
                let devIndex = findName(uniqueName)
                
                if (devIndex > data.count)
                {
                    list = NSMutableArray()
                    data.add(list)
                }
                else
                {
                    list = data.object(at: devIndex) as! NSMutableArray
                }
                
                list.add(thisEntry)
                
                //So we might next have another device, or the end of the sample
                //Save current position
                
                currPos = myScanner.scanLocation
                
                state = Parser.lookForMAC
                foundMac = myScanner.scanUpTo(state.text(), into:nil)
                macPos = myScanner.scanLocation
                
                //reset context... 
                myScanner.scanLocation = currPos
                
                state = Parser.lookForSampleTermination
                foundTerm  = myScanner.scanUpTo(state.text(), into:nil)
                termPos = myScanner.scanLocation
                
                //determine what to parse for next in the context.
                
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

        var outString = String(format:"Seconds Elapsed %.2f\n",Date().timeIntervalSince (startTime))
        
        self.progressText.insertText(outString)
        
        self.progressText.insertText("Constructing Output\n")
        self.progressText.needsDisplay = true
        self.progressText.display()
        
        if data.count > 0 {
            for dev:Int in 0...data.count-1  { //Go thru the interfaces found
                
                var outputData:String = "Date,Time,Device,Speed,SendBytes/s,RecvBytes/s,SendFrames/s,RecvFrames/s,ReTrans/s,LostFrame/s\n"
                
                let list:NSMutableArray = data.object(at: dev) as! NSMutableArray  //get the sample list
                let thisInterface:interface = interfaceList.object(at: dev) as! interface

                var lastDate = ""

                for sample:Int in 1...list.count-1 { //starts at sample 1 as we will delta N from N-1
                    
                    let thisSample:netSample = list.object(at: sample)as! netSample
                    let prevSample:netSample = list.object(at: sample - 1) as! netSample
                    
                    let seconds = Int(thisSample.absTime.timeIntervalSince(prevSample.absTime as Date))

                    if (thisSample.date != lastDate) {
                        outputData = outputData + thisSample.date + ","
                        lastDate = thisSample.date
                    }
                    else {
                        outputData = outputData + ","
                    }

                    outputData = outputData + thisSample.time + ","
                    outputData = outputData + thisInterface.deviceName + ","
                    outputData = outputData + thisInterface.speed + ","
                    
                    outputData = outputData + rateAsString (thisSample.sentBytes,
                                                            prevCount: prevSample.sentBytes, interval: seconds) + ","
                    outputData = outputData + rateAsString (thisSample.recvBytes,
                                                            prevCount: prevSample.recvBytes, interval: seconds) + ","
                    outputData = outputData + rateAsString (thisSample.sentFrames,
                                                            prevCount: prevSample.sentFrames, interval: seconds) + ","
                    outputData = outputData + rateAsString(thisSample.recvFrames,
                                                            prevCount: prevSample.recvFrames, interval: seconds) + ","
                    outputData = outputData + rateAsString(thisSample.reXmit,
                                                            prevCount: prevSample.reXmit, interval: seconds) + ","
                    outputData = outputData + rateAsString(thisSample.lostFrames,
                                                            prevCount: prevSample.lostFrames, interval: seconds) + ","
                    
                    outputData = outputData + "\n"

                }
                
                list.removeAllObjects()
                
                let  outputFile = (self.outDir as String) + "/" + thisInterface.deviceName + ".csv"
                
                do {
                    try outputData.write(toFile: outputFile, atomically: true, encoding: String.Encoding.utf8)
                    self.progressText.insertText("Wrote: \(outputFile)\n")
                    self.progressText.needsDisplay = true
                    self.progressText.display()
            
                }
                catch {
                    self.progressText.insertText("File write failed with error:\(error)\n")
                }
            }

        }

        data.removeAllObjects()
        devNames.removeAllObjects()
        interfaceList.removeAllObjects()
        
        outString = String(format:"Seconds Elapsed %.2f\n",Date().timeIntervalSince (startTime))
        
        self.progressText.insertText(outString)
        
        self.progSpinner.stopAnimation(self)

        return(true)
        
    }
  
}
