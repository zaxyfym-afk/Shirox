import XCTest
@testable import Shirox

/// The bundled avatar catalog: its pairing with the palette, and that a registry saved
/// before avatars still decodes.
final class ProfileAvatarTests: XCTestCase {
    func testEveryPaletteColourPairsWithAnAvatar() {
        XCTAssertEqual(ProfileAvatarCatalog.all.count, ProfilePalette.colors.count,
                       "The catalog and the palette pair one to one")
        for hex in ProfilePalette.colors {
            XCTAssertNotNil(ProfileAvatarCatalog.default(colorHex: hex), "No avatar paired with \(hex)")
        }
    }

    func testEachAvatarPairsWithExactlyOneColour() {
        let defaults = ProfilePalette.colors.compactMap { ProfileAvatarCatalog.default(colorHex: $0) }
        XCTAssertEqual(Set(defaults).count, ProfileAvatarCatalog.all.count,
                       "Two colours picked the same avatar")
    }

    func testAColourOutsideThePaletteHasNoDefault() {
        XCTAssertNil(ProfileAvatarCatalog.default(colorHex: "#123456"))
    }

    /// Registries saved before the avatar field decode with it nil: an update must not
    /// cost anyone their profiles.
    func testARegistryFromBeforeAvatarsDecodes() throws {
        let json = """
        {"profiles": [{
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "Alice",
            "colorHex": "#E5484D",
            "hasPhoto": false,
            "artworkURL": null, "artworkTitle": null,
            "accountAvatarURL": null,
            "moduleGroup": "22222222-2222-2222-2222-222222222222",
            "createdAt": 0
        }], "activeID": "11111111-1111-1111-1111-111111111111"}
        """.data(using: .utf8)!
        let registry = try JSONDecoder().decode(ProfileRegistry.self, from: json)
        XCTAssertEqual(registry.profiles.count, 1)
        XCTAssertNil(registry.profiles[0].avatarID)
    }

    func testAnAvatarSavedDecodesBack() throws {
        var profile = AppProfile(id: UUID(), name: "B", colorHex: "#F76B15", moduleGroup: UUID())
        profile.avatarID = "AvatarTiger"
        let roundtrip = try JSONDecoder().decode(AppProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(roundtrip.avatarID, "AvatarTiger")
    }
}
