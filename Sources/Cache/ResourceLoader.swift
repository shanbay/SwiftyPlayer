//
//  ResourceLoader.swift
//  SwiftyPlayer
//
//  Created by shiwei on 2021/1/11.
//

import AVFoundation
import Foundation
import MobileCoreServices
import SystemConfiguration

struct ResourceLoaderRequest: Hashable {
    var data = Data()
    var loadingRequest: AVAssetResourceLoadingRequest
    var dataTask: URLSessionDataTask
    var response: URLResponse?
    var requestType: RequestType
    enum RequestType {
        case contentInfo
        case dataRequest
    }
}

class ResourceLoader: NSObject {
    private(set) var loaderQueue = DispatchQueue(label: "com.swiftyplayer.resourceloader.queue")

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()

    private var loadingRequests: [ResourceLoaderRequest] = []
}

extension ResourceLoader: AVAssetResourceLoaderDelegate {
    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let requestURL = loadingRequest.request.url else {
            return false
        }
        let url = CacheURLUtil.convertToOriginal(requestURL)
        let fileName = url.lastPathComponent

        // read from cache first
        // if key = filename exists
        // return value

        let loadingRequestExist = loadingRequests.contains { $0.loadingRequest == loadingRequest }
        if !loadingRequestExist {
            if loadingRequest.contentInformationRequest != nil {
                var request = URLRequest(url: url)
                if let dataRequest = loadingRequest.dataRequest {
                    let lowerBound = Int(dataRequest.requestedOffset)
                    let upperBound = lowerBound + Int(dataRequest.requestedLength) - 1
                    let rangeHeader = "bytes=\(lowerBound)-\(upperBound)"
                    request.setValue(rangeHeader, forHTTPHeaderField: "Range")
                }

                let dataTask = session.dataTask(with: request)
                loadingRequests.append(
                    ResourceLoaderRequest(
                        loadingRequest: loadingRequest,
                        dataTask: dataTask,
                        requestType: .contentInfo
                    )
                )
                dataTask.resume()
                return true
            } else if let dataRequest = loadingRequest.dataRequest {
                var request = URLRequest(url: url)

                let lowerBound = dataRequest.requestedOffset
                let length = Int64(dataRequest.requestedLength)
                let upperBound = lowerBound + length
                let rangeHeader = "bytes=\(lowerBound)-\(upperBound)"
                request.setValue(rangeHeader, forHTTPHeaderField: "Range")

                let dataTask = session.dataTask(with: request)
                loadingRequests.append(
                    ResourceLoaderRequest(
                        loadingRequest: loadingRequest,
                        dataTask: dataTask,
                        requestType: .dataRequest
                    )
                )
                dataTask.resume()
                return true
            }
        }

        return false
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        loaderQueue.async {
            let index = self.loadingRequests.firstIndex { $0.loadingRequest == loadingRequest }
            if let index = index {
                self.loadingRequests[index].dataTask.cancel()
                // save data
                self.saveDataToCache(resourceLoaderRequest: self.loadingRequests[index])
                self.loadingRequests.remove(at: index) // 移除请求记录
            }
        }
    }
}

extension ResourceLoader: URLSessionDataDelegate {
    private func saveDataToCache(resourceLoaderRequest: ResourceLoaderRequest) {
        //read cache key = fileName
        //update cache data
        //save data to cache as fileName
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        loaderQueue.async {
            let index = self.loadingRequests.firstIndex { $0.dataTask == dataTask }
            if let index = index, self.loadingRequests[index].requestType == .dataRequest {
                self.loadingRequests[index].data.append(data)
                self.loadingRequests[index].loadingRequest.dataRequest?.respond(with: data)
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        loaderQueue.async {
            let index = self.loadingRequests.firstIndex { $0.dataTask == dataTask }
            if let index = index {
                self.loadingRequests[index].response = response
            }
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        loaderQueue.async {
            let index = self.loadingRequests.firstIndex { $0.dataTask == task }
            guard let currentIndex = index else {
                return
            }

            if let error = error {
                self.loadingRequests[currentIndex].loadingRequest.finishLoading(with: error)
                return
            }

            if self.loadingRequests[currentIndex].requestType == .contentInfo {
                guard let response = self.loadingRequests[currentIndex].response as? HTTPURLResponse else {
                    return
                }

                if let rangeString = response.allHeaderFields["Content-Range"] as? String,
                   let bytesString = rangeString.split(separator: "/").map({ String($0) }).last,
                   let bytes = Int64(bytesString) {
                    self.loadingRequests[currentIndex].loadingRequest.contentInformationRequest?.contentLength = bytes
                }

                if let mimeType = response.mimeType,
                   let contentType = UTTypeCreatePreferredIdentifierForTag(
                    kUTTagClassMIMEType,
                    mimeType as CFString,
                    nil
                   )?.takeRetainedValue() {
                    self.loadingRequests[currentIndex]
                        .loadingRequest
                        .contentInformationRequest?
                        .contentType = contentType as String
                }

                if let value = response.allHeaderFields["Accept-Ranges"] as? String,
                   value == "bytes" {
                    self.loadingRequests[currentIndex]
                        .loadingRequest
                        .contentInformationRequest?
                        .isByteRangeAccessSupported = true
                } else {
                    self.loadingRequests[currentIndex]
                        .loadingRequest
                        .contentInformationRequest?
                        .isByteRangeAccessSupported = false
                }

                self.loadingRequests[currentIndex].loadingRequest.finishLoading()

                if let fileName = self.loadingRequests[currentIndex].loadingRequest.request.url?.lastPathComponent {
                    //save info to cache as fileName
                }
            } else if self.loadingRequests[currentIndex].requestType == .dataRequest {
                self.loadingRequests[currentIndex].loadingRequest.finishLoading()
                self.saveDataToCache(resourceLoaderRequest: self.loadingRequests[currentIndex])
            }
            self.loadingRequests.remove(at: currentIndex)
        }
    }
}
