//
//  SSCacheControl.swift
//  SSCacheControl
//
//  Created by LawLincoln on 15/12/22.
//  Copyright © 2015年 SelfStudio. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

private extension String {
    var date: NSDate! {
        let fmt = NSDateFormatter()
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        fmt.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        fmt.timeZone = NSTimeZone(abbreviation: "GMT")
        return fmt.dateFromString(self)
    }
}

extension NSURLRequest {
    
    private struct AssociatedKeys {
        static var MaxAge = "MaxAge"
    }
    var ll_max_age: NSTimeInterval {
        get {
            return (objc_getAssociatedObject(self, &AssociatedKeys.MaxAge) as? NSTimeInterval) ?? 0
        }
        set(max) {
            objc_setAssociatedObject(self, &AssociatedKeys.MaxAge, max, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    /**
     Save NSHTTPURLResponse
     
     - parameter maxAge: NSTimeInterval
     - parameter resp:   NSHTTPURLResponse to store
     - parameter data:   data to store
     */
    
    func ll_storeResponse(maxAge: NSTimeInterval,
                            resp: NSHTTPURLResponse?,
                            data: NSData?) {
        if let response = resp, url = response.URL, header = response.allHeaderFields as? [String : String], data = data {
            if let re = NSHTTPURLResponse(URL: url, statusCode: response.statusCode, HTTPVersion: nil, headerFields: header) {
                let cachedResponse = NSCachedURLResponse(response: re, data: data, userInfo: nil, storagePolicy: NSURLCacheStoragePolicy.Allowed)
                NSURLCache.sharedURLCache().storeCachedResponse(cachedResponse, forRequest: self)
            }
        }
    }
    
    func ll_lastCachedResponseDataIgnoreExpires(ignoreExpires: Bool = true) -> NSData? {
        let response = NSURLCache.sharedURLCache().cachedResponseForRequest(self)
        if ignoreExpires {
            return response?.data
        }
        let now = NSDate()
        var data: NSData!
        if let resp = response?.response as? NSHTTPURLResponse {
            if let dateString = resp.allHeaderFields["Date"] as? String, dateExpires = dateString.date {
                let expires = dateExpires.dateByAddingTimeInterval(ll_max_age)
                if now.compare(expires) == .OrderedAscending {
                    data = response?.data
                }
            }
        }
        return data
    }
}

public func request(URLRequest: URLRequestConvertible,
     cacheControlMaxAge config: (maxAge: NSTimeInterval, ignoreExpires: Bool) = (0, false),
                         queue: dispatch_queue_t? = nil,
    completionHandler handler: (result: Result<SwiftyJSON.JSON, NSError>) -> Void) -> Request {
        
        let request = URLRequest.URLRequest
        let maxAge = config.maxAge
        request.ll_max_age = maxAge
        let req = Manager.sharedInstance.request(request)
        func goGetData() {
            req.response { (_req, _resp, _data, _err) -> Void in
                var result: Result<SwiftyJSON.JSON, NSError>?
                if let err = _err {
                    result = .Failure(err)
                } else if let resp = _resp, data = _data, req = _req {
                    req.ll_storeResponse(maxAge, resp: resp, data: data)
                    result = .Success(JSON(data: data))
                }
                if let result = result {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        handler(result: result)
                    })
                }
            }
        }
        dispatch_async(queue ?? dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
            if maxAge == 0 {
                goGetData()
            } else {
                if let data = request.ll_lastCachedResponseDataIgnoreExpires(config.ignoreExpires) {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        handler(result: .Success(JSON(data: data)))
                    })
                } else {
                    goGetData()
                }
            }
        })
        return req
}

