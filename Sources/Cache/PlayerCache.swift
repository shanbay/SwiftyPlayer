//
//  PlayerCache.swift
//  SwiftyPlayer
//
//  Created by shiwei on 2021/1/12.
//

import AVFoundation
import PINCache

struct PlayerCacheRange: Hashable {
    // 下界
    let lower: Int64
    // 上界
    let upper: Int64

    func hash(into hasher: inout Hasher) {
        let value = String(format: "bytes=%lld-%lld", lower, upper)
        hasher.combine(value.hash)
    }

    static func ~= (lhs: PlayerCacheRange, rhs: Int64) -> Bool {
        rhs >= lhs.lower && rhs <= lhs.upper
    }
}

//
extension Dictionary where Key == PlayerCacheRange {
    subscript(bound: Int64) -> Value? {
        for key in keys where key ~= bound {
            return self[key]
        }
        return nil
    }

//    func retrieveRange(_ original: )
}

enum PlayerCacheStatus {
    case allCompleted(Data)
    case tmp([PlayerCacheRange: Data?])
}

struct PlayerCache {
    static let cache = PINCache(name: "com.swiftyplayer.cache")

    static func read(name: String) -> PlayerCacheStatus {
        // 1. 是否已经全部下载完成
        if let data = cache.object(forKey: name) as? Data {
            // 2. 全部下载完成
            return .allCompleted(data)
        } else {
            // 3. 获取 name_tmp 临时存储记录文件
            if let data = cache.object(forKey: name + "_tmp") as? [PlayerCacheRange: Data?] {
                // 3.1 已经存在 name_tmp 临时文件
                return .tmp(data)
            } else {
                // 3.2 不存在 name_tmp 临时文件，新建它
                let dict: [PlayerCacheRange: Data?] = [
                    PlayerCacheRange(lower: 0, upper: 1): nil, // content-info
                ]
                cache.setObject(dict, forKey: name + "_tmp")
                // 替换为下面，增加过期时间
//                cache.setObjectAsync(dict, forKey: name + "_tmp", withAgeLimit: , completion: )
                return .tmp(dict)
            }
        }
    }

    /// 保存 Data 到 Cache 中
    static func saveData(name: String, resourceLoaderRequest: ResourceLoaderRequest) {
        guard var dict = cache.object(forKey: name + "_tmp") as? [PlayerCacheRange: Data?] else {
            // 走到这一步了，肯定有 name_tmp 数据了，没有?那就有问题了
            return
        }
        if case .contentInfo = resourceLoaderRequest.requestType {
            let contentInfoRange = PlayerCacheRange(lower: 0, upper: 1)
            dict[contentInfoRange] = resourceLoaderRequest.data
            if let length = resourceLoaderRequest.loadingRequest.contentInformationRequest?.contentLength {
                dict[PlayerCacheRange(lower: 2, upper: length - 1)] = nil
            }
        } else {

        }
    }
}
