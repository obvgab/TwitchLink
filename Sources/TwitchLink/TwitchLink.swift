import Foundation

/*
 Beginning of Token structures
 Tokens are given in a 3-level JSON format, necessary information is saved as such:
    data: {
        stream/videoPlaybackAcessToken (depends on whether the content is a VOD or not): {
            value: "{Long Stringified JSON}"
            signature: "Signature String"
        }
    }
 The stream/videoPlaybackAccessToken is handled via optional variables, isVod parameter is used to check which one to unwrap.
*/
struct tokenStruct: Codable {
    var data: tokenSecondLevel
}
struct tokenSecondLevel: Codable {
    var streamPlaybackAccessToken: tokenLastLevel?
    var videoPlaybackAccessToken: tokenLastLevel?
}
struct tokenLastLevel: Codable {
    var value: String
    var signature: String
}

/*
 Beginning of List structure
 Playlist of URLs are given in plaintext, separated by \n
 Necessary information is taken and put into an array for access.
*/
public struct listStruct: Codable {
    public var quality: String
    public var resolution: String
    public var url: String
}

// Code adapted from twitch-m3u8, originally node.js
@available(macOS 12.0.0, iOS 15.0.0, *)
public struct StreamLink {
    // Client ID derived from streamlink on Github
    public var clientID: String?
    
    public init(clientID: String) {
        self.clientID = clientID
    }
    
    // Retrieving access token from Twitch from ID (VOD or Stream)
    func getToken(id: String, isVod: Bool) async -> tokenStruct {
        var request = URLRequest(url: URL(string: "https://gql.twitch.tv/gql")!)
        request.setValue(clientID, forHTTPHeaderField: "Client-id")
        request.httpMethod = "POST"
        let (responseData, response) = try! await URLSession.shared.upload(
            for: request,
            from: try! JSONSerialization.data(
                withJSONObject: [
                    "operationName": "PlaybackAccessToken",
                    "extensions": [
                        "persistedQuery": [
                            "version": 1,
                            "sha256Hash": "0828119ded1c13477966434e15800ff57ddacf13ba1911c129dc2200705b0712"
                        ]
                    ],
                    "variables": [
                        "isLive": !isVod,
                        "login": (isVod ? "" : id),
                        "isVod": isVod,
                        "vodID": (isVod ? id : ""),
                        "playerType": "embed"
                    ]
                ], options: []))
        let httpResponse = response as! HTTPURLResponse
        if httpResponse.statusCode != 200 {
            print("Assumed error occured: Status code is not 200, got \(httpResponse.statusCode)")
        } else {
            do {
                return try JSONDecoder().decode(tokenStruct.self, from: responseData)
            } catch {
                print("Return error occured: Parsing or serialization failure")
            }
        }
        fatalError()
    }
    
    // Retrieving the playlist from a given ID and access token (VOD and Stream)
    func getList(id: String, token: tokenStruct, isVod: Bool) async -> Data {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "usher.ttvnw.net"
        urlComponents.path = "/\(isVod ? "vod" : "api/channel/hls")/\(id).m3u8"
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientID!),
            URLQueryItem(name: "token", value: (isVod ? token.data.videoPlaybackAccessToken!.value : token.data.streamPlaybackAccessToken!.value)),
            URLQueryItem(name: "sig", value: (isVod ? token.data.videoPlaybackAccessToken!.signature : token.data.streamPlaybackAccessToken!.signature)),
            URLQueryItem(name: "allow_source", value: "true"),
            URLQueryItem(name: "allow_audio_only", value: "true")
        ]
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        let (responseData, response) = try! await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        switch(httpResponse.statusCode) {
            case 200:
                return responseData
            case 404:
                print("404 error occured: Transcode doesn't exist/Stream is offline")
            default:
                print("Unexpected error occured: Twtich returned status code \(httpResponse.statusCode)")
        }
        fatalError()
    }
    
    // Parse playlist from the previous data to get direct stream links (.m3u8 links)
   func parseList(list: Data) -> [listStruct] {
        var parsedList = [listStruct]()
        let lines = String(data: list, encoding: .utf8)!.split(separator: "\n")
        for i in 4..<lines.count where (i - 4) % 3 == 0 {
            parsedList.append(
                listStruct(
                    quality: String(lines[i - 2]),
                    resolution: String(lines[i - 1]),
                    url: String(lines[i])
                )
            )
        }
        return parsedList
    }
    
    // Public function to provide a parsed list of available .m3u8 stream links, uses Task to await
    public func getStream(_ streamer: String) async -> [listStruct] {
        return parseList(list: await getList(id: streamer, token: await getToken(id: streamer, isVod: false), isVod: false))
    }
    
    // Public function to provide a parsed list of available .m3u8 video links, uses Task to await
    public func getVod(_ video: String) async -> [listStruct] {
        return parseList(list: await getList(id: video, token: await getToken(id: video, isVod: true), isVod: true))
    }
}
