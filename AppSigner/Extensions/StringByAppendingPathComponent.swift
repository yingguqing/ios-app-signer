//
//  StringByAppendingPathComponent.swift
//  AppSigner
//
//  Created by Daniel Radtke on 11/3/15.
//  Copyright © 2015 Daniel Radtke. All rights reserved.
//

import Foundation
extension String {
    var lastPathComponent: String {
        return (self as NSString).lastPathComponent
    }

    var pathExtension: String {
        return (self as NSString).pathExtension
    }

    var stringByDeletingLastPathComponent: String {
        return (self as NSString).deletingLastPathComponent
    }

    var stringByDeletingPathExtension: String {
        return (self as NSString).deletingPathExtension
    }

    var pathComponents: [String] {
        return (self as NSString).pathComponents
    }
    
    func stringByAppendingPathComponent(_ path: String) -> String {
        let nsSt = self as NSString
        
        return nsSt.appendingPathComponent(path)
    }
    
    func stringByAppendingPathExtension(_ ext: String) -> String? {
        let nsSt = self as NSString
        
        return nsSt.appendingPathExtension(ext)
    }
}
