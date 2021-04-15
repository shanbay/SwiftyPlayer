//
//  AVAsset+Resource.swift
//  SwiftyPlayer
//
//  Created by jiang yi on 2021/3/12.
//

import AVFoundation

extension AVAsset {
    /// 异步获取metadata
    /// - Parameter loaded: 完成回调
    func asyncMetaData(_ completion: @escaping ([AVMetadataItem]) -> Void) {
        let formatsKeys = "availableMetadataFormats"
        loadValuesAsynchronously(forKeys: [formatsKeys]) { [weak self] in
            guard let self = self else { return }
            var error: NSError?
            let status = self.statusOfValue(forKey: formatsKeys, error: &error)
            if status == .loaded {
                for format in self.availableMetadataFormats {
                    let metadata = self.metadata(forFormat: format)
                    DispatchQueue.main.safeAsync {
                        completion(metadata)
                    }
                }
            }
        }
    }

    /// 异步获取duration
    /// - Parameter loaded: 完成回调
    func asyncDuration(_ completion: @escaping (CMTime) -> Void) {
        let formatsKeys = "availableDuration"
        loadValuesAsynchronously(forKeys: [formatsKeys]) { [weak self] in
            guard let self = self else { return }
            var error: NSError?
            let status = self.statusOfValue(forKey: formatsKeys, error: &error)
            if status == .loaded {
                DispatchQueue.main.safeAsync {
                    completion(self.duration)
                }
            }
        }
    }
}
