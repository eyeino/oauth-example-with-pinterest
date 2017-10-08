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
        button.setTitle("Start Pinterest OAuth", for: .normal)
        button.setTitleColor(.blue, for: .normal)
        button.addTarget(self, action: #selector(handlePinterestAuthentication), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    lazy var pinterestTokenButton: UIButton = {
        let button = UIButton()
        button.setTitle("Get permanent token...", for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.addTarget(self, action: #selector(handlePinterestToken), for: .touchUpInside)
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
        guard let code = oauth2Token else { return }
        getPinterestAccessToken(accessCode: code, completion: { token in
            if let token = token {
                DispatchQueue.main.async {
                    print(token)
                    self.pinterestAccessTokenLabel.text = token
                }
            } else {
                DispatchQueue.main.async {
                    self.pinterestAccessTokenLabel.text = "Error"
                }
            }
        })
    }
    
    fileprivate func getPinterestAccessToken(accessCode: String, completion: @escaping (String?) -> Void) {
        
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
                let token = json["access_token"].string
                
                DispatchQueue.main.async {
                    self.pinterestAccessTokenLabel.text = token
                }
            case .failure:
                print(response.error?.localizedDescription ?? "Unspecified error with response for access token request.")
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
        
        pinterestButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        pinterestButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        tokenLabel.topAnchor.constraint(equalTo: pinterestButton.bottomAnchor).isActive = true
        tokenLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        pinterestTokenButton.topAnchor.constraint(equalTo: tokenLabel.bottomAnchor).isActive = true
        pinterestTokenButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        pinterestAccessTokenLabel.topAnchor.constraint(equalTo: pinterestTokenButton.bottomAnchor).isActive = true
        pinterestAccessTokenLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
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
