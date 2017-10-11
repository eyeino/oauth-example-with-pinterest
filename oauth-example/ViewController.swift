//
//  ViewController.swift
//  oauth-example
//
//  Created by Ian MacFarlane on 9/22/17.
//  Copyright © 2017 Ian MacFarlane. All rights reserved.
//

import UIKit
import OAuthSwift
import Alamofire
import SwiftyJSON
import Locksmith

class ViewController: UIViewController {
    
    var oauthswift: OAuth2Swift?
    open var returnedURLWithParameters: URL? {
        didSet {
            guard let parameters = returnedURLWithParameters else {
                return
            }
            oauth2Token = parseToken(from: parameters)
        }
    }
    
    fileprivate func parseToken(from url: URL) -> String? {
        return getQueryStringParameter(url: url.absoluteString, param: "code")
    }
    
    func getQueryStringParameter(url: String, param: String) -> String? {
        guard let url = URLComponents(string: url) else { return nil }
        return url.queryItems?.first(where: { $0.name == param })?.value
    }
    
    open var oauth2Token: String? {
        didSet {
            tokenLabel.text = self.oauth2Token!
        }
    }
    
    let tokenLabel: UILabel = {
       let label = UILabel()
        label.text = "Token"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let pinterestAccessTokenLabel: UILabel = {
        let label = UILabel()
        label.text = "Access token"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var pinterestButton: UIButton = {
       let button = UIButton()
        button.setTitle("Log in with Pinterest", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.red
        button.addTarget(self, action: #selector(handlePinterestAuthentication), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    lazy var pinterestTokenButton: UIButton = {
        let button = UIButton()
        button.setTitle("Get permanent token...", for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.addTarget(self, action: #selector(handlePinterestToken), for: .touchUpInside)
        button.layer.cornerRadius = 5
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    lazy var pinterestBoardButton: UIButton = {
        let button = UIButton()
        button.setTitle("Get pinterest board JSON", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.black
        button.addTarget(self, action: #selector(getMyPinterestBoards), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    lazy var pinterestPinButton: UIButton = {
        let button = UIButton()
        button.setTitle("Get pinterest pins", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.green
        button.addTarget(self, action: #selector(getPinterestImageData), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    @objc fileprivate func handlePinterestAuthentication() {
        oauthswift = OAuth2Swift(
            consumerKey: DeveloperParameters.consumerKey,
            consumerSecret: DeveloperParameters.consumerSecret,
            authorizeUrl: "https://api.pinterest.com/oauth/",
            responseType: "code"
        )
        
        _ = oauthswift!.authorize(
            withCallbackURL: URL(string: DeveloperParameters.callbackURL)!,
            scope: "read_public", state: "oauth-example-state",
            success: { credential, response, parameters in
                print("Auth code is \(credential.oauthToken)")
                self.oauth2Token = credential.oauthToken
        },
            failure: { error in
                print(error.localizedDescription)
        })
    }
    
    @objc fileprivate func handlePinterestToken() {
        guard let code = oauth2Token else {
            print("No access code yet. Please request code from Pinterest first, before attempting to request token.")
            return
        }
        
        getPinterestAccessToken(accessCode: code)
    }
    
    fileprivate func getPinterestAccessToken(accessCode: String) {
        
        var parameters = Alamofire.Parameters()
        parameters["grant_type"] = "authorization_code"
        parameters["client_id"] = DeveloperParameters.consumerKey
        parameters["client_secret"] = DeveloperParameters.consumerSecret
        parameters["code"] = accessCode
        
        Alamofire.request(DeveloperParameters.pinterestAccessTokenURL, method: .post, parameters: parameters, encoding: URLEncoding.default).responseJSON { response in
            switch response.result {
            case .success:
                guard let data = response.data else { return }
                let json = JSON(data)
                guard let token = json["access_token"].string else { return }
                
                DispatchQueue.main.async {
                    self.pinterestAccessTokenLabel.text = token
                    
                    do {
                        // updateData creates a key-value pair if it does not exist
                        try Locksmith.updateData(data: ["pinterest_access_token": token], forUserAccount: "myUserAccount")
                    } catch {
                        print("Locksmith could not save the Pinterest access token.")
                    }
                    
                    guard let dict = Locksmith.loadDataForUserAccount(userAccount: "myUserAccount") else { return }
                    guard let pinterestAccessToken = dict["pinterest_access_token"] else { return }
                    print("This is the token saved in the Keychain: \(pinterestAccessToken as? String)")
                }
            case .failure:
                print(response.error?.localizedDescription ?? "Unspecified error with response for access token request.")
            }
        }
    }
    
    @objc fileprivate func getMyPinterestBoards() {
        
        var parameters = Alamofire.Parameters()
        guard let dict = Locksmith.loadDataForUserAccount(userAccount: "myUserAccount") else { return }
        guard let accessToken = dict["pinterest_access_token"] else { return }
        parameters["access_token"] = accessToken
        
        Alamofire.request(DeveloperParameters.pinterestFetchMyBoards, method: .get, parameters: parameters, encoding: URLEncoding.default).responseJSON { response in
            switch response.result {
            case .success:
                guard let data = response.data else { return }
                let json = JSON(data)
                print(json)
                guard let pinId = json["data"][0]["id"].string else {
                    return
                }
                
                self.getPinterestImageData(for: pinId)
            
            case .failure:
                print(response.error?.localizedDescription ?? "error in get board")
            }
        }
    }
    
    @objc fileprivate func getPins(boardName: String, userName: String) {
        
        var parameters = Alamofire.Parameters()
        guard let dict = Locksmith.loadDataForUserAccount(userAccount: "myUserAccount") else { return }
        guard let accessToken = dict["pinterest_access_token"] else { return }
        parameters["access_token"] = accessToken

        let urlString = "https://api.pinterest.com/v1/boards/\(userName + "/" + boardName)/pins/"
        
        Alamofire.request(urlString, method: .get, parameters: parameters, encoding: URLEncoding.default).responseJSON { response in
            switch response.result {
            case .success:
                guard let data = response.data else { return }
                let json = JSON(data)
                print("JSON data: \(json)")
            case .failure:
                print(response.error?.localizedDescription ?? "error in get board")
            }
        }
    }
    
    @objc fileprivate func getPinterestImageData(for pinId: String) {
        
        var parameters = Alamofire.Parameters()
        guard let dict = Locksmith.loadDataForUserAccount(userAccount: "myUserAccount") else { return }
        guard let accessToken = dict["pinterest_access_token"] else { return }
        parameters["access_token"] = accessToken
        parameters["fields"] = "image"
        
        let urlString = "https://api.pinterest.com/v1/pins/\(pinId)"
        
        Alamofire.request(urlString, method: .get, parameters: parameters, encoding: URLEncoding.default).responseJSON { response in
            switch response.result {
            case .success:
                guard let data = response.data else { return }
                let json = JSON(data)
                guard let imageURL = json["data"]["image"]["original"]["url"].string else { return }
                print(imageURL)
            case .failure:
                print(response.error?.localizedDescription ?? "error in image getter" )
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(pinterestButton)
        view.addSubview(tokenLabel)
        view.addSubview(pinterestTokenButton)
        view.addSubview(pinterestAccessTokenLabel)
        view.addSubview(pinterestBoardButton)
        
        pinterestButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        pinterestButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        tokenLabel.topAnchor.constraint(equalTo: pinterestButton.bottomAnchor).isActive = true
        tokenLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        pinterestTokenButton.topAnchor.constraint(equalTo: tokenLabel.bottomAnchor).isActive = true
        pinterestTokenButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        pinterestAccessTokenLabel.topAnchor.constraint(equalTo: pinterestTokenButton.bottomAnchor).isActive = true
        pinterestAccessTokenLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        pinterestBoardButton.topAnchor.constraint(equalTo: pinterestAccessTokenLabel.bottomAnchor).isActive = true
        pinterestBoardButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Do any additional setup after loading the view, typically from a nib.
//        if let token = oauth2Token {
//            tokenLabel.text = token
//        }
    }
}

extension UIView {
    
    func anchor(top: NSLayoutYAxisAnchor?, left: NSLayoutXAxisAnchor?, bottom: NSLayoutYAxisAnchor?, right: NSLayoutXAxisAnchor?, paddingTop: CGFloat, paddingLeft: CGFloat, paddingBottom: CGFloat, paddingRight: CGFloat, width: CGFloat, height: CGFloat) {
        
        translatesAutoresizingMaskIntoConstraints = false
        
        if let top = top {
            self.topAnchor.constraint(equalTo: top, constant: paddingTop).isActive = true
        }
        
        if let left = left {
            self.leftAnchor.constraint(equalTo: left, constant: paddingLeft).isActive = true
        }
        
        if let bottom = bottom {
            self.bottomAnchor.constraint(equalTo: bottom, constant: -paddingBottom).isActive = true
        }
        
        if let right = right {
            self.rightAnchor.constraint(equalTo: right, constant: -paddingRight).isActive = true
        }
        
        if width != 0 {
            self.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        
        if height != 0 {
            self.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
    }
}
