//
//  Post Utils.swift
//  OpenArtemis
//
//  Created by Ethan Bills on 11/28/23.
//

import Foundation
import CoreData
import Defaults

struct Post: Equatable, Hashable, Codable {
    let id: String
    let subreddit: String
    let title: String
    let author: String
    let votes: String
    let mediaURL: PrivateURL
    let commentsURL: String
    let type: String
    // If post media has a thumbnail...
    let thumbnailURL: String?
    // Ensure that PrivateURL also conforms to Codable
    struct PrivateURL: Codable {
        let originalURL: String
        let privateURL: String
    }
    
    // Conform to Codable
    enum CodingKeys: String, CodingKey {
        case id, subreddit, title, author, votes, mediaURL, commentsURL, type, thumbnailURL
    }

    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Don't do drugs kids
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(subreddit)
        hasher.combine(title)
        hasher.combine(author)
        hasher.combine(votes)
        hasher.combine(commentsURL)
        hasher.combine(mediaURL.originalURL)
        hasher.combine(mediaURL.privateURL)
        hasher.combine(type)
        hasher.combine(thumbnailURL)
    }
}


class PostUtils {
    // Singleton instance
    static let shared = PostUtils()

    // Private initializer to enforce singleton pattern
    private init() {}
    
    // General utilities
    
    /// Determines the type of a post based on its media URL.
    ///
    /// - Parameter mediaURL: The media URL of the post.
    /// - Returns: A string representing the type of the post (e.g., "text", "image", "video").
    func determinePostType(mediaURL: String) -> String {
        let mediaURL = mediaURL.lowercased()
        
        if mediaURL.contains("/r/") && mediaURL.contains("/comments/") {
            return "text"
        } else if mediaURL.contains("reddit.com/gallery/") {
            return "gallery"
        } else if mediaURL.hasSuffix(".png") || mediaURL.hasSuffix(".jpg") || mediaURL.hasSuffix(".jpeg") {
            return "image"
        } else if mediaURL.hasSuffix(".gif") || mediaURL.hasSuffix(".gifv") {
            return "gif"
        } else if mediaURL.contains("v.redd.it") || mediaURL.hasSuffix(".mp4") {
            return "video"
        } else {
            return "article"
        }
    }

    // Core Data integration
    
    /// Converts a `SavedPost` entity to a tuple containing the saved timestamp and a corresponding `Post`.
    ///
    /// - Parameters:
    ///   - context: The Core Data managed object context.
    ///   - post: The `SavedPost` entity to convert.
    /// - Returns: A tuple containing the saved timestamp and the corresponding `Post`.
    func savedPostToPost(context: NSManagedObjectContext, post: SavedPost) -> (Date?, Post) {
        return (
            post.savedTimestamp,
            Post(
                id: post.id ?? "",
                subreddit: post.subreddit ?? "",
                title: post.title ?? "",
                author: post.author ?? "",
                votes: post.votes ?? "",
                mediaURL: Post.PrivateURL(originalURL: post.mediaURL ?? "", privateURL: post.mediaURL ?? ""),
                commentsURL: post.commentsURL ?? "",
                type: post.type ?? "",
                thumbnailURL: post.thumbnailURL ?? ""
            )
        )
    }

    /// Saves a `Post` entity to Core Data.
    ///
    /// - Parameters:
    ///   - context: The Core Data managed object context.
    ///   - post: The `Post` to save.
    func savePost(context: NSManagedObjectContext, post: Post) {
        @Default(.redirectToPrivateSites) var privULR
        let tempPost = SavedPost(context: context)
        tempPost.author = post.author
        tempPost.subreddit = post.subreddit
        tempPost.commentsURL = post.commentsURL
        tempPost.id = post.id
        tempPost.mediaURL = privULR ? post.mediaURL.privateURL : post.mediaURL.originalURL
        tempPost.thumbnailURL = post.thumbnailURL
        tempPost.title = post.title
        tempPost.type = post.type
        tempPost.votes = post.votes
        tempPost.savedTimestamp = Date()

        DispatchQueue.main.async {
            do {
                try context.save()
            } catch {
                print("Error removing saved post: \(error)")
            }
        }
    }
    
    /// Toggles the saved status of a `Post` entity.
    ///
    /// - Parameters:
    ///   - context: The Core Data managed object context.
    ///   - post: The `Post` to toggle.
    /// - Returns: A boolean indicating whether the post is now saved.
    func toggleSaved(context: NSManagedObjectContext, post: Post) -> Bool {
        if let savedPost = fetchSavedPost(context: context, id: post.id) {
            removeSavedPost(context: context, savedPost: savedPost)
            return false
        } else {
            savePost(context: context, post: post)
            return true
        }
    }

    /// Removes a saved `Post` entity from Core Data.
    ///
    /// - Parameters:
    ///   - context: The Core Data managed object context.
    ///   - savedPost: The `SavedPost` entity to remove.
    func removeSavedPost(context: NSManagedObjectContext, savedPost: SavedPost) {
        context.delete(savedPost)
        
        DispatchQueue.main.async {
            do {
                try context.save()
            } catch {
                print("Error removing saved post: \(error)")
            }
        }
    }


    /// Fetches all saved `Post` entities from Core Data.
    ///
    /// - Parameter context: The Core Data managed object context.
    /// - Returns: An array of `SavedPost` entities.
    func fetchSavedPosts(context: NSManagedObjectContext) -> [SavedPost] {
        do {
            return try context.fetch(SavedPost.fetchRequest())
        } catch {
            print("Error fetching saved posts: \(error)")
            return []
        }
    }

    /// Fetches a specific saved `Post` entity from Core Data based on its identifier.
    ///
    /// - Parameters:
    ///   - context: The Core Data managed object context.
    ///   - id: The identifier of the post to fetch.
    /// - Returns: The fetched `SavedPost` entity or nil if not found.
    func fetchSavedPost(context: NSManagedObjectContext, id: String) -> SavedPost? {
        let request: NSFetchRequest<SavedPost> = SavedPost.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        var savedPost: SavedPost? = nil
        
        do {
            savedPost = try context.fetch(request).first
        } catch {
            print("Error fetching saved post: \(error)")
        }
        
        return savedPost
    }
}
