//
//  PlayerConfigurator.swift
//  SwiftyPlayer
//
//  Created by jiang yi on 2021/3/12.
//

import UIKit

public struct PlayerConfigurator {
    /// 是否播放器外部管理AudioSession
    ///
    /// 默认内部管理 播放时设置
    public var manageAudioSessionExternal: Bool = false

    /// public
    public init(manageAudioSessionExternal: Bool) {
        self.manageAudioSessionExternal = manageAudioSessionExternal
    }

    private init() {}
    /// default
    public static var `default`: PlayerConfigurator = PlayerConfigurator()
}
