//
//  netSample.swift
//  AnalyzeSTCPLogs
//
//  Created by Ian Farquharson on 19/02/2015.
//  Copyright (c) 2015 Ian Farquharson. All rights reserved.
//

import Foundation

class netSample {
    var index: Int = 0
    var absTime:NSDate = NSDate()
    var date:String = ""
    var time:String = ""
    var sentFrames: Double = 0.0
    var recvFrames: Double = 0.0
    var sentBytes: Double = 0.0
    var recvBytes: Double = 0.0
    var reXmit: Double = 0.0
    var lostFrames: Double = 0.0
    
}