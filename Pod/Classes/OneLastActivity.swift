//
//  OneLastActivity.swift
//  XMPP-Messenger-iOS
//
//  Created by Sean Batson on 2015-09-18.
//  Edited by Paul LEMAIRE on 2015-10-09.
//  Copyright © 2015 ProcessOne. All rights reserved.
//

import Foundation
import XMPPFramework

public typealias OneMakeLastCallCompletionHandler = (_ response: XMPPIQ?, _ forJID:XMPPJID?, _ error: DDXMLElement?) -> Void

open class OneLastActivity: NSObject {
	
	var didMakeLastCallCompletionBlock: OneMakeLastCallCompletionHandler?
	
	// MARK: Singleton
	
	open class var sharedInstance : OneLastActivity {
		struct OneLastActivitySingleton {
			static let instance = OneLastActivity()
		}
		return OneLastActivitySingleton.instance
	}
	
	// MARK: Public Functions
	
	open func getStringFormattedDateFrom(_ second: UInt) -> NSString {
		if second > 0 {
			let time = NSNumber(value: second as UInt)
			let interval = time.doubleValue
			let elapsedTime = Date(timeIntervalSince1970: interval)
			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "HH:mm:ss"
			
			return dateFormatter.string(from: elapsedTime) as NSString
		} else {
			return ""
		}
	}
	
	open func getStringFormattedElapsedTimeFrom(_ date: Date!) -> String {
		var elapsedTime = "nc"
		let startDate = Date()
		let components = (Calendar.current as NSCalendar).components(NSCalendar.Unit.day, from: date, to: startDate, options: NSCalendar.Options.matchStrictly)
		
		if nil == date {
			return elapsedTime
		}
		
		if 52 < components.weekOfYear! {
			elapsedTime = "more than a year"
		} else if 1 <= components.weekOfYear! {
			if 1 < components.weekOfYear! {
				elapsedTime = "\(components.weekOfYear) weeks"
			} else {
				elapsedTime = "\(components.weekOfYear) week"
			}
		} else if 1 <= components.day! {
			if 1 < components.day! {
				elapsedTime = "\(components.day) days"
			} else {
				elapsedTime = "\(components.day) day"
			}
		} else if 1 <= components.hour! {
			if 1 < components.hour! {
				elapsedTime = "\(components.hour) hours"
			} else {
				elapsedTime = "\(components.hour) hour"
			}
		} else if 1 <= components.minute! {
			if 1 < components.minute! {
				elapsedTime = "\(components.minute) minutes"
			} else {
				elapsedTime = "\(components.minute) minute"
			}
		} else if 1 <= components.second! {
			if 1 < components.second! {
				elapsedTime = "\(components.second) seconds"
			} else {
				elapsedTime = "\(components.second) second"
			}
		} else {
			elapsedTime = "now"
		}
		
		return elapsedTime
	}
	
	open class func sendLastActivityQueryToJID(_ userName: String, sender: XMPPLastActivity? = nil, completionHandler completion:@escaping OneMakeLastCallCompletionHandler) {
		sharedInstance.didMakeLastCallCompletionBlock = completion
        let userJID = XMPPJID(string: userName)
		
		sender?.sendQuery(to: userJID)
	}
}

extension OneLastActivity: XMPPLastActivityDelegate {
	
	public func xmppLastActivity(_ sender: XMPPLastActivity!, didNotReceiveResponse queryID: String!, dueToTimeout timeout: TimeInterval) {
		if let callback = OneLastActivity.sharedInstance.didMakeLastCallCompletionBlock {
			callback(nil, nil ,DDXMLElement(name: "TimeOut"))
		}
	}
	
	public func xmppLastActivity(_ sender: XMPPLastActivity!, didReceiveResponse response: XMPPIQ!) {
		if let callback = OneLastActivity.sharedInstance.didMakeLastCallCompletionBlock {
			if let resp = response {
				if resp.forName("error") != nil {
					if let from = resp.value(forKey: "from") {
                        callback(resp, XMPPJID(string: "\(from)"), resp.forName("error"))
					} else {
						callback(resp, nil, resp.forName("error"))
					}
				} else {
					if let from = resp.attribute(forName: "from") {
                        callback(resp, XMPPJID(string: "\(from)"), nil)
					} else {
						callback(resp, nil, nil)
					}
				}
			}
		}
	}
	
	public func numberOfIdleTimeSeconds(for sender: XMPPLastActivity!, queryIQ iq: XMPPIQ!, currentIdleTimeSeconds idleSeconds: UInt) -> UInt {
		return 30
	}
}
