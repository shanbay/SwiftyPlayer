//
//  Avasset+Resource.swift
//  SwiftyPlayer
//
//  Created by jiang yi on 2021/3/12.
//

import AVFoundation

extension AVAsset {
    
    /// 异步获取metadata
    /// - Parameter loaded: 完成回调
    func asyncMetaData(loaded: @escaping ([AVMetadataItem])->()) {
        let formatsKeys = "availableMetadataFormats"
        loadValuesAsynchronously(forKeys: [formatsKeys]) { [weak self] in
            guard let self = self else { return }
            var error: NSError? = nil
            let status = self.statusOfValue(forKey: formatsKeys, error: &error)
            if status == .loaded {
                for format in self.availableMetadataFormats {
                    let metadata = self.metadata(forFormat: format)
                    loaded(metadata)
                }
            }
        }
    }
    
    /// 异步获取duration
    /// - Parameter loaded: 完成回调
    func asyncDuration(loaded: @escaping (CMTime)->()) {
        let formatsKeys = "availableDuration"
        loadValuesAsynchronously(forKeys: [formatsKeys]) { [weak self] in
            guard let self = self else { return }
            var error: NSError? = nil
            let status = self.statusOfValue(forKey: formatsKeys, error: &error)
            if status == .loaded {
                loaded(self.duration)
            }
        }
    }
}
