//
//  PronunciationPlayer.swift
//  faff
//
//  Plays a word's pronunciation. The dictionary's recorded audio is preferred,
//  but its media host is unreliable (it can return error pages instead of MP3s,
//  which AVPlayer swallows silently). So the clip is downloaded and validated
//  first, and on any failure the word is spoken with on-device speech instead.
//

import AVFoundation

@MainActor
final class PronunciationPlayer {
    private var audioPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var currentTask: Task<Void, Never>?

    func play(word: String, audioURL: String?) {
        currentTask?.cancel()
        audioPlayer?.stop()
        synthesizer.stopSpeaking(at: .immediate)
        activateSession()

        currentTask = Task {
            if let url = Self.normalizedURL(audioURL),
               let data = await Self.fetchAudio(url),
               !Task.isCancelled,
               let player = try? AVAudioPlayer(data: data),
               player.play() {
                audioPlayer = player
                return
            }
            guard !Task.isCancelled else { return }
            speak(word)
        }
    }

    private func speak(_ word: String) {
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    /// The default session (.soloAmbient) is muted by the silent switch, so a
    /// user-initiated pronunciation would play silently.
    private func activateSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    /// Some entries return protocol-relative ("//...") or plain http links;
    /// the former can't load and ATS blocks the latter.
    private static func normalizedURL(_ raw: String?) -> URL? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return nil
        }
        if s.hasPrefix("//") {
            s = "https:" + s
        } else if s.hasPrefix("http://") {
            s = "https://" + s.dropFirst("http://".count)
        }
        return URL(string: s)
    }

    /// Returns the clip only if the server actually answered with audio.
    private static func fetchAudio(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !data.isEmpty else {
            return nil
        }
        if let type = http.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
           type.hasPrefix("text/") || type.contains("html") || type.contains("json") {
            return nil
        }
        return data
    }
}
