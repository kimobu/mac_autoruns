//
//  AutorunEntry.swift
//  Mac Autoruns
//
//  Created by Kimo Bumanglag on 6/2/20.
//  Copyright © 2020 Kimo Bumanglag. All rights reserved.
//

import Cocoa
import CryptoKit

class AutorunEntry: NSObject {
    var filepath: String
    var programpath: String
    var autoruntype: String
    var md5: String {
        return calculateHash(hashType: "md5")
    }
    var sha1: String {
        return calculateHash(hashType: "sha1")
    }
    var sha256: String {
        return calculateHash(hashType: "sha256")
    }
    var certChain: Array<String> {
        return getCerts(path: self.programpath)
    }
    init(filepath: String, programpath: String, autoruntype: String) {
        self.filepath = filepath
        self.programpath = programpath
        self.autoruntype = autoruntype
    }
    private func calculateHash(hashType: String) -> String {
        var hash = "No hash"
        if self.autoruntype == "Cron Job" {
            // We do not hash cron jobs since they can contain arbitrary shell commands/scripts
            return hash
        }
        var fileContents = try? Data(contentsOf: URL(fileURLWithPath: self.programpath))
        if fileContents == nil {
            // A file like /Applications/LuLu.app is a directory
            // Do a lazy find of what the binary should be
            let newFile = findApp(path: programpath)
            if newFile != "" {
                // We will hash the lazily found file
                fileContents = try? Data(contentsOf: URL(fileURLWithPath: newFile))
            } else {
                // We could not find an app to hash
                return hash
            }
        }
        switch hashType {
        case "md5":
            hash = CryptoKit.Insecure.MD5.hash(data: fileContents!).description
        case "sha1":
            hash = CryptoKit.Insecure.SHA1.hash(data: fileContents!).description
        case "sha256":
            hash = CryptoKit.SHA256.hash(data: fileContents!).description
        default:
            return hash
        }
        return hash
    }
    private func findApp(path: String) -> String {
        // Given an app path, try to find the first real binary in the Contents/MacOS directory
        // Potentially will not find anything
        let binarypath = path + "/Contents/MacOS"
        let binary = try? FileManager.default.contentsOfDirectory(atPath: binarypath).first
        if binary != nil {
            return binarypath + "/" + binary!
        } else {
            return ""
        }
    }
    private func getCerts(path: String) -> Array<String> {
        // Given an app, try to obtain certificate signing information
        // This will return the certificate chain as an array of strings
        let programurl = NSURL.fileURL(withPath: path)
        let kSecCSDefaultFlags = 1
        let flags = SecCSFlags(rawValue: SecCSFlags.RawValue(kSecCSDefaultFlags))
        var staticCode: SecStaticCode?
        var signingInfo: CFDictionary?
        var returnArray = [String]()
        _ = SecStaticCodeCreateWithPath(programurl as CFURL, flags, &staticCode )
        if staticCode != nil {
            _ = SecCodeCopySigningInformation(staticCode!, SecCSFlags(rawValue: kSecCSSigningInformation), &signingInfo)
            let nsdSigningInfo = signingInfo! as NSDictionary
            let certChain = nsdSigningInfo["certificates"] as! NSArray
            var cname: CFString?
            for cert in certChain {
                SecCertificateCopyCommonName(cert as! SecCertificate, &cname)
                returnArray.append(cname! as String)
            }
            return returnArray
        } else {
            return []
        }
    }
}
