//
//  AppDelegate.swift
//  NavCam2.0
//
//  Created by Shayaan Tanveer on 4/26/25.
//

import UIKit
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate {


  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // configure your OAuth client
    let config = GIDConfiguration(
      clientID: "867979137270-fjmmntfpv3kmdnlqmr5l546q22b3mcf1.apps.googleusercontent.com"
    )
    GIDSignIn.sharedInstance.configuration = config

    // attempt silent restore of any previous sign-in
    GIDSignIn.sharedInstance.restorePreviousSignIn()

    return true
  }

  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    // hand the URL back to GoogleSignIn
    return GIDSignIn.sharedInstance.handle(url)
  }
}
