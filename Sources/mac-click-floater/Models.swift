import Foundation
import CoreGraphics

struct ClickPoint: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var x: Double
    var y: Double
    var interval: Double
    var isEnabled: Bool
    var durationHours: Int
    var durationMinutes: Int
    var durationSeconds: Int

    init(
        id: UUID = UUID(),
        name: String,
        x: Double,
        y: Double,
        interval: Double,
        isEnabled: Bool,
        durationHours: Int = 0,
        durationMinutes: Int = 0,
        durationSeconds: Int = 0
    ) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.interval = interval
        self.isEnabled = isEnabled
        self.durationHours = durationHours
        self.durationMinutes = durationMinutes
        self.durationSeconds = durationSeconds
    }

    enum CodingKeys: String, CodingKey {
        case id, name, x, y, interval, isEnabled, durationHours, durationMinutes, durationSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        interval = try container.decode(Double.self, forKey: .interval)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        durationHours = try container.decodeIfPresent(Int.self, forKey: .durationHours) ?? 0
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 0
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(interval, forKey: .interval)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(durationHours, forKey: .durationHours)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(durationSeconds, forKey: .durationSeconds)
    }

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }

    var displayPosition: String {
        "x: \(Int(x)), y: \(Int(y))"
    }

    var durationTimeInterval: TimeInterval {
        TimeInterval((durationHours * 3600) + (durationMinutes * 60) + durationSeconds)
    }

    var durationDescription: String {
        if durationTimeInterval <= 0 {
            return "一直运行"
        }
        return "\(durationHours)h \(durationMinutes)m \(durationSeconds)s"
    }
}
