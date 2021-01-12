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

    enum RequestType {
        case contentInfo
        case dataRequest
    }
    var requestType: RequestType
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
                    let rangeHeader = String(format: "bytes=%lld-%lld", lowerBound, upperBound)
                    request.setValue(rangeHeader, forHTTPHeaderField: "Range")
                }
                request.httpMethod = "HEAD" // use "HEAD", fetch content-length/content-type ie.

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
                let rangeHeader = String(format: "bytes=%lld-%lld", lowerBound, upperBound)
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
        if let fileName = resourceLoaderRequest.loadingRequest.request.url?.lastPathComponent {
            // read cache key = fileName
            // update cache data
            // save data to cache as fileName
        }
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
                completionHandler(.allow)
            } else {
                completionHandler(.cancel)
            }
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
                let allStringHeader = response.allHeaderFields.compactMap { pair -> (key: String, value: Any)? in
                    if let key = pair.key as? String {
                        return (key: key, value: pair.value)
                    }
                    return nil
                }
                let headerFields: [String: Any] = Dictionary(allStringHeader) { $1 }
                // content-length
                let cotentLength = headerFields.first { $0.key.lowercased() == "content-length" }?.value
                if let cotentLengthString = cotentLength as? String, let bytes = Int64(cotentLengthString) {
                    self.loadingRequests[currentIndex].loadingRequest.contentInformationRequest?.contentLength = bytes
                }

                if let mimeType = response.mimeType {
                    let contentType = UTTypeCreatePreferredIdentifierForTag(
                        kUTTagClassMIMEType,
                        mimeType as CFString,
                        nil
                    )
                    self.loadingRequests[currentIndex]
                        .loadingRequest
                        .contentInformationRequest?
                        .contentType = contentType?.takeRetainedValue() as String?
                }
                // accept-range
                let acceptRanges = headerFields.first { $0.key.lowercased() == "accept-range" }?.value
                var isByteRangeAccessSupported = false
                if let value = acceptRanges as? String, value == "bytes" {
                    isByteRangeAccessSupported = true
                }
                self.loadingRequests[currentIndex]
                    .loadingRequest
                    .contentInformationRequest?
                    .isByteRangeAccessSupported = isByteRangeAccessSupported

                self.loadingRequests[currentIndex].loadingRequest.finishLoading()
                self.saveDataToCache(resourceLoaderRequest: self.loadingRequests[currentIndex])
            } else if self.loadingRequests[currentIndex].requestType == .dataRequest {
                self.loadingRequests[currentIndex].loadingRequest.finishLoading()
                self.saveDataToCache(resourceLoaderRequest: self.loadingRequests[currentIndex])
            }
            self.loadingRequests.remove(at: currentIndex)
        }
    }
}
