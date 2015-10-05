//
//  StringExtensions.swift
//  AnalyzeSTCPLogs
//
//  Created by Ian Farquharson on 12/02/2015.
//  Copyright (c) 2015 Ian Farquharson. All rights reserved.
//

import Foundation

extension String
{
    func replace(target: String, withString: String) -> String
    {
        return self.stringByReplacingOccurrencesOfString(target, withString: withString, options: NSStringCompareOptions.LiteralSearch, range: nil)
    }
    func contains(other: String) -> Bool{
        var start = startIndex
        
        repeat{
            let subString = self[Range(start: start++, end: endIndex)]
            if subString.hasPrefix(other){
                return true
            }
            
        }while start != endIndex
        
        return false
    }
    
    func containsIgnoreCase(other: String) -> Bool{
        var start = startIndex
        
        repeat{
            let subString = self[Range(start: start++, end: endIndex)].lowercaseString
            if subString.hasPrefix(other.lowercaseString){
                return true
            }
            
        }while start != endIndex
        
        return false
    }
}


