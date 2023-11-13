//
//  DailyRotatingFileDestination.swift
//  XCGLogger
//
//  Created by Stefan Fahrnbauer on 13.11.23.
//  Copyright © 2023 Speed4Trade GmbH. All rights reserved.
//

import Foundation

// MARK: - DailyRotatingFileDestination
/// A destination that outputs log details to files in a log folder, with auto-rotate option: at midnight
open class DailyRotatingFileDestination: FileDestination {
    // MARK: - Constants

    // MARK: - Properties

    internal var archiveSuffixDateFormatter: DateFormatter? = nil

    /// Start time of the current log file
    internal var currentLogStartTimeInterval: TimeInterval = 0

    /// The base file name of the log file
    internal var baseFileName: String = "xcglogger"

    /// The extension of the log file name
    internal var fileExtension: String = "log"

    // MARK: - Class Properties


    // MARK: - Life Cycle
    public init(owner: XCGLogger? = nil,
                writeToFile: Any,
                identifier: String = "",
                shouldAppend: Bool = false,
                appendMarker: String? = "-- ** ** ** --",
                attributes: [FileAttributeKey: Any]? = nil,
                archiveSuffixDateFormatter: DateFormatter? = nil,
                targetMaxLogFiles: UInt8 = 10) {

        super.init(owner: owner, writeToFile: writeToFile, identifier: identifier, shouldAppend: true, appendMarker: shouldAppend ? appendMarker : nil, attributes: attributes)

        self.currentLogStartTimeInterval = Date().timeIntervalSince1970
        self.archiveSuffixDateFormatter = archiveSuffixDateFormatter
        
        guard let writeToFileURL = writeToFileURL else { return }

        // Calculate some details for naming archived logs based on the current log file path/name
        fileExtension = writeToFileURL.pathExtension
        baseFileName = writeToFileURL.lastPathComponent
        if let fileExtensionRange: Range = baseFileName.range(of: ".\(fileExtension)", options: .backwards),
           fileExtensionRange.upperBound >= baseFileName.endIndex {
            baseFileName = String(baseFileName[baseFileName.startIndex ..< fileExtensionRange.lowerBound])
        }

        let filePath: String = writeToFileURL.path
        let logFileName: String = "\(baseFileName).\(fileExtension)"
        if let logFileNameRange: Range = filePath.range(of: logFileName, options: .backwards),
           logFileNameRange.upperBound >= filePath.endIndex {
            let archiveFolderPath: String = String(filePath[filePath.startIndex ..< logFileNameRange.lowerBound])
            archiveFolderURL = URL(fileURLWithPath: "\(archiveFolderPath)")
        }
        if archiveFolderURL == nil {
            archiveFolderURL = type(of: self).defaultLogFolderURL
        }

        // Because we always start by appending, regardless of the shouldAppend setting, we now need to handle the cases where we don't want to append or that we have now reached the rotation threshold for our current log file
        if !shouldAppend || shouldRotate() {
            rotateFile()
        }
    }

    /// Rotate the current log file.
    ///
    /// - Parameters:   None.
    ///
    /// - Returns:      Nothing.
    ///
    open func rotateFile() {
        guard let writeToFileURL = self.writeToFileURL else { return }
        guard let archiveSuffixDateFormatter = self.archiveSuffixDateFormatter else { return }

        var suffix: String?
        do {
            let fileAttributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: writeToFileURL.path)
            suffix = archiveSuffixDateFormatter.string(from: fileAttributes[.creationDate] as? Date ?? Date())
        }
        catch let error as NSError {
            owner?._logln("Unable to determine current file attributes of log file: \(error.localizedDescription)", level: .warning)
        }

        guard let suffix = suffix else { return }

        var archiveFolderURL: URL = (self.archiveFolderURL ?? type(of: self).defaultLogFolderURL)
        archiveFolderURL = archiveFolderURL.appendingPathComponent("\(baseFileName)\(suffix)")
        archiveFolderURL = archiveFolderURL.appendingPathExtension(fileExtension)

        rotateFile(to: archiveFolderURL)

        currentLogStartTimeInterval = Date().timeIntervalSince1970

        cleanUpLogFiles()
    }

    /// Determine if the log file should be rotated.
    ///
    /// - Parameters:   None.
    ///
    /// - Returns:
    ///     - true:     The log file should be rotated.
    ///     - false:    The log file doesn't have to be rotated.
    ///
    open func shouldRotate() -> Bool {
        // Do not rotate until critical setup has been completed so that we do not accidentally rotate once to the defaultLogFolderURL before determining the desired log location
        guard archiveFolderURL != nil else { return false }

        // Alter: wir rotieren nur um Mitternacht
        let midnightOfToday = Calendar(identifier: .gregorian).startOfDay(for: Date())
        if (midnightOfToday.timeIntervalSince1970 > currentLogStartTimeInterval)
        {
            return true
        }

        return false
    }

    // MARK: - Overridden Methods
    /// Write the log to the log file.
    ///
    /// - Parameters:
    ///     - message:   Formatted/processed message ready for output.
    ///
    /// - Returns:  Nothing
    ///
    open override func write(message: String) {
        super.write(message: message)

        if shouldRotate() {
            rotateFile()
        }
    }
}
