import UIKit
import SwiftUI
import UserNotifications
import UserNotificationsUI

/// Bildirim aşağı çekilip açıldığında gösterilen kompakt kart.
/// Bu uzantı olmadan iOS, ekteki ikon görselini ekran genişliğinde (dev bir daire olarak) gösterir.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var host: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let card: AnyView
        if let data = NotificationCardData(userInfo: content.userInfo, title: content.title, body: content.body) {
            card = AnyView(NotificationCardView(data: data))
        } else {
            card = AnyView(
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title).font(.headline)
                    Text(content.body).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            )
        }

        let hosting: UIHostingController<AnyView>
        if let host {
            hosting = host
            hosting.rootView = card
        } else {
            hosting = UIHostingController(rootView: card)
            hosting.view.backgroundColor = .clear
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            addChild(hosting)
            view.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            hosting.didMove(toParent: self)
            host = hosting
        }

        let width = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let fitted = hosting.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        preferredContentSize = CGSize(width: width, height: ceil(fitted.height))
    }
}
