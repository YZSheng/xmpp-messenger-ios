//
//  OneMessage.swift
//  OneChat
//
//  Created by Paul on 27/02/2015.
//  Copyright (c) 2015 ProcessOne. All rights reserved.
//

import Foundation
import JSQMessagesViewController
import XMPPFramework

public typealias OneChatMessageCompletionHandler = (_ stream: XMPPStream, _ message: XMPPMessage) -> Void

// MARK: Protocols

public protocol OneMessageDelegate {
	func oneStream(_ sender: XMPPStream, didReceiveMessage message: XMPPMessage, from user: XMPPUserCoreDataStorageObject)
	func oneStream(_ sender: XMPPStream, userIsComposing user: XMPPUserCoreDataStorageObject)
}

open class OneMessage: NSObject {
	open var delegate: OneMessageDelegate?
	
	open var xmppMessageStorage: XMPPMessageArchivingCoreDataStorage?
	var xmppMessageArchiving: XMPPMessageArchiving?
	var didSendMessageCompletionBlock: OneChatMessageCompletionHandler?
	
	// MARK: Singleton
	
	open class var sharedInstance : OneMessage {
		struct OneMessageSingleton {
			static let instance = OneMessage()
		}
		
		return OneMessageSingleton.instance
	}
	
	// MARK: private methods
	
	func setupArchiving() {
		xmppMessageStorage = XMPPMessageArchivingCoreDataStorage.sharedInstance()
		xmppMessageArchiving = XMPPMessageArchiving(messageArchivingStorage: xmppMessageStorage)
		
		xmppMessageArchiving?.clientSideMessageArchivingOnly = true
		xmppMessageArchiving?.activate(OneChat.sharedInstance.xmppStream)
		xmppMessageArchiving?.addDelegate(self, delegateQueue: DispatchQueue.main)
	}
	
	// MARK: public methods
	
	open class func sendMessage(_ message: String, to receiver: String, completionHandler completion:@escaping OneChatMessageCompletionHandler) {
		let body = DDXMLElement.element(withName: "body") as! DDXMLElement
		let messageID = OneChat.sharedInstance.xmppStream?.generateUUID()
		
		body.stringValue = message
		
		let completeMessage = DDXMLElement.element(withName: "message") as! DDXMLElement
		
		completeMessage.addAttribute(withName: "id", stringValue: messageID!)
		completeMessage.addAttribute(withName: "type", stringValue: "chat")
		completeMessage.addAttribute(withName: "to", stringValue: receiver)
		completeMessage.addChild(body)
		
		sharedInstance.didSendMessageCompletionBlock = completion
		OneChat.sharedInstance.xmppStream?.send(completeMessage)
	}
	
	open class func sendIsComposingMessage(_ recipient: String, completionHandler completion:@escaping OneChatMessageCompletionHandler) {
		if recipient.characters.count > 0 {
			let message = DDXMLElement.element(withName: "message") as! DDXMLElement
			message.addAttribute(withName: "type", stringValue: "chat")
			message.addAttribute(withName: "to", stringValue: recipient)
			
			let composing = DDXMLElement.element(withName: "composing", stringValue: "http://jabber.org/protocol/chatstates") as! DDXMLElement
			message.addChild(composing)
			
			sharedInstance.didSendMessageCompletionBlock = completion
			OneChat.sharedInstance.xmppStream?.send(message)
		}
	}
	
	open class func sendIsNotComposingMessage(_ recipient: String, completionHandler completion:@escaping OneChatMessageCompletionHandler) {
		if recipient.characters.count > 0 {
			let message = DDXMLElement.element(withName: "message") as! DDXMLElement
			message.addAttribute(withName: "type", stringValue: "chat")
			message.addAttribute(withName: "to", stringValue: recipient)
			
			let active = DDXMLElement.element(withName: "active", stringValue: "http://jabber.org/protocol/chatstates") as! DDXMLElement
			message.addChild(active)
			
			sharedInstance.didSendMessageCompletionBlock = completion
			OneChat.sharedInstance.xmppStream?.send(message)
		}
	}
	
	open func loadArchivedMessagesFrom(jid: String) -> NSMutableArray {
		let moc = xmppMessageStorage?.mainThreadManagedObjectContext
		let entityDescription = NSEntityDescription.entity(forEntityName: "XMPPMessageArchiving_Message_CoreDataObject", in: moc!)
		let request = NSFetchRequest<NSFetchRequestResult>()
		let predicateFormat = "bareJidStr like %@ "
		let predicate = NSPredicate(format: predicateFormat, jid)
		let retrievedMessages = NSMutableArray()
		
		request.predicate = predicate
		request.entity = entityDescription
		
		do {
			let results = try moc?.fetch(request)
			
			for message in results! {
				var element: DDXMLElement!
				do {
					element = try DDXMLElement(xmlString: (message as AnyObject).messageStr)
				} catch _ {
					element = nil
				}
				
				let body: String
				let sender: String
				let date: Date
				
				date = (message as AnyObject).timestamp
				
				if (message as AnyObject).body() != nil {
					body = (message as AnyObject).body()
				} else {
					body = ""
				}
				
				if element.attributeStringValue(forName: "to") == jid {
					let displayName = OneChat.sharedInstance.xmppStream?.myJID
					sender = displayName!.bare()
				} else {
					sender = jid
				}
				
				let fullMessage = JSQMessage(senderId: sender, senderDisplayName: sender, date: date, text: body)
				retrievedMessages.add(fullMessage)
			}
		} catch _ {
			//catch fetch error here
		}
		return retrievedMessages
	}
	
	open func deleteMessagesFrom(jid: String, messages: NSArray) {
        messages.enumerateObjects({ (message, idx, stop) -> Void in
            let moc = self.xmppMessageStorage?.mainThreadManagedObjectContext
            let entityDescription = NSEntityDescription.entity(forEntityName: "XMPPMessageArchiving_Message_CoreDataObject", in: moc!)
            let request = NSFetchRequest<NSFetchRequestResult>()
            let predicateFormat = "messageStr like %@ "
            let predicate = NSPredicate(format: predicateFormat, message as! String)
            
            request.predicate = predicate
            request.entity = entityDescription
            
            do {
                let results = try moc?.fetch(request)
                
                for message in results! {
                    var element: DDXMLElement!
                    do {
                        element = try DDXMLElement(xmlString: (message as AnyObject).messageStr)
                    } catch _ {
                        element = nil
                    }
                    
                    if element.attributeStringValue(forName: "messageStr") == message as! String {
                        moc?.delete(message as! NSManagedObject)
                    }
                }
            } catch _ {
                //catch fetch error here
            }
        })
	}
}

extension OneMessage: XMPPStreamDelegate {
	
	public func xmppStream(_ sender: XMPPStream, didSend message: XMPPMessage) {
		if let completion = OneMessage.sharedInstance.didSendMessageCompletionBlock {
			completion(sender, message)
		}
		//OneMessage.sharedInstance.didSendMessageCompletionBlock!(stream: sender, message: message)
	}
	
	public func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
		let user = OneChat.sharedInstance.xmppRosterStorage.user(for: message.from(), xmppStream: OneChat.sharedInstance.xmppStream, managedObjectContext: OneRoster.sharedInstance.managedObjectContext_roster())
		
		if !OneChats.knownUserForJid(jidStr: (user?.jidStr)!) {
			OneChats.addUserToChatList(jidStr: (user?.jidStr)!)
		}
		
		if message.isChatMessageWithBody() {
			OneMessage.sharedInstance.delegate?.oneStream(sender, didReceiveMessage: message, from: user!)
		} else {
			//was composing
			if let _ = message.forName("composing") {
				OneMessage.sharedInstance.delegate?.oneStream(sender, userIsComposing: user!)
			}
		}
	}
}
