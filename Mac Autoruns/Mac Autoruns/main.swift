//
//  main.swift
//  Mac Autoruns
//
//  Created by Kimo Bumanglag on 6/2/20.
//  Copyright © 2020 Kimo Bumanglag. All rights reserved.
//

import Foundation
import CryptoKit

// Globals
let launchDaemonsDir = "/Library/LaunchDaemons/"
let launchAgentsDir = "/Library/LaunchAgents/"
let userDir = "/Users/"
let cronDir = "/var/at/tabs/"
let loginItems = "/Library/Application Support/com.apple.backgroundtaskmanagementagent/backgrounditems.btm"
var autorunEntries = [AutorunEntry]()

func enumerateUsers() -> Array<URL> {
    // Enumerate the users present on the system, as identified by a home directory
    // Returns: Array of file URLs for each user's home directory
    let usernames = try? FileManager.default.contentsOfDirectory(atPath: userDir)
    var userdirs = [URL]()
    for user in usernames! {
        let userurl = URL(fileURLWithPath: userDir + user)
        userdirs.append(userurl)
    }
    return userdirs
}

func extractProgramFromPlist(plistURL: URL) -> URL {
    // Given a URL to a plist file, load it and extract the Program key
    var format = PropertyListSerialization.PropertyListFormat.xml
    let fileContents = try? Data(contentsOf: plistURL)
    let plistData = try? PropertyListSerialization.propertyList(from: fileContents!,
        options: .mutableContainersAndLeaves,
        format: &format
    ) as? [String:AnyObject]
    var program = plistData!["Program"]
    if program === nil {
        // If the Program key does not exist, we should have a ProgramArguments key
        let arguments = plistData!["ProgramArguments"] as! Array<Any>
        program = arguments[0] as! String as AnyObject
    }
    return URL(fileURLWithPath: program as! String)
}

func enumerateLaunchDaemons(userHomeDirs: Array<URL>) {
    let systemLaunchDaemonFiles = try? FileManager.default.contentsOfDirectory(atPath: launchDaemonsDir)
    for file in systemLaunchDaemonFiles! {
        // Enumerate System Launch Daemon entries
        let autoruntype = "System Launch Daemon"
        let filepath = launchDaemonsDir + file
        if FileManager.default.isReadableFile(atPath: filepath) {
            let fileurl = URL(fileURLWithPath: filepath)
            let program = extractProgramFromPlist(plistURL: fileurl)
            let autorunentry = AutorunEntry(filepath: filepath, programpath: program.path, autoruntype: autoruntype)
            autorunEntries.append(autorunentry)
        }
    }
    for userHomeDir in userHomeDirs {
        let userLaunchDaemonDir = userHomeDir.absoluteString + launchDaemonsDir
        let userLaunchDaemonFiles = try? FileManager.default.contentsOfDirectory(atPath: userLaunchDaemonDir)
        if FileManager.default.isReadableFile(atPath: userLaunchDaemonDir) {
            for file in userLaunchDaemonFiles! {
                // Enumerate User Launch Daemon entries
                let autoruntype = "User Launch Daemon"
                let filepath = userLaunchDaemonDir + file
                let fileurl = URL(fileURLWithPath: filepath)
                let program = extractProgramFromPlist(plistURL: fileurl)
                let autorunentry = AutorunEntry(filepath: filepath, programpath: program.path, autoruntype: autoruntype)
                autorunEntries.append(autorunentry)
            }
        }
    }
}

func enumerateLaunchAgents(userHomeDirs: Array<URL>) {
    let systemLaunchAgentFiles = try? FileManager.default.contentsOfDirectory(atPath: launchAgentsDir)
    for file in systemLaunchAgentFiles! {
        // Enumerate System Launch Agent entries
        let autoruntype = "System Launch Agent"
        let filepath = launchAgentsDir + file
        if FileManager.default.isReadableFile(atPath: filepath) {
            let fileurl = URL(fileURLWithPath: filepath)
            let program = extractProgramFromPlist(plistURL: fileurl)
            let autorunentry = AutorunEntry(filepath: filepath, programpath: program.path, autoruntype: autoruntype)
            autorunEntries.append(autorunentry)
        }
    }
    for userHomeDir in userHomeDirs {
        let userLaunchAgentDir = userHomeDir.path + launchAgentsDir
        let userLaunchAgentFiles = try? FileManager.default.contentsOfDirectory(atPath: userLaunchAgentDir)
        if FileManager.default.isReadableFile(atPath: userLaunchAgentDir) {
            for file in userLaunchAgentFiles! {
                // Enumerate User Launch Agent entries
                let autoruntype = "User Launch Agent"
                let filepath = userLaunchAgentDir + file
                let fileurl = URL(fileURLWithPath: filepath)
                let program = extractProgramFromPlist(plistURL: fileurl)
                let autorunentry = AutorunEntry(filepath: filepath, programpath: program.path, autoruntype: autoruntype)
                autorunEntries.append(autorunentry)
            }
        }
    }
}

func enumerateCrons() {
    if FileManager.default.isReadableFile(atPath: cronDir) == false {
        // A non-admin user cannot read cron files, so bail
        return
    }
    let cronFiles = try? FileManager.default.contentsOfDirectory(atPath: cronDir)
    let autoruntype = "Cron Job"
    for file in cronFiles! {
        let filepath = cronDir.appending(file)
        if FileManager.default.isReadableFile(atPath: filepath) {
            let contents = try! String(contentsOfFile: filepath)
            let lines = contents.split(separator:"\n")
            for line in lines {
                if line.range(of: "^#", options: .regularExpression) == nil {
                    // A line that starts with a # is a comment, so we can ignore it
                    let autorunentry = AutorunEntry(filepath: filepath, programpath: String(line), autoruntype: autoruntype)
                    autorunEntries.append(autorunentry)
                }
            }
        }
    }
}

func enumerateLoginItems(userHomeDirs: Array<URL>) {
    var format = PropertyListSerialization.PropertyListFormat.xml
    let autoruntype = "Background Item"
    for userHomeDir in userHomeDirs {
        let userLoginItems = userHomeDir.path + loginItems
        if FileManager.default.isReadableFile(atPath: userLoginItems) {
            let fileContents = try? Data(contentsOf: URL(fileURLWithPath: userLoginItems))
             let plistData = try? PropertyListSerialization.propertyList(from: fileContents!,
                 options: .mutableContainersAndLeaves,
                 format: &format
             ) as? [String:AnyObject]
             let objects = plistData!["$objects"] as! Array<Any>
             for item in objects {
                // Each object key should have a program URL present
                // Format is file:///path/to/app.app
                 if String(describing: type(of: item)) == "__NSCFData" {
                     let theString:NSString = NSString(data: item as! Data, encoding: String.Encoding.ascii.rawValue) ?? "<nil>"
                     let pattern = "/([A-z0-9-_+ %]+/)*([A-z0-9 %]+.(app))"
                    // This Regex finds the first .app string, which may not be correct, since /Application/app.app is a directory
                    // TODO: Better Regex which finds the full path of the binary that gets executed
                     let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                     if let match = regex?.firstMatch(in: theString as String, options: [], range: NSRange(location: 0, length: theString.length)) {
                         let programpath = theString.substring(with: match.range)
                         let autorunentry = AutorunEntry(filepath: userLoginItems, programpath: programpath, autoruntype: autoruntype)
                         autorunEntries.append(autorunentry)
                     }
                 }
             }
        }
    }
}

func printResults() {
    for type in ["System Launch Daemon", "System Launch Agent", "User Launch Daemon", "User Launch Agent", "Cron Job", "Background Item"] {
        print("\(type)")
        for autorunentry in autorunEntries {
            if autorunentry.autoruntype == type {
                print("\t\(autorunentry.filepath)")
                print("\t\(autorunentry.programpath)")
                print("\t\t\(autorunentry.md5)")
                print("\t\t\(autorunentry.sha1)")
                print("\t\t\(autorunentry.sha256)")
                print("\t\tCertificate Chain:")
                for cert in autorunentry.certChain {
                    print("\t\t\t\(cert)")
                }
            }
        }
    }
}

let users = enumerateUsers()
enumerateLaunchDaemons(userHomeDirs: users)
enumerateLaunchAgents(userHomeDirs: users)
enumerateCrons()
enumerateLoginItems(userHomeDirs: users)
printResults()
