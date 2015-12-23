//
//  ViewController.swift
//  SSRequest
//
//  Created by CodeEagle on 12/22/2015.
//  Copyright (c) 2015 CodeEagle. All rights reserved.
//

import UIKit
import SSCacheControl
import Alamofire
final class ViewController: UIViewController {

    @IBOutlet weak var logView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    private struct URLTest: URLRequestConvertible {
        var URLRequest: NSMutableURLRequest {
            return NSMutableURLRequest(URL: NSURL(string: "https://httpbin.org/cache/0")!)
        }
    }
    
    
    @IBAction func startTest(sender: AnyObject) {
        logView.text = "requesting..."
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            request(URLTest(), cacheControlMaxAge: (maxAge: 10, ignoreExpires: false), completionHandler: {[weak self] (result) -> Void in
                let text = "success:\n\(result.isSuccess)\n"
                var desc = ""
                if result.isSuccess {
                    desc = result.value?.description ?? ""
                } else {
                    desc = result.error?.localizedDescription ?? ""
                }
                self?.logView.text = text + "data:\n" + desc
            })
        }
        
    }
}

