import AppKit

/// Synthesized gong strikes: a small one when a break starts, a large one
/// when it ends. Built in code so the app needs no bundled audio resources.
@MainActor
enum Gong {
    enum Size { case small, large }

    private static let small = NSSound(data: wav(samples: synthesize(fundamental: 196, duration: 2.5, level: 0.5)))
    private static let large = NSSound(data: wav(samples: synthesize(fundamental: 98, duration: 5, level: 0.8)))

    static func play(_ size: Size) {
        let sound = size == .small ? small : large
        sound?.stop()
        sound?.play()
    }

    private static let sampleRate = 44_100.0

    /// Inharmonic partials with independent decays, plus a short mallet thump.
    private static func synthesize(fundamental: Double, duration: Double, level: Float) -> [Float] {
        // Smaller gongs ring for less time.
        let decayScale = duration / 5
        // (frequency ratio, amplitude, decay seconds)
        let partials: [(Double, Double, Double)] = [
            (1.00, 1.00, 4.5), (1.006, 0.6, 4.5), // detuned pair for a slow shimmer
            (1.52, 0.55, 3.2), (2.00, 0.45, 2.6), (2.66, 0.40, 2.0),
            (3.17, 0.30, 1.6), (4.10, 0.22, 1.1), (5.43, 0.15, 0.7), (7.30, 0.10, 0.4),
        ]
        let count = Int(duration * sampleRate)
        var out = [Float](repeating: 0, count: count)
        var noise: UInt32 = 0x9E37_79B9
        for i in 0..<count {
            let t = Double(i) / sampleRate
            // Higher partials bloom in slightly after the strike, as a real gong does.
            let attack = min(1, t / 0.008)
            var v = 0.0
            for (ratio, amp, decay) in partials {
                let bloom = ratio > 2 ? min(1, 0.4 + t / 0.15) : 1
                v += amp * bloom * exp(-t / (decay * decayScale)) * sin(2 * .pi * fundamental * ratio * t)
            }
            noise = noise &* 1_664_525 &+ 1_013_904_223
            let thump = (Double(noise) / Double(UInt32.max) * 2 - 1) * exp(-t / 0.015) * 0.5
            let fadeOut = min(1, (duration - t) / 0.3)
            out[i] = Float((v * attack + thump) * fadeOut)
        }
        let peak = out.map(abs).max() ?? 1
        return out.map { $0 / peak * level }
    }

    /// 16-bit mono PCM WAV.
    private static func wav(samples: [Float]) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(36 + bytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16))
        append(UInt16(1)); append(UInt16(1)); append(UInt32(sampleRate)); append(UInt32(sampleRate) * 2)
        append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(bytes)
        for s in samples { append(Int16(max(-1, min(1, s)) * Float(Int16.max))) }
        return data
    }
}
