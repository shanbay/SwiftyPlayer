//
//  AVAsset+Metadata.swift
//  SwiftyPlayer
//
//  Created by shiwei on 2021/4/11.
//

import AVFoundation

public enum DynamicAttribute: String, CaseIterable {
    case duration
    case metadata
    case commonMetadata
    case playable

    public var key: String {
        rawValue
    }
}

extension AVAsset {
    private func loadAttributeAsynchronously(_ attribute: DynamicAttribute, completion: (() -> Void)?) {
        loadValuesAsynchronously(forKeys: [attribute.key], completionHandler: completion)
    }

    private func loadedAttributeValue<T>(for attribute: DynamicAttribute) -> T? {
        var error: NSError?
        let status = self.statusOfValue(forKey: attribute.key, error: &error)
        if let error = error {
            #if DEBUG
            print("Error loading asset value for key '\(attribute.key)': \(error)")
            #endif
        }
        guard status == .loaded else { return nil }
        return value(forKey: attribute.key) as? T
    }

    public func loadDuration(completion: @escaping ((_ duration: CMTime?) -> Void)) {
        loadAttributeAsynchronously(.duration) {
            guard let duration = self.loadedAttributeValue(for: .duration) as CMTime? else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            // Read duration from asset
            DispatchQueue.main.safeAsync {
                completion(duration)
            }
        }
    }

    public func load(_ attribute: DynamicAttribute, completion: @escaping ((_ items: [AVMetadataItem]) -> Void)) {
        loadAttributeAsynchronously(attribute) {
            let metadataItems = self.loadedAttributeValue(for: attribute) as [AVMetadataItem]?
            DispatchQueue.main.safeAsync {
                completion(metadataItems ?? [])
            }
        }
    }
}
