import Foundation

/// Light, rule-based cleanup of raw Whisper output so pasted text reads
/// like something you typed, not a court transcript.
enum TranscriptCleaner {
    static func clean(_ raw: String, removeFillers: Bool) -> String {
        var text = raw

        // Whisper emits annotations like [BLANK_AUDIO], [Music], <|endoftext|>
        // and noise notes like (laughs) — none of which belong in dictation.
        text = text.replacingOccurrences(
            of: #"<\|[^|]*\|>|\[[^\]]*\]|\((?:silence|music|laughs|laughter|coughs|applause|inaudible)\)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        if removeFillers {
            // Standalone hesitation sounds, plus any trailing comma/period.
            text = text.replacingOccurrences(
                of: #"(?i)(?<![\w'])(?:um+|uh+|uhm+|erm+|mm-hmm|hmm+)(?![\w'])[,.]?"#,
                with: "",
                options: .regularExpression
            )
        }

        // Tidy the seams left by removals.
        text = text.replacingOccurrences(of: #"\s+([,.!?;:])"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize the first letter if Whisper didn't.
        if let first = text.first, first.isLowercase {
            text = first.uppercased() + text.dropFirst()
        }

        return text
    }
}
