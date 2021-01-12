//
//  CacheURLUtil.swift
//  SwiftyPlayer
//
//  Created by shiwei on 2021/1/11.
//

import Foundation

struct CacheURLUtil {
    static let customScheme = "streaming"
    static let originalScheme = "__originalScheme__"

    static func convertToCustom(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: originalScheme, value: components.scheme))
        components.queryItems = queryItems
        components.scheme = customScheme
        if let urlString = (components.url ?? url).absoluteString.removingPercentEncoding {
            return URL(string: urlString) ?? url
        } else {
            return url
        }
    }

    static func convertToOriginal(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let originalScheme = components?.queryItems?.first {
            $0.name == CacheURLUtil.originalScheme
        }
        guard let scheme = originalScheme else {
            return url
        }
        components?.scheme = scheme.value
        return components?.url ?? url
    }
}
