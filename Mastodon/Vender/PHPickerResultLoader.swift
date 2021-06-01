//
//  PHPickerResultLoader.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-3-18.
//

import os.log
import Foundation
import Combine
import MobileCoreServices
import PhotosUI
import MastodonSDK

// load image with low memory usage
// Refs: https://christianselig.com/2020/09/phpickerviewcontroller-efficiently/
enum PHPickerResultLoader {
    
    static func loadImageData(from result: PHPickerResult) -> Future<Mastodon.Query.MediaAttachment?, Error> {
        Future { promise in
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard  let url = url else {
                    promise(.success(nil))
                    return
                }
                
                let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
                guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
                    return
                }
                
                let downsampleOptions = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 4096,
                ] as CFDictionary
                
                guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
                    return
                }
                
                let data = NSMutableData()
                guard let imageDestination = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else {
                    promise(.success(nil))
                    return
                }
                
                let isPNG: Bool = {
                    guard let utType = cgImage.utType else { return false }
                    return (utType as String) == UTType.png.identifier
                }()
                
                let destinationProperties = [
                    kCGImageDestinationLossyCompressionQuality: isPNG ? 1.0 : 0.75
                ] as CFDictionary
                
                CGImageDestinationAddImage(imageDestination, cgImage, destinationProperties)
                CGImageDestinationFinalize(imageDestination)
                
                let dataSize = ByteCountFormatter.string(fromByteCount: Int64(data.length), countStyle: .memory)
                os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: load image %s", ((#file as NSString).lastPathComponent), #line, #function, dataSize)

                let file = Mastodon.Query.MediaAttachment.jpeg(data as Data)
                promise(.success(file))
            }
        }
    }
    
    static func loadVideoData(from result: PHPickerResult) -> Future<Mastodon.Query.MediaAttachment?, Error> {
        Future { promise in
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let url = url else {
                    promise(.success(nil))
                    return
                }
                
                let fileName = UUID().uuidString
                let tempDirectoryURL = FileManager.default.temporaryDirectory
                let fileURL = tempDirectoryURL.appendingPathComponent(fileName).appendingPathExtension(url.pathExtension)
                do {
                    try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                    try FileManager.default.copyItem(at: url, to: fileURL)
                    let file = Mastodon.Query.MediaAttachment.other(fileURL, fileExtension: fileURL.pathExtension, mimeType: UTType.movie.preferredMIMEType ?? "video/mp4")
                    promise(.success(file))
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }
    
}
