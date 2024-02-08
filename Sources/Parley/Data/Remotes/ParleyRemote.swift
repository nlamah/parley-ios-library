import Alamofire
import AlamofireImage
import UIKit
import Foundation

internal class ParleyRemote {
    
    internal static var sessionManager: Alamofire.Session!
    
    private static let encoding = URLEncoding(boolEncoding: URLEncoding.BoolEncoding.literal)
    
    internal static func refresh(_ network: ParleyNetwork) {
        guard let domain = URL(string: network.url)?.host else {
            fatalError("ParleyRemote: Invalid url")
        }
        
        let evaluators: [String: ServerTrustEvaluating] = [
            domain: PublicKeysTrustEvaluator()
        ]
        
        sessionManager = Session(
            configuration: URLSessionConfiguration.af.default,
            serverTrustManager: ServerTrustManager(evaluators: evaluators)
        )
    }
    
    private static func getHeaders() -> HTTPHeaders {
        var headers = Parley.shared.network.headers
        guard let secret = Parley.shared.secret else {
            fatalError("ParleyRemote: Secret is not set")
        }
        headers["x-iris-identification"] = "\(secret):\(getDeviceId())"
        
        if let userAuthorization = Parley.shared.userAuthorization {
            headers["Authorization"] = userAuthorization
        }
        
        return HTTPHeaders(headers)
    }
    
    private static func getDeviceId() -> String {
        if let configuredDeviceId = Parley.shared.uniqueDeviceIdentifier {
            return configuredDeviceId
        }
        
        if let uuid = UserDefaults.standard.string(forKey: kParleyUserDefaultDeviceUUID) {
            return uuid
        } else {
            let uuid = UUID().uuidString
            UserDefaults.standard.set(uuid, forKey: kParleyUserDefaultDeviceUUID)
            return uuid
        }
    }
    
    private static func getUrl(_ path: String) -> URL {
        Parley.shared.network.absoluteURL.appendingPathComponent(path)
    }
    
    // MARK: Execute request
    @discardableResult internal static func execute<T: Codable>(_ method: HTTPMethod, _ path: String, parameters: Parameters? = nil, keyPath: DataRequest.KeyPath = .data, onSuccess: @escaping (_ items: [T])->(), onFailure: @escaping (_ error: Error)->()) -> DataRequest {
        debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path)) \(parameters ?? [:])")
        
        let request = sessionManager.request(getUrl(path), method: method, parameters: parameters, encoding: Self.encoding, headers: getHeaders())
        request.validate(statusCode: 200...299)
            .responseDecodableAtKeyPath(of: [T].self, keyPath: keyPath, onSuccess: onSuccess, onFailure: onFailure)
        
        return request
    }
    
    @discardableResult internal static func execute<T: Codable>(_ method: HTTPMethod, _ path: String, parameters: Parameters? = nil, keyPath: DataRequest.KeyPath = .data, onSuccess: @escaping (_ item: T) -> (), onFailure: @escaping (_ error: Error) -> ()) -> DataRequest {
        debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path)) \(parameters ?? [:])")

        let request = sessionManager.request(getUrl(path), method: method, parameters: parameters, encoding: Self.encoding, headers: getHeaders())
        request
            .validate(statusCode: 200...299)
            .responseDecodableAtKeyPath(of: T.self, keyPath: keyPath, onSuccess: onSuccess, onFailure: onFailure)
        
        return request
    }
    
    @discardableResult internal static func execute(_ method: HTTPMethod, _ path: String, parameters: Parameters? = nil, onSuccess: @escaping ()->(), onFailure: @escaping (_ error: Error)->()) -> DataRequest {
        debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path)) \(parameters ?? [:])")
        
        let request = sessionManager.request(getUrl(path), method: method, parameters: parameters, encoding: Self.encoding, headers: getHeaders())
        request.validate(statusCode: 200...299).responseJSON { (response) in
            switch response.result {
            case .success:
                onSuccess()
            case .failure(let error):
                if let data = response.data, let apiError = decodeBackendError(responseData: data) {
                    onFailure(apiError)
                } else {
                    onFailure(error)
                }
            }
        }
        
        return request
    }
    
    internal static func execute<T: Codable>(_ method: HTTPMethod = HTTPMethod.post, path: String, multipartFormData: @escaping (MultipartFormData) -> Void, keyPath: DataRequest.KeyPath = .data, onSuccess: @escaping (_ item: T) -> (), onFailure: @escaping (_ error: Error)->()) {
        debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path))")
        
        sessionManager.upload(multipartFormData: multipartFormData, to: getUrl(path), method: method, headers: getHeaders())
            .validate(statusCode: 200...299)
            .responseDecodableAtKeyPath(of: T.self, keyPath: keyPath, onSuccess: onSuccess, onFailure: onFailure)
    }
    
    // MARK: Image
    internal static let imageCache = NSCache<NSString, UIImage>()
    
    @discardableResult internal static func execute(_ method: HTTPMethod, _ path: String, parameters: Parameters?=nil, onSuccess: @escaping (_ image: UIImage)->(), onFailure: @escaping (_ error: Error)->()) -> DataRequest? {
        let url = getUrl(path)
        
        if let image = getImage(url.absoluteString) {
            onSuccess(image)
            
            return nil
        } else {
            debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path)) \(parameters ?? [:])")
            
            let request = sessionManager.request(url, method: method, parameters: parameters, encoding: Self.encoding, headers: getHeaders())
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
                    if let data = request.data, let apiError = decodeBackendError(responseData: data) {
                        onFailure(apiError)
                    } else {
                        onFailure(error)
                    }
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
    
    private static func setImage(_ url: URL, image: UIImage, data: Data, isGif: Bool = false) {
        let suffix = isGif ? ".gif" : ""
        guard let key = "\(url.absoluteString)\(suffix)".data(using: .utf8)?.base64EncodedString() else { return }
        
        imageCache.setObject(image, forKey: key as NSString)
        
        Parley.shared.dataSource?.set(data, forKey: key)
    }
}

// MARK: - Codable implementation

internal extension ParleyRemote {
    
    static func execute<T: Codable>(_ method: HTTPMethod = HTTPMethod.post, path: String, multipartFormData: MultipartFormData, result: @escaping ((Result<T, Error>) -> ())) {
        debugPrint("ParleyRemote.execute:: \(method) \(getUrl(path))")
        sessionManager.upload(multipartFormData: multipartFormData, to: getUrl(path), method: method, headers: getHeaders())
            .validate(statusCode: 200...299)
            .responseData(completionHandler: { response in
                decodeData(response: response, result: result)
            })
    }
    
    private static func decodeData<T: Codable>(response: AFDataResponse<Data>, result: @escaping ((Result<T, Error>) -> ())) {
        switch response.result {
        case .success(let data):
            do {
                let decodedData = try JSONDecoder().decode(ParleyResponse<T>.self, from: data)
                result(.success(decodedData.data))
            } catch let responseError {
                
                result(.failure(responseError))
            }
        case .failure(let defaultError):
            guard
                let data = response.data,
                let apiResponseError = decodeBackendError(responseData: data)
            else { result(.failure(defaultError)) ; return }
            
            result(.failure(apiResponseError))
        }
    }
    
    internal static func decodeBackendError(responseData: Data) -> ParleyErrorResponse? {
        try? JSONDecoder().decode(ParleyErrorResponse.self, from: responseData)
    }
}
