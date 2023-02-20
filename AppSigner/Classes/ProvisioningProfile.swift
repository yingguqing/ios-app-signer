//
//  provisioningProfile.swift
//  AppSigner
//
//  Created by Daniel Radtke on 11/4/15.
//  Copyright © 2015 Daniel Radtke. All rights reserved.
//

import AppKit
import Foundation
struct ProvisioningProfile {
    var filename: String,
        name: String,
        created: Date,
        expires: Date,
        appID: String,
        teamID: String,
        entitlements: [String: AnyObject]
    var certificates:[DeveloperCertificate]
    
    fileprivate let delegate = NSApplication.shared.delegate as! AppDelegate
    
    static func getProfiles() -> [ProvisioningProfile] {
        var output: [ProvisioningProfile] = []
        
        let fileManager = FileManager()
        if let libraryDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let provisioningProfilesPath = libraryDirectory.path.stringByAppendingPathComponent("MobileDevice/Provisioning Profiles") as NSString
            if let provisioningProfiles = try? fileManager.contentsOfDirectory(atPath: provisioningProfilesPath as String) {
                for provFile in provisioningProfiles {
                    if provFile.pathExtension == "mobileprovision" {
                        let profileFilename = provisioningProfilesPath.appendingPathComponent(provFile)
                        if let profile = ProvisioningProfile(filename: profileFilename) {
                            output.append(profile)
                        }
                    }
                }
            }
        }

        // distinct
        output = output.sorted(by: {
            $0.created.timeIntervalSince1970 > $1.created.timeIntervalSince1970
        })

        var newProfiles = [ProvisioningProfile]()
        var names = [String]()
        for profile in output {
            if !names.contains("\(profile.name)\(profile.appID)") {
                newProfiles.append(profile)
                names.append("\(profile.name)\(profile.appID)")
                NSLog("\(profile.name), \(profile.created)")
            }
        }
        return newProfiles
    }
    
    init?(filename: String) {
        let securityArgs = ["cms", "-D", "-i", filename]
        
        let taskOutput = Process().execute("/usr/bin/security", workingDirectory: nil, arguments: securityArgs)
        let rawXML: String
        if taskOutput.status == 0 {
            if let xmlIndex = taskOutput.output.range(of: "<?xml") {
                rawXML = String(taskOutput.output[xmlIndex.lowerBound...])
            } else {
                Log.write("Unable to find xml start tag in profile")
                rawXML = taskOutput.output
            }

            if let results = try? PropertyListSerialization.propertyList(from: rawXML.data(using: String.Encoding.utf8)!, options: .mutableContainers, format: nil) as? [String: AnyObject] {
                if let expirationDate = results["ExpirationDate"] as? Date,
                   let creationDate = results["CreationDate"] as? Date,
                   let name = results["Name"] as? String,
                   let entitlements = results["Entitlements"] as? [String: AnyObject],
                   let applicationIdentifier = entitlements["application-identifier"] as? String,
                   let periodIndex = applicationIdentifier.firstIndex(of: ".")
                {
                    self.filename = filename
                    self.expires = expirationDate
                    self.created = creationDate
                    /// 获取证书信息
                    let certificateDatas = results["DeveloperCertificates"] as? [Data] ?? []
                    self.certificates = certificateDatas.compactMap({ DeveloperCertificate(data: $0) })
                    self.appID = String(applicationIdentifier[applicationIdentifier.index(periodIndex, offsetBy: 1)...])
                    self.teamID = String(applicationIdentifier[applicationIdentifier.startIndex..<periodIndex])
                    self.name = name
                    self.entitlements = entitlements
                } else {
                    Log.write("Error processing \(filename.lastPathComponent)")
                    return nil
                }
            } else {
                Log.write("Error parsing \(filename.lastPathComponent)")
                return nil
            }
        } else {
            Log.write("Error reading \(filename.lastPathComponent)")
            return nil
        }
    }
    
    mutating func removeGetTaskAllow() {
        if let _ = entitlements.removeValue(forKey: "get-task-allow") {
            Log.write("Skipped get-task-allow entitlement!")
        } else {
            Log.write("get-task-allow entitlement not found!")
        }
    }
    
    mutating func update(trueAppID: String) {
        guard let oldIdentifier = entitlements["application-identifier"] as? String else {
            Log.write("Error reading application-identifier")
            return
        }
        let newIdentifier = teamID + "." + trueAppID
        entitlements["application-identifier"] = newIdentifier as AnyObject
        Log.write("Updated application-identifier from '\(oldIdentifier)' to '\(newIdentifier)'")
        // TODO: update any other wildcard entitlements
    }
    
    func getEntitlementsPlist() -> String? {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: .bitWidth)
            return String(data: data, encoding: .utf8)
        } catch {
            Log.write("parser entitlement xml faild:\(error.localizedDescription)")
            return ""
        }
    }
}
/// 描述文件中的证书信息
struct DeveloperCertificate {
    let name: String // 证书名称：iPhone Developer: Created via API (G7X5J84AUC)
    let expires: Date? // 证书过期时间
    
    /// 证书是否过期
    var isExpire:Bool {
        guard let date = expires else { return false }
        return Date() > date
    }
    
    
    init?(data: Data) {
        guard let cfData = CFDataCreate(kCFAllocatorDefault, (data as NSData).bytes, data.count), let certificateRef = SecCertificateCreateWithData(nil, cfData) else { return nil }
        guard let summary = SecCertificateCopySubjectSummary(certificateRef) as? String else { return nil }
        var error: Unmanaged<CFError>?
        guard let valuesDict = SecCertificateCopyValues(certificateRef, [kSecOIDInvalidityDate] as? CFArray, &error) as? [CFString: AnyObject] else { return nil }
        guard let invalidityDateDictionaryRef = valuesDict[kSecOIDInvalidityDate] as? [CFString: AnyObject] else { return nil }
        guard let invalidityRef = invalidityDateDictionaryRef[kSecPropertyKeyValue] else { return nil }
        self.name = summary
        if let invalidity = invalidityRef as? Date {
            self.expires = invalidity
        } else {
            let string = invalidityRef.description ?? ""
            let invalidityDateFormatter = DateFormatter()
            invalidityDateFormatter.locale = Locale(identifier: "zh_CN")
            invalidityDateFormatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
            if let invalidityDate = invalidityDateFormatter.date(from: string) {
                self.expires = invalidityDate
            } else {
                self.expires = nil
            }
        }
    }
}
