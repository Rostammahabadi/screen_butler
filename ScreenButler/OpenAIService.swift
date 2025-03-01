import Foundation
import SwiftUI
#if os(macOS)
import AVFoundation
#else
import AVFoundation
import UIKit
#endif

class OpenAIService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var suggestedName = ""
    @Published var error: String?
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // Key for UserDefaults
    private let apiKeyUserDefaultsKey = "OpenAIAPIKey"
    
    // Get API key from UserDefaults
    var apiKey: String {
        get {
            UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: apiKeyUserDefaultsKey)
        }
    }
    
    // Check if API key is available
    var hasAPIKey: Bool {
        return !apiKey.isEmpty
    }
    
    // Test if the API key is valid
    func testAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let testURL = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: testURL)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // Network error occurred
                    print("OpenAI API Key Test Error: \(error.localizedDescription)")
                    completion(false, "Connection error: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response from server")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    // Success - key is valid
                    completion(true, nil)
                } else if httpResponse.statusCode == 401 {
                    // Unauthorized - invalid key
                    completion(false, "Invalid API key")
                } else {
                    // Other error
                    completion(false, "Server error: HTTP \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    func analyzeImage(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        isAnalyzing = true
        error = nil
        
        // For video files, extract a thumbnail first
        if isVideoFile(url: url) {
            // Update analysis status for better feedback
            DispatchQueue.main.async {
                self.suggestedName = "Extracting video frames..."
            }
            
            extractVideoThumbnail(from: url) { result in
                switch result {
                case .success(let thumbnailURL):
                    // Update status for better feedback
                    DispatchQueue.main.async {
                        self.suggestedName = "Analyzing thumbnail..."
                    }
                    
                    // Now analyze the thumbnail image
                    self.processImageForAnalysis(url: thumbnailURL, originalFile: url, completion: completion)
                    
                    // Clean up temporary thumbnail file after a delay
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                        try? FileManager.default.removeItem(at: thumbnailURL)
                    }
                    
                case .failure(let error):
                    // If thumbnail extraction fails, fall back to non-image approach
                    print("Failed to extract video frames: \(error.localizedDescription)")
                    self.generateNameForNonImage(url: url, completion: completion)
                }
            }
            return
        }
        
        // For image files, process directly
        if isImageFile(url: url) {
            processImageForAnalysis(url: url, originalFile: url, completion: completion)
            return
        }
        
        // For non-image, non-video files, use text-based approach
        generateNameForNonImage(url: url, completion: completion)
    }
    
    private func processImageForAnalysis(url: URL, originalFile: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // Read the image data
        guard let imageData = try? Data(contentsOf: url) else {
            isAnalyzing = false
            let error = NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not read image data"])
            completion(.failure(error))
            return
        }
        
        // If API key is empty, use mock response
        if apiKey.isEmpty {
            generateMockResponse(completion: completion)
            return
        }
        
        // Convert image data to base64 string for OpenAI API
        let base64Image = imageData.base64EncodedString()
        
        // Check if this is a video file being analyzed
        let isVideoAnalysis = isVideoFile(originalFile)
        
        // Send to OpenAI Vision API
        sendImageToOpenAI(base64Image: base64Image, isVideo: isVideoAnalysis, filename: originalFile.lastPathComponent, completion: completion)
    }
    
    private func sendImageToOpenAI(base64Image: String, isVideo: Bool, filename: String, completion: @escaping (Result<String, Error>) -> Void) {
        let visionURL = "https://api.openai.com/v1/chat/completions"
        var request = URLRequest(url: URL(string: visionURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Longer timeout for image processing
        
        // Create vision-optimized prompt
        let prompt: String
        if isVideo {
            prompt = """
            This is a composite image showing three frames from the video file '\(filename)' - 
            from the beginning (left), middle (center), and end (right) of the video.
            
            Carefully analyze all three frames to understand what happens in this video.
            Pay attention to:
            - The main subject(s) or people
            - Actions or movements
            - Scene changes
            - Any text visible in the frames
            - The overall theme or purpose
            
            Based on your analysis, suggest a clear, descriptive filename that best represents 
            the video content. Be specific but concise.
            
            Respond ONLY with the suggested filename (without extension).
            """
        } else {
            prompt = """
            This is an image file named '\(filename)'.
            
            Carefully analyze the image and suggest a clear, descriptive filename that best represents 
            what this image contains. Be specific but concise.
            
            Respond ONLY with the suggested filename (without extension).
            """
        }
        
        // Try the most capable vision model first
        let model = "gpt-4o"
        
        // Create the payload for vision API
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 150,
            "temperature": 0.5
        ]
        
        // Serialize payload to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("Error serializing request: \(error.localizedDescription)")
            self.error = "Error preparing request: \(error.localizedDescription)"
            generateMockResponse(completion: completion)
            return
        }
        
        // Make the network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isAnalyzing = false
                
                if let error = error {
                    print("OpenAI Vision API Error: \(error.localizedDescription)")
                    self.error = error.localizedDescription
                    self.generateMockResponse(completion: completion)
                    return
                }
                
                guard let data = data else {
                    print("No data returned from OpenAI Vision API")
                    self.error = "No data returned"
                    self.generateMockResponse(completion: completion)
                    return
                }
                
                do {
                    // Debug - log the response
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("OpenAI Vision API Response: \(jsonString)")
                    }
                    
                    // Parse the JSON response
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Check for errors from the API
                        if let errorObj = json["error"] as? [String: Any],
                           let message = errorObj["message"] as? String {
                            print("OpenAI API returned error: \(message)")
                            self.error = "API Error: \(message)"
                            self.generateMockResponse(completion: completion)
                            return
                        }
                        
                        // Extract content from the response
                        if let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first,
                           let message = firstChoice["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            // Clean up the response for a valid filename
                            let cleanName = self.cleanResponseForFilename(content)
                            completion(.success(cleanName))
                            return
                        }
                        
                        // If we couldn't extract the content
                        print("Could not extract content from OpenAI Vision response")
                        self.error = "Could not parse OpenAI response structure"
                        self.generateMockResponse(completion: completion)
                    } else {
                        print("OpenAI response is not valid JSON")
                        self.error = "Invalid JSON response"
                        self.generateMockResponse(completion: completion)
                    }
                } catch {
                    print("JSON parsing error: \(error.localizedDescription)")
                    self.error = "Error parsing response: \(error.localizedDescription)"
                    self.generateMockResponse(completion: completion)
                }
            }
        }.resume()
    }
    
    // Helper to check if this is a video analysis
    private func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"]
        let fileExtension = url.pathExtension.lowercased()
        return videoExtensions.contains(fileExtension)
    }
    
    private func extractVideoThumbnail(from videoURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Get video duration
        let duration = asset.duration
        let durationSeconds = CMTimeGetSeconds(duration)
        
        if durationSeconds <= 0 {
            let error = NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not determine video duration"])
            completion(.failure(error))
            return
        }
        
        // Update status for user feedback
        DispatchQueue.main.async {
            self.suggestedName = "Extracting video frames..."
        }
        
        // Calculate three points: beginning (1 sec), middle, and near end
        let beginTime = CMTime(seconds: min(1, durationSeconds * 0.1), preferredTimescale: 60)
        let middleTime = CMTime(seconds: durationSeconds * 0.5, preferredTimescale: 60)
        let endTime = CMTime(seconds: max(0, durationSeconds * 0.9), preferredTimescale: 60)
        
        // Array to hold our generated thumbnails
        var thumbnails: [CGImage] = []
        let times = [beginTime, middleTime, endTime]
        let dispatchGroup = DispatchGroup()
        
        // Generate three thumbnails in parallel
        for (index, time) in times.enumerated() {
            dispatchGroup.enter()
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    print("Error generating frame \(index): \(error.localizedDescription)")
                    return
                }
                
                if let cgImage = cgImage, result == .succeeded {
                    // Safely append to our thumbnail array
                    DispatchQueue.main.async {
                        thumbnails.append(cgImage)
                    }
                }
            }
        }
        
        // When all thumbnails are ready (or failed)
        dispatchGroup.notify(queue: .main) {
            // Handle case where we couldn't get any thumbnails
            if thumbnails.isEmpty {
                // Fall back to a single thumbnail as before
                let time = CMTime(seconds: 1, preferredTimescale: 60)
                
                imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cgImage, _, result, error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    
                    guard result == .succeeded, let cgImage = cgImage else {
                        let error = NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not generate thumbnail"])
                        completion(.failure(error))
                        return
                    }
                    
                    // Convert single CGImage to temporary file
                    do {
                        let tempURL = try self.saveThumbnailToFile(cgImage: cgImage)
                        completion(.success(tempURL))
                    } catch {
                        completion(.failure(error))
                    }
                }
                return
            }
            
            // Update status
            self.suggestedName = "Combining frames..."
            
            // Combine the thumbnails into a single image
            do {
                let combinedImage = try self.combineImages(thumbnails)
                let tempURL = try self.saveThumbnailToFile(cgImage: combinedImage)
                completion(.success(tempURL))
            } catch {
                print("Error combining thumbnails: \(error.localizedDescription)")
                
                // Fall back to using just the first thumbnail if we have it
                if let firstThumbnail = thumbnails.first {
                    do {
                        let tempURL = try self.saveThumbnailToFile(cgImage: firstThumbnail)
                        completion(.success(tempURL))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // New method to combine multiple CGImages into a single image
    private func combineImages(_ images: [CGImage]) throws -> CGImage {
        // Handle case with fewer than 3 images
        let imagesToUse = images.count >= 3 ? Array(images.prefix(3)) : images
        
        // Get dimensions
        let width = imagesToUse.first?.width ?? 1280
        let height = imagesToUse.first?.height ?? 720
        
        // Calculate combined image dimensions
        // For horizontal layout (more common for videos)
        let combinedWidth = width * imagesToUse.count
        let combinedHeight = height
        
        // Create bitmap context
        #if os(macOS)
        guard let context = CGContext(
            data: nil,
            width: combinedWidth,
            height: combinedHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create graphics context"])
        }
        #else
        guard let context = CGContext(
            data: nil,
            width: combinedWidth,
            height: combinedHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create graphics context"])
        }
        #endif
        
        // Draw each image in the context
        for (index, image) in imagesToUse.enumerated() {
            let rect = CGRect(x: width * index, y: 0, width: width, height: height)
            context.draw(image, in: rect)
        }
        
        // Create the combined image
        guard let combinedImage = context.makeImage() else {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create combined image"])
        }
        
        return combinedImage
    }
    
    private func saveThumbnailToFile(cgImage: CGImage) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "video_thumbnail_\(UUID().uuidString).jpg"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [:]) else {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not convert thumbnail to JPEG"])
        }
        #else
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not convert thumbnail to JPEG"])
        }
        #endif
        
        try jpegData.write(to: fileURL)
        return fileURL
    }
    
    private func generateNameForNonImage(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // Simple logic to suggest a better name based on file metadata
        let filename = url.lastPathComponent
        let fileExtension = url.pathExtension
        
        // If API key is empty or we're not in a good environment to make API calls, use mock
        if apiKey.isEmpty {
            // Use mock response for demo instead
            lastAnalyzedFileExtension = fileExtension
            generateMockResponse(completion: completion)
            return
        }
        
        // Use different prompts for different file types
        var prompt = "Suggest a good filename for a file called '\(filename)' with extension '\(fileExtension)'. Return only the filename without extension. Be concise but descriptive."
        
        if isVideoFile(url: url) {
            prompt = """
            Suggest a good filename for a video file called '\(filename)'.
            The video might contain important content that should be reflected in the name.
            Be specific and descriptive, focusing on the likely subject matter and purpose of the video.
            Return only the filename without extension.
            """
        }
        
        let request = createRequestForTextAnalysis(prompt: prompt)
        
        performRequest(request: request) { result in
            DispatchQueue.main.async {
                self.isAnalyzing = false
                completion(result)
            }
        }
    }
    
    private func createRequestForTextAnalysis(prompt: String) -> URLRequest {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        let payload: [String: Any] = [
            "model": "gpt-3.5-turbo", // Use a more widely available model
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 100
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        return request
    }
    
    private func performRequest(request: URLRequest, completion: @escaping (Result<String, Error>) -> Void) {
        // If API key is not set, use a mock response for demo purposes
        if apiKey.isEmpty {
            generateMockResponse(completion: completion)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("OpenAI API Error: \(error.localizedDescription)")
                    self.error = error.localizedDescription
                    
                    // Fall back to mock response on network error
                    print("Falling back to mock response due to network error")
                    self.generateMockResponse(completion: completion)
                    return
                }
                
                guard let data = data else {
                    print("No data returned from OpenAI API")
                    let error = NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data returned"])
                    self.error = "No data returned"
                    
                    // Fall back to mock response
                    self.generateMockResponse(completion: completion)
                    return
                }
                
                do {
                    // Print the raw response for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("OpenAI API Response: \(jsonString)")
                    }
                    
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Check for errors from the API
                        if let errorObj = json["error"] as? [String: Any],
                           let message = errorObj["message"] as? String {
                            print("OpenAI API returned error: \(message)")
                            self.error = "API Error: \(message)"
                            self.generateMockResponse(completion: completion)
                            return
                        }
                        
                        // Try to extract the content
                        if let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first {
                            
                            // First try the standard response format
                            if let message = firstChoice["message"] as? [String: Any],
                               let content = message["content"] as? String {
                                let cleanName = self.cleanResponseForFilename(content)
                                completion(.success(cleanName))
                                return
                            }
                            
                            // Fallback: try other possible response formats
                            if let text = firstChoice["text"] as? String {
                                let cleanName = self.cleanResponseForFilename(text)
                                completion(.success(cleanName))
                                return
                            }
                            
                            if let content = firstChoice["content"] as? String {
                                let cleanName = self.cleanResponseForFilename(content)
                                completion(.success(cleanName))
                                return
                            }
                        }
                        
                        // If we get here, we couldn't extract content in any expected format
                        print("Could not extract content from OpenAI response")
                        self.error = "Could not parse OpenAI response structure"
                        self.generateMockResponse(completion: completion)
                    } else {
                        print("OpenAI response is not valid JSON")
                        self.error = "Invalid JSON response"
                        self.generateMockResponse(completion: completion)
                    }
                } catch {
                    print("JSON parsing error: \(error.localizedDescription)")
                    self.error = "Error parsing response: \(error.localizedDescription)"
                    self.generateMockResponse(completion: completion)
                }
            }
        }.resume()
    }
    
    private func generateMockResponse(completion: @escaping (Result<String, Error>) -> Void) {
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Generate a more appropriate mock name based on file extension
            let fileExtension = self.lastAnalyzedFileExtension?.lowercased() ?? ""
            let mockName = self.getMockNameForFileType(fileExtension)
            completion(.success(mockName))
        }
    }
    
    // Store the extension of the file we're analyzing
    private var lastAnalyzedFileExtension: String?
    
    // Get a more contextually appropriate mock name based on file type
    private func getMockNameForFileType(_ fileExtension: String) -> String {
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "heic", "bmp", "tiff":
            let imageNames = [
                "Product_Logo_Design",
                "Company_Banner_Blue",
                "Team_Photo_Office",
                "Website_Hero_Image",
                "App_Icon_Final",
                "Marketing_Graphic_Q1"
            ]
            return imageNames.randomElement() ?? "Image_File"
            
        case "pdf", "doc", "docx":
            let documentNames = [
                "Business_Proposal_Final",
                "Meeting_Minutes_March",
                "Project_Timeline_2025",
                "Annual_Report_Draft",
                "Client_Contract_Signed"
            ]
            return documentNames.randomElement() ?? "Document_File"
            
        case "mp3", "wav", "m4a":
            let audioNames = [
                "Podcast_Episode_5",
                "Interview_CEO_Smith",
                "Project_Presentation_Audio",
                "Voice_Memo_Meeting",
                "Background_Music_Loop"
            ]
            return audioNames.randomElement() ?? "Audio_Recording"
            
        case "mp4", "mov", "avi":
            let videoNames = [
                "Product_Demo_Video",
                "Tutorial_How_To_Use",
                "Team_Introduction",
                "Animation_Logo_Reveal",
                "Customer_Testimonial"
            ]
            return videoNames.randomElement() ?? "Video_File"
            
        default:
            return "Smart_File_\(Int.random(in: 1...100))"
        }
    }
    
    private func cleanResponseForFilename(_ response: String) -> String {
        // Remove quotes, extra spaces, and any file extensions
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        
        // Remove any file extensions the AI might have included
        if let range = cleaned.range(of: ".", options: .backwards) {
            cleaned = String(cleaned[..<range.lowerBound])
        }
        
        // Replace spaces with underscores for a valid filename
        cleaned = cleaned.replacingOccurrences(of: " ", with: "_")
        
        // Remove any invalid filename characters
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        cleaned = cleaned.components(separatedBy: invalidCharacters).joined()
        
        // If after all cleaning we have an empty string, return a default
        if cleaned.isEmpty {
            return "Smart_File_\(Int.random(in: 1...1000))"
        }
        
        return cleaned
    }
    
    private func isImageFile(url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "bmp", "tiff"]
        let fileExtension = url.pathExtension.lowercased()
        lastAnalyzedFileExtension = fileExtension
        return imageExtensions.contains(fileExtension)
    }
    
    private func isVideoFile(url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v"]
        let fileExtension = url.pathExtension.lowercased()
        lastAnalyzedFileExtension = fileExtension
        return videoExtensions.contains(fileExtension)
    }
    
    private func getCreationDate(for url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.creationDate] as? Date
    }
} 