import UIKit
import Flutter
import Firebase
import UserNotifications
import GoogleSignIn


@main
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Firebase init
    FirebaseApp.configure()

    // Notification Delegate
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    // FCM token delegate
    Messaging.messaging().delegate = self

    // Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ----------------------------------------------------
  // MARK: - 🔗 Deep Link Handler (doxyapp://auth?token=)
  // ----------------------------------------------------
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {

     return GIDSignIn.sharedInstance.handle(url)
  }

  // ----------------------------------------------------
  // MARK: - 🔥 FCM Token Received
  // ----------------------------------------------------
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("📡 iOS FCM Token: \(String(describing: fcmToken))")

    // Send to Flutter via NotificationCenter
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: ["token": fcmToken ?? ""]
    )
  }

  // ----------------------------------------------------
  // MARK: - 🔔 Foreground Notifications
  // ----------------------------------------------------
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show banner + sound in foreground
    completionHandler([.banner, .sound, .badge])
  }

  // ----------------------------------------------------
  // MARK: - 🔔 Notification Tap Handling
  // ----------------------------------------------------
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("📲 Notification tapped: \(response.notification.request.content.userInfo)")

    completionHandler()
  }

  // ----------------------------------------------------
  // MARK: - APNS TOKEN
  // ----------------------------------------------------
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("📬 APNS device token received")

    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
