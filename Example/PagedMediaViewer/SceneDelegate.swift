//
//  SceneDelegate.swift
//  PagedMediaViewer_Example
//
//  Created by Gorjan Shukov on 16.9.25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        let rootVC = PagedMediaViewControllerExample()
        let navController = UINavigationController(rootViewController: rootVC)
        window.rootViewController = navController
        window.makeKeyAndVisible()

        self.window = window
    }
}
