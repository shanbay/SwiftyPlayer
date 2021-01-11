//
//  CacheTests.swift
//  Tests
//
//  Created by shiwei on 2021/1/11.
//

@testable import SwiftyPlayer
import XCTest

class CacheTests: XCTestase {
    func testSchemeConvert() {
        let url = URL(string: "https://www.shanbay.com")!
        let result = CacheURLUtil.convertToCustom(url)
        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        XCTAssertNotNil(components)
        XCTAssertEqual(components!.scheme, CacheURLUtil.customScheme)
        XCTAssertNotNil(components!.queryItems)
        XCTAssertTrue(components!.queryItems!.contains { $0.name == CacheURLUtil.originalScheme })
        let item = components!.queryItems!.first { $0.name == CacheURLUtil.originalScheme }
        XCTAssertNotNil(item)
        XCTAssertEqual(item!.value, "https")
    }
}
