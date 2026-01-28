import Foundation

enum SidebarSelection: Hashable {
    case favorites
    case book(Book)
    case tag(Tag)
}
