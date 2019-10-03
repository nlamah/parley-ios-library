import Alamofire
import AlamofireImage
import AlamofireObjectMapper
import ObjectMapper
import TrustKit
import SwiftGifOrigin

internal class ParleyRemote {
    
    internal static let sessionManager: Alamofire.SessionManager = {
        let configuration = URLSessionConfiguration.default
        
        return Alamofire.SessionManager(configuration: configuration)
    }()
    
    internal static func refresh(_ network: ParleyNetwork) {
        guard let domain = URL(string: network.url)?.host else {
            fatalError("ParleyRemote: Invalid url")
        }
        
        let configuration = [
            kTSKPinnedDomains: [
                domain: [
                    kTSKPublicKeyHashes: [
                        network.pin1,
                        network.pin2
                    ],
                    kTSKEnforcePinning: true,
                    kTSKReportUris: []
                ]
            ]
        ]
        
        let trustKit = TrustKit(configuration: configuration)
        
        sessionManager.delegate.taskDidReceiveChallengeWithCompletion = { session, task, challenge, completionHandler in
            let pinningValidator = trustKit.pinningValidator
            if !pinningValidator.handle(challenge, completionHandler: completionHandler) {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
    
    private static func getHeaders() -> [String: String] {
        var headers = Parley.shared.network.headers
        guard let secret = Parley.shared.secret, let uuid = UIDevice.current.identifierForVendor?.uuidString else {
            fatalError("ParleyRemote: Secret or device uuid not set")
        }
        headers["x-iris-identification"] = "\(secret):\(uuid)"
        
        if let userAuthorization = Parley.shared.userAuthorization {
            headers["Authorization"] = userAuthorization
        }
        
        return headers
    }
    
    private static func getUrl(_ path: String) -> String {
        return Parley.shared.network.url + Parley.shared.network.path + path
    }
    
    // MARK: Execute request
    @discardableResult internal static func execute<T: BaseMappable>(_ method: HTTPMethod, _ path: String, parameters: Parameters?=nil, keyPath: String?="data", onSuccess: @escaping (_ items: [T])->(), onFailure: @escaping (_ error: Error)->()) -> DataRequest {
        debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path)) \(parameters ?? [:])")
        
        let request = sessionManager.request(getUrl(path), method: method, parameters: parameters, headers: getHeaders())
        request.validate(statusCode: 200...299).responseArray(keyPath: keyPath) { (response: DataResponse<[T]>) in
            switch response.result {
            case .success(let items):
                onSuccess(items)
            case .failure(let error):
                onFailure(error)
            }
        }
        
        return request
    }
    
    @discardableResult internal static func execute<T: BaseMappable>(_ method: HTTPMethod, _ path: String, parameters: Parameters?=nil, keyPath: String?="data", onSuccess: @escaping (_ item: T)->(), onFailure: @escaping (_ error: Error)->()) -> DataRequest {
        debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path)) \(parameters ?? [:])")
        
        let request = sessionManager.request(getUrl(path), method: method, parameters: parameters, headers: getHeaders())
        request.validate(statusCode: 200...299).responseObject(keyPath: keyPath) { (response: DataResponse<T>) in
            switch response.result {
            case .success(let item):
                onSuccess(item)
            case .failure(let error):
                onFailure(error)
            }
        }
        
        return request
    }
    
    @discardableResult internal static func execute(_ method: HTTPMethod, _ path: String, parameters: Parameters?=nil, onSuccess: @escaping ()->(), onFailure: @escaping (_ error: Error)->()) -> DataRequest {
        debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path)) \(parameters ?? [:])")
        
        let request = sessionManager.request(getUrl(path), method: method, parameters: parameters, headers: getHeaders())
        request.validate(statusCode: 200...299).responseJSON { (response) in
            switch response.result {
            case .success:
                onSuccess()
            case .failure(let error):
                onFailure(error)
            }
        }
        
        return request
    }
    
    internal static func execute<T: BaseMappable>(_ method: HTTPMethod = HTTPMethod.post, path: String, multipartFormData: @escaping (MultipartFormData) -> Void, keyPath: String?="data", onSuccess: @escaping (_ item: T)->(), onFailure: @escaping (_ error: Error)->()) {
        debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path))")
        
        sessionManager.upload(multipartFormData: multipartFormData, to: getUrl(path), method: method, headers: getHeaders()) { encodingResult in
            switch encodingResult {
            case .success(let upload, _, _):
                upload.validate(statusCode: 200...299).responseObject(keyPath: keyPath) { (response: DataResponse<T>) in
                    switch response.result {
                    case .success(let item):
                        onSuccess(item)
                    case .failure(let error):
                        onFailure(error)
                    }
                }
            case .failure(let error):
                onFailure(error)
            }
        }
    }
    
    // MARK: Image
    internal static let imageCache: NSCache<NSString, UIImage> = {
        return NSCache()
    }()
    
    @discardableResult internal static func execute(_ method: HTTPMethod, _ path: String, parameters: Parameters?=nil, onSuccess: @escaping (_ image: UIImage)->(), onFailure: @escaping (_ error: Error)->()) -> DataRequest? {
        let url = getUrl(path)
        
        if let image = getImage(url) {
            onSuccess(image)
            
            return nil
        } else {
            debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path)) \(parameters ?? [:])")
            
            let request = sessionManager.request(url, method: method, parameters: parameters, headers: getHeaders())
            request.validate(statusCode: 200...299).responseImage { response in
                switch response.result {
                case .success(let image):
                    if let contentType: String = response.response?.allHeaderFields["Content-Type"] as? String, contentType.contains("image/gif"), let data = response.data, let image = UIImage.gif(data: data) {
                        setImage(url, image: image, data: data, isGif: true)
                        
                        onSuccess(image)
                    } else if let data = response.data {
                        setImage(url, image: image, data: data)
                        
                        onSuccess(image)
                    }
                case .failure(let error):
                    onFailure(error)
                }
            }
            
            return request
        }
    }
    
    private static func getImage(_ url: String) -> UIImage? {
        guard let key = url.data(using: .utf8)?.base64EncodedString() else { return nil }
        guard let gifKey = "\(url).gif".data(using: .utf8)?.base64EncodedString() else { return nil }
        
        if let image = imageCache.object(forKey: key as NSString) {
            return image
        } else if let image = imageCache.object(forKey: gifKey as NSString) {
            return image
        }
        
        if let data = Parley.shared.dataSource?.data(forKey: key), let image = UIImage(data: data) {
            return image
        } else if let data = Parley.shared.dataSource?.data(forKey: gifKey), let image = UIImage.gif(data: data) {
            return image
        }
        
        return nil
    }
    
    private static func setImage(_ url: String, image: UIImage, data: Data, isGif: Bool = false) {
        let suffix = isGif ? ".gif" : ""
        guard let key = "\(url)\(suffix)".data(using: .utf8)?.base64EncodedString() else { return }
        
        imageCache.setObject(image, forKey: key as NSString)
        
        Parley.shared.dataSource?.set(data, forKey: key)
    }
}
