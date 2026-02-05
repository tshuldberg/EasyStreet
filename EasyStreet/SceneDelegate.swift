import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Create the main view controller
        let mapViewController = MapViewController()
        let navigationController = UINavigationController(rootViewController: mapViewController)
        
        // Create window and set it as the root
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called when a scene is being released by the system
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when a scene becomes active (foreground)
        
        // Refresh map display when returning to the app
        if let mapVC = window?.rootViewController as? UINavigationController,
           let mainVC = mapVC.viewControllers.first as? MapViewController {
            mainVC.viewWillAppear(true) // Force refresh
        }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when a scene is about to move to background
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called when a scene is moving from background to foreground
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called when a scene enters the background
    }
} 