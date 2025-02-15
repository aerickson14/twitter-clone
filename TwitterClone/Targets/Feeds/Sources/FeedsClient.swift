//
//  FeedsClient.swift
//  TwitterCloneFeeds
//
//  Created by Jeroen Leenarts on 18/01/2023.
//  Copyright © 2023 Stream.io Inc.  All rights reserved.
//

import Foundation
import SwiftUI
import Auth
import NetworkKit
import os.log

private struct FollowParamModel: Encodable {
    let target: String
    let activity_copy_limit: Int
    
    enum CodingKeys: CodingKey {
        case target
        case activity_copy_limit
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("user:" + self.target, forKey: .target)
        try container.encode(self.activity_copy_limit, forKey: .activity_copy_limit)
    }
}

private struct ReplyReactionParamModel: Encodable {
    let kind = ReactionType.reply
    let activityId: String
    let reply: String
    
    enum CodingKeys: String, CodingKey {
        case kind
        case activityId = "activity_id"
        case data
        case reply
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encode(activityId, forKey: .activityId)
        var dataContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .data)
        try dataContainer.encode(reply, forKey: .reply)
    }
}

private struct LikeReactionParamModel: Encodable {
    let kind = ReactionType.like
    let activityId: String
    
    enum CodingKeys: String, CodingKey {
        case kind
        case activityId = "activity_id"
        case data
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encode(activityId, forKey: .activityId)
    }
}

private struct UnfollowParamModel: Encodable {
    let keep_history: Bool
}

public struct PagingModel: Encodable {
    let limit: Int
    let offset: Int

    func appendingPagingModel(to url: URL) -> URL {
        return url.appending(queryItems:
            [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ])
    }

}

public struct FileResultModel: Decodable {
    let duration: String
    let file: String
}

public enum ReactionType: String {
    case like
    case reply
}

public enum FeedError: Error {
    case unexpectedResponse
}

@MainActor
public class FeedsClient: ObservableObject {
    public internal ( set ) var authUser: AuthUser
    
    private let mockEnabled: Bool

    private let urlFactory: URLFactory

    public static func productionClient(authUser: AuthUser, region: Region = .euWest) -> FeedsClient {
        return FeedsClient(authUser: authUser, urlString: region.rawValue)
    }

    public static func previewClient() throws -> FeedsClient {
        return FeedsClient(authUser: AuthUser.previewUser(), urlString: Region.euWest.rawValue, mockEnabled: true)
    }

    private init(authUser: AuthUser, urlString: String, mockEnabled: Bool = false) {
        // swiftlint:disable:next force_unwrapping
        urlFactory = URLFactory(baseUrl: URL(string: urlString)!)
        self.authUser = authUser
        self.mockEnabled = mockEnabled
    }

    public func user(id: String? = nil) async throws -> FeedUser {
        let session = TwitterCloneNetworkKit.restSession

        let userId = id ?? authUser.userId
        let feedToken = authUser.feedToken

        var request = URLRequest(url: urlFactory.url(forPath: .user(userId: userId)))
        request.httpMethod = "GET"

        // Headers
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        if OSLog.networkPayloadLog.isEnabled(type: .debug) {
            os_log(.debug, "user request: %{public}@", request.url?.description ?? "")
        }
        let (data, response) = try await session.data(for: request)

        if OSLog.networkPayloadLog.isEnabled(type: .debug) {
            os_log(.debug, "user response: %{public}@", String(data: data, encoding: .utf8) ?? "")
        }
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)

        return try TwitterCloneNetworkKit.jsonDecoder.decode(FeedUser.self, from: data)
    }

    public func updateUser(_ user: FeedUser) async throws {
        let session = TwitterCloneNetworkKit.restSession

        let userId = authUser.userId
        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .user(userId: userId)))
        request.httpMethod = "PUT"
        request.httpBody = try TwitterCloneNetworkKit.jsonEncoder.encode(user)

        // Headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)
    }

    public func createUser(_ user: NewFeedUser) async throws -> FeedUser {
        let session = TwitterCloneNetworkKit.restSession

        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .user(userId: nil)))
        request.httpMethod = "POST"
        request.httpBody = try TwitterCloneNetworkKit.jsonEncoder.encode(user)

        // Headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)

        return try TwitterCloneNetworkKit.jsonDecoder.decode(FeedUser.self, from: data)
    }

    public func follow(target: String, activityCopyLimit: Int) async throws {
        let session = TwitterCloneNetworkKit.restSession

        let userId = authUser.userId
        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .follow(userId: userId)))
        request.httpMethod = "POST"
        let httpBody = try TwitterCloneNetworkKit.jsonEncoder.encode(FollowParamModel(target: target, activity_copy_limit: activityCopyLimit))
        request.httpBody = httpBody
        
        if OSLog.networkPayloadLog.isEnabled(type: .debug) {
            os_log(.debug, "follow request: %{public}@\n%{public}@", request.url?.description ?? "", String(data: httpBody, encoding: .utf8) ?? "")
        }

        // Headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        if OSLog.networkPayloadLog.isEnabled(type: .debug) {
            os_log(.debug, "follow response: %{public}@", String(data: data, encoding: .utf8) ?? "")
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)
    }

    public func unfollow(target: String, keepHistory: Bool) async throws {
        let session = TwitterCloneNetworkKit.restSession

        let userId = authUser.userId
        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .unfollow(userId: userId, target: target)))
        request.httpMethod = "DELETE"

        request.httpBody = try TwitterCloneNetworkKit.jsonEncoder.encode(UnfollowParamModel(keep_history: keepHistory))

        // Headers
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)
    }

    public func followers(feedId: String, pagingModel: PagingModel? = nil) async throws -> [FeedFollower] {
        let session = TwitterCloneNetworkKit.restSession

        let userId = authUser.userId
        let feedToken = authUser.feedToken
        var url = urlFactory.url(forPath: .followers(userId: userId))
        url = pagingModel?.appendingPagingModel(to: url) ?? url

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Headers
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)

        return try TwitterCloneNetworkKit.jsonDecoder.decode(ResultResponse<[FeedFollower]>.self, from: data).results
    }

    public func following(pagingModel: PagingModel? = nil) async throws -> [FeedFollower] {
        let session = TwitterCloneNetworkKit.restSession

        let userId = authUser.userId
        let feedToken = authUser.feedToken
        var url = urlFactory.url(forPath: .follows(userId: userId))
        url = pagingModel?.appendingPagingModel(to: url) ?? url

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Headers
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)

        return try TwitterCloneNetworkKit.jsonDecoder.decode(ResultResponse<[FeedFollower]>.self, from: data).results
    }

    public func getUserActivities(userId: String) async throws -> [EnrichedPostActivity] {
        if mockEnabled {
            return EnrichedPostActivity.previewPostActivities()
        }
        let session = TwitterCloneNetworkKit.restSession

        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .userFeed(userId: userId)))
        request.httpMethod = "GET"

        // Headers
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)

        if OSLog.networkPayloadLog.isEnabled(type: .debug) {
            os_log(.debug, "getactivities response: %{public}@", String(data: data, encoding: .utf8) ?? "")
        }

        return try TwitterCloneNetworkKit.jsonDecoder.decode(ResultResponse<[EnrichedPostActivity]>.self, from: data).results
    }
    // TODO: paging
    public func getTimelineActivities() async throws -> [EnrichedPostActivity] {
        if mockEnabled {
            return EnrichedPostActivity.previewPostActivities()
        }
        let session = TwitterCloneNetworkKit.restSession

        let userId = authUser.userId
        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .timelineFeed(userId: userId)))
        request.httpMethod = "GET"

        // Headers
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)

        if OSLog.networkPayloadLog.isEnabled(type: .debug) {
            os_log(.debug, "getactivities response: %{public}@", String(data: data, encoding: .utf8) ?? "")
        }

        return try TwitterCloneNetworkKit.jsonDecoder.decode(ResultResponse<[EnrichedPostActivity]>.self, from: data).results
    }

    public func addActivity(_ activity: PostActivity) async throws {
        let session = TwitterCloneNetworkKit.restSession

        let userId = authUser.userId
        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .userFeed(userId: userId)))
        request.httpMethod = "POST"
        request.httpBody = try TwitterCloneNetworkKit.jsonEncoder.encode(activity)

        // Headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)
    }
    
    public func addReaction(_ activityId: String, reactionType: ReactionType, reply: String) async throws {
        let session = TwitterCloneNetworkKit.restSession
        
        let reaction = ReplyReactionParamModel(activityId: activityId, reply: reply)

        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .reaction(activityId: nil)))
        request.httpMethod = "POST"
        request.httpBody = try TwitterCloneNetworkKit.jsonEncoder.encode(reaction)

        // Headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)
    }
    
    public func addLike(_ activityId: String) async throws {
        let session = TwitterCloneNetworkKit.restSession
        
        let reaction = LikeReactionParamModel(activityId: activityId)

        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .reaction(activityId: nil)))
        request.httpMethod = "POST"
        request.httpBody = try TwitterCloneNetworkKit.jsonEncoder.encode(reaction)

        // Headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)
    }

    public func uploadImage(fileName: String, mimeType: String, imageData: Data) async throws -> URL {
        let session = TwitterCloneNetworkKit.restSession

        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .images))
        request.httpMethod = "POST"

        var multipart = MultipartRequest()
        multipart.add(key: "file", fileName: fileName, fileMimeType: mimeType, fileData: imageData)

        request.setValue(multipart.httpContentTypeHeadeValue, forHTTPHeaderField: "Content-Type")
        request.httpBody = multipart.httpBody

        if OSLog.networkPayloadLog.isEnabled(type: .debug) {
            os_log(.debug, "upload image request body: %{public}@", String(data: multipart.httpBody, encoding: .utf8) ?? "")
        }

        // Headers
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        
        if OSLog.networkPayloadLog.isEnabled(type: .debug) {
            os_log(.debug, "upload image response: %{public}@", String(data: data, encoding: .utf8) ?? "")
        }
        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)

        let fileResult = try TwitterCloneNetworkKit.jsonDecoder.decode(FileResultModel.self, from: data)
        return try convertToURL(fileResult.file)
    }

    public func deleteImage(cdnUrl: String) async throws {
        let session = TwitterCloneNetworkKit.restSession

        let feedToken = authUser.feedToken
        var request = URLRequest(url: urlFactory.url(forPath: .images))
        request.httpMethod = "DELETE"
        request.httpBody = cdnUrl.data(using: .utf8)

        // Headers
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)
    }

    public func processImage(cdnUrl: String, resize: CdnImageResizeStrategy? = nil, crop: CdnImageCropStrategy? = nil, width: Int? = nil, height: Int? = nil) async throws -> URL {
        let session = TwitterCloneNetworkKit.restSession

        let feedToken = authUser.feedToken
        var url = urlFactory.url(forPath: .images)

        let queryItems = [
            resize.map { URLQueryItem(name: "resize", value: $0.rawValue) },
            crop.map { URLQueryItem(name: "crop", value: $0.rawValue) },
            width.map { URLQueryItem(name: "w", value: "\($0)") },
            height.map { URLQueryItem(name: "h", value: "\($0)") },
            URLQueryItem(name: "url", value: cdnUrl)
        ].compactMap { $0 }

        url.append(queryItems: queryItems)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Headers
        request.addValue("jwt", forHTTPHeaderField: "Stream-Auth-Type")
        request.addValue(feedToken, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode

        try TwitterCloneNetworkKit.checkStatusCode(statusCode: statusCode)

        let fileUrl = try TwitterCloneNetworkKit.jsonDecoder.decode(String.self, from: data)
        return try convertToURL(fileUrl)
    }
    
    private func convertToURL(_ urlString: String) throws -> URL {
        guard let result = URL(string: urlString) else {
            throw FeedError.unexpectedResponse
        }
        return result
    }
}

public enum CdnImageResizeStrategy: String {
    case crop, scale, fill
}
public enum CdnImageCropStrategy: String {
    case top, bottom, left, right, center
}
