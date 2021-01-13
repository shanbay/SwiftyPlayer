//
//  PlayerCache.swift
//  SwiftyPlayer
//
//  Created by shiwei on 2021/1/12.
//

import AVFoundation
import PINCache

struct PlayerCacheRange: Hashable {
    // 数据开始的下标
    let location: Int64
    // 数据总长度
    let length: Int64

    var upperBound: Int64 {
        location + length - 1
    }

    func hash(into hasher: inout Hasher) {
        let value = String(format: "bytes=%lld-%lld", location, upperBound)
        hasher.combine(value.hash)
    }

    static func ~= (lhs: PlayerCacheRange, rhs: Int64) -> Bool {
        rhs >= lhs.location && rhs <= lhs.upperBound
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

    /// 获取需要请求下载的 range
    func retrieveRequestRange(_ original: PlayerCacheRange) -> [PlayerCacheRange] {
        []
    }
}

enum PlayerCacheStatus {
    case allCompleted(Data)
    case tmp([PlayerCacheRange: Data])
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
            if let dict = cache.object(forKey: name + "_tmp") as? [PlayerCacheRange: Data] {
                // 3.1 已经存在 name_tmp 临时文件
                return .tmp(dict)
            } else {
                // 3.2 不存在 name_tmp 临时文件，新建它
                let dict: [PlayerCacheRange: Data] = [:]
                setObject(dict, forKey: name + "_tmp")
                return .tmp(dict)
            }
        }
    }

    /// 保存 Data 到 Cache 中
    static func saveData(name: String, resourceLoaderRequest: ResourceLoaderRequest) {
        guard var dict = cache.object(forKey: name + "_tmp") as? [PlayerCacheRange: Data?] else {
            // 走到这一步了，肯定有 name_tmp 数据了，没有? 那就有问题了
            return
        }
        if case .contentInfo = resourceLoaderRequest.requestType {
            if let length = resourceLoaderRequest.loadingRequest.contentInformationRequest?.contentLength {
                // content info 获取之后，cache 一个总长的数据，data 为 nil
                // 后续对 0-[content-length] 的数据拆分合并
//                dict[PlayerCacheRange(location: 0, length: length)] = Data(capacity: length)
                setObject(dict, forKey: name + "_tmp")
            }
        } else {

        }
    }

    static func setObject(_ object: Any, forKey key: String) {
        cache.setObject(object, forKey: key)
        // 替换为下面，增加过期时间
//        cache.setObjectAsync(dict, forKey: name + "_tmp", withAgeLimit: , completion: )
    }
}
