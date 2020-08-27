//
//  TealiumRemoteCommand.swift
//  tealium-swift
//
//  Created by Jonathan Wong on 1/31/18.
//  Copyright © 2018 Tealium, Inc. All rights reserved.
//
#if os(iOS)
import Foundation
#if remotecommands
import TealiumCore
#endif

/// Designed to be subclassed. Allows Remote Commands to be created by host apps,
/// and called on-demand by the Tag Management module
open class TealiumRemoteCommand {

    let commandId: String
    weak var delegate: TealiumRemoteCommandDelegate?
    var description: String?
    static var urlSession: URLSessionProtocol = URLSession.shared
    public let remoteCommandCompletion: ((_ response: TealiumRemoteCommandResponse) -> Void)

    /// Constructor for a Tealium Remote Command.
    ///
    /// - Parameters:
    ///     - commandId: `String` identifier for command block.
    ///     - description: `String?` description of command.
    ///     - urlSession: `URLSessionProtocol`
    ///     - completion: The completion block to run when this remote command is triggered.
    public init(commandId: String,
                description: String?,
                completion : @escaping ((_ response: TealiumRemoteCommandResponse) -> Void)) {

        self.commandId = commandId
        self.description = description
        self.remoteCommandCompletion = completion
    }

    /// Called when a Remote Command is ready for execution.
    ///￼
    /// - Parameter response: `TealiumRemoteCommandResponse` object containing information from the TiQ webview
    func completeWith(response: TealiumRemoteCommandResponse) {
        TealiumQueues.backgroundSerialDispatchQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.delegate?.tealiumRemoteCommandRequestsExecution(self,
                                                            response: response)
        }
    }

    /// Sends a notification to the TiQ webview when the remote command has finished executing.
    ///
    /// - Parameters:
    ///     - commandId: `String` identifier for the Remote Command
    ///     - response: `TealiumRemoteCommandResponse` from the remote command to be passed back to the TiQ webview
    public class func sendCompletionNotification(for commandId: String,
                                                 response: TealiumRemoteCommandResponse) {
        guard let responseId = response.responseId() else {
            return
        }
        guard TealiumRemoteCommands.pendingResponses.value[responseId] == true else {
            return
        }
        TealiumRemoteCommands.pendingResponses.value[responseId] = nil
        guard let notification = TealiumRemoteCommand.completionNotification(for: commandId,
                                                                             response: response) else {
                                                                                        return
        }
        NotificationCenter.default.post(notification)
    }

    /// Generates a completion notification for a specific Remote Command response.
    ///
    /// - Parameters:
    ///     - commandId: `String` identifier for the Remote Command
    ///     - response: `TealiumRemoteCommandResponse` from the remote command to be passed back to the TiQ webview
    ///     - Returns: `Notification?`  containing the encoded JavaScript string for the TiQ webview.
    class func completionNotification(for commandId: String,
                                      response: TealiumRemoteCommandResponse) -> Notification? {
        guard let responseId = response.responseId() else {
            return nil
        }

        var responseStr: String
        if let responseData = response.data {
            responseStr = String(data: responseData, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
        } else {
            // keep previous behavior from obj-c library
            responseStr = "(null)"
        }

        let jsString = "try { utag.mobile.remote_api.response['\(commandId)']['\(responseId)']('\(response.status)','\(responseStr)')} catch(err) {console.error(err)}"
        let notificationName = Notification.Name(rawValue: TealiumKey.jsNotificationName)
        let notification = Notification(name: notificationName,
                                        object: self,
                                        userInfo: [TealiumRemoteHTTPCommandKey.jsCommand: jsString])
        return notification
    }
}
#endif
