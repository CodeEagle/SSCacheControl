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

public func request(URLRequest: URLRequestConvertible,
	cacheControlMaxAge config: SSCacheControlConfig = (maxAge: 0, ignoreExpires: false, requestNewAfterRetrunCache: true),
	queue: dispatch_queue_t? = nil,
	printResponse: Bool = false,
	canCacheResultClosure closure: ((result: Result<SwiftyJSON.JSON, NSError>) -> Bool)? = nil,
	completionHandler handler: (result: Result<SwiftyJSON.JSON, NSError>) -> Void) -> Request {

		let request = URLRequest.URLRequest
		let maxAge = config.maxAge
		request.ll_max_age = maxAge
		var cacheHash = 0
		let manager = Manager.sharedInstance
		let previousStartRequestsImmediately = manager.startRequestsImmediately
		manager.startRequestsImmediately = false
		let req = Manager.sharedInstance.request(request)
		func goGetData() {
			manager.startRequestsImmediately = previousStartRequestsImmediately
			req.response { (_req, _resp, _data, _err) -> Void in
				if printResponse { print(_resp) }
				var dataHash = 0
				if let err = _err {
					dispatch_async(dispatch_get_main_queue(), { () -> Void in
						handler(result: .Failure(err))
					})
				} else if let resp = _resp, data = _data, req = _req {
					dataHash = data.description.hash
					let dat: Result<SwiftyJSON.JSON, NSError> = Result.Success(JSON(data: data))
					if let cacheConfigClosure = closure {
						if cacheConfigClosure(result: dat) {
							req.ll_storeResponse(maxAge, resp: resp, data: data)
						}
					} else {
						req.ll_storeResponse(maxAge, resp: resp, data: data)
					}
					if dataHash != cacheHash && dataHash != 0 {
						dispatch_async(dispatch_get_main_queue(), { () -> Void in
							handler(result: dat)
						})
					}
				}
			}
			req.resume()
		}
		dispatch_async(queue ?? dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
			if maxAge == 0 {
				goGetData()
			} else {
				if let data = request.ll_lastCachedResponseDataIgnoreExpires(config.ignoreExpires) {
					cacheHash = data.description.hash
					manager.startRequestsImmediately = previousStartRequestsImmediately
					dispatch_async(dispatch_get_main_queue(), { () -> Void in
						handler(result: .Success(JSON(data: data)))
					})
					if config.requestNewAfterRetrunCache &&
					config.ignoreExpires &&
					request.ll_lastCachedResponseDataIgnoreExpires(false) == nil {
						goGetData()
					}
				} else {
					goGetData()
				}
			}
		})
		return req
}
