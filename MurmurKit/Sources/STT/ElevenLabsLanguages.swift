import Foundation

/// An ElevenLabs-supported language with ISO 639-1 and ISO 639-3 codes.
public struct ElevenLabsLanguage: Sendable {
    public let id: String          // ISO 639-1 (e.g. "en")
    public let iso639_3: String    // ISO 639-3 (e.g. "eng")
    public let displayName: String
}

/// Full list of 98 languages supported by ElevenLabs Scribe STT.
public enum ElevenLabsLanguages {
    /// Look up ISO 639-3 code from an ISO 639-1 code.
    /// Returns nil for unknown codes. "auto" passes through as "auto".
    public static func iso639_3(for code: String) -> String? {
        if code == "auto" { return "auto" }
        return lookupTable[code]
    }

    /// All supported languages, sorted by display name.
    public static let all: [ElevenLabsLanguage] = [
        ElevenLabsLanguage(id: "auto", iso639_3: "auto", displayName: "Auto-detect"),
        ElevenLabsLanguage(id: "af", iso639_3: "afr", displayName: "Afrikaans"),
        ElevenLabsLanguage(id: "am", iso639_3: "amh", displayName: "Amharic"),
        ElevenLabsLanguage(id: "ar", iso639_3: "ara", displayName: "Arabic"),
        ElevenLabsLanguage(id: "as", iso639_3: "asm", displayName: "Assamese"),
        ElevenLabsLanguage(id: "az", iso639_3: "aze", displayName: "Azerbaijani"),
        ElevenLabsLanguage(id: "be", iso639_3: "bel", displayName: "Belarusian"),
        ElevenLabsLanguage(id: "bg", iso639_3: "bul", displayName: "Bulgarian"),
        ElevenLabsLanguage(id: "bn", iso639_3: "ben", displayName: "Bengali"),
        ElevenLabsLanguage(id: "bo", iso639_3: "bod", displayName: "Tibetan"),
        ElevenLabsLanguage(id: "br", iso639_3: "bre", displayName: "Breton"),
        ElevenLabsLanguage(id: "bs", iso639_3: "bos", displayName: "Bosnian"),
        ElevenLabsLanguage(id: "ca", iso639_3: "cat", displayName: "Catalan"),
        ElevenLabsLanguage(id: "cs", iso639_3: "ces", displayName: "Czech"),
        ElevenLabsLanguage(id: "cy", iso639_3: "cym", displayName: "Welsh"),
        ElevenLabsLanguage(id: "da", iso639_3: "dan", displayName: "Danish"),
        ElevenLabsLanguage(id: "de", iso639_3: "deu", displayName: "German"),
        ElevenLabsLanguage(id: "el", iso639_3: "ell", displayName: "Greek"),
        ElevenLabsLanguage(id: "en", iso639_3: "eng", displayName: "English"),
        ElevenLabsLanguage(id: "es", iso639_3: "spa", displayName: "Spanish"),
        ElevenLabsLanguage(id: "et", iso639_3: "est", displayName: "Estonian"),
        ElevenLabsLanguage(id: "eu", iso639_3: "eus", displayName: "Basque"),
        ElevenLabsLanguage(id: "fa", iso639_3: "fas", displayName: "Persian"),
        ElevenLabsLanguage(id: "fi", iso639_3: "fin", displayName: "Finnish"),
        ElevenLabsLanguage(id: "fo", iso639_3: "fao", displayName: "Faroese"),
        ElevenLabsLanguage(id: "fr", iso639_3: "fra", displayName: "French"),
        ElevenLabsLanguage(id: "ga", iso639_3: "gle", displayName: "Irish"),
        ElevenLabsLanguage(id: "gl", iso639_3: "glg", displayName: "Galician"),
        ElevenLabsLanguage(id: "gu", iso639_3: "guj", displayName: "Gujarati"),
        ElevenLabsLanguage(id: "ha", iso639_3: "hau", displayName: "Hausa"),
        ElevenLabsLanguage(id: "he", iso639_3: "heb", displayName: "Hebrew"),
        ElevenLabsLanguage(id: "hi", iso639_3: "hin", displayName: "Hindi"),
        ElevenLabsLanguage(id: "hr", iso639_3: "hrv", displayName: "Croatian"),
        ElevenLabsLanguage(id: "hu", iso639_3: "hun", displayName: "Hungarian"),
        ElevenLabsLanguage(id: "hy", iso639_3: "hye", displayName: "Armenian"),
        ElevenLabsLanguage(id: "id", iso639_3: "ind", displayName: "Indonesian"),
        ElevenLabsLanguage(id: "is", iso639_3: "isl", displayName: "Icelandic"),
        ElevenLabsLanguage(id: "it", iso639_3: "ita", displayName: "Italian"),
        ElevenLabsLanguage(id: "ja", iso639_3: "jpn", displayName: "Japanese"),
        ElevenLabsLanguage(id: "jv", iso639_3: "jav", displayName: "Javanese"),
        ElevenLabsLanguage(id: "ka", iso639_3: "kat", displayName: "Georgian"),
        ElevenLabsLanguage(id: "kk", iso639_3: "kaz", displayName: "Kazakh"),
        ElevenLabsLanguage(id: "km", iso639_3: "khm", displayName: "Khmer"),
        ElevenLabsLanguage(id: "kn", iso639_3: "kan", displayName: "Kannada"),
        ElevenLabsLanguage(id: "ko", iso639_3: "kor", displayName: "Korean"),
        ElevenLabsLanguage(id: "lo", iso639_3: "lao", displayName: "Lao"),
        ElevenLabsLanguage(id: "lt", iso639_3: "lit", displayName: "Lithuanian"),
        ElevenLabsLanguage(id: "lv", iso639_3: "lav", displayName: "Latvian"),
        ElevenLabsLanguage(id: "mg", iso639_3: "mlg", displayName: "Malagasy"),
        ElevenLabsLanguage(id: "mk", iso639_3: "mkd", displayName: "Macedonian"),
        ElevenLabsLanguage(id: "ml", iso639_3: "mal", displayName: "Malayalam"),
        ElevenLabsLanguage(id: "mn", iso639_3: "mon", displayName: "Mongolian"),
        ElevenLabsLanguage(id: "mr", iso639_3: "mar", displayName: "Marathi"),
        ElevenLabsLanguage(id: "ms", iso639_3: "msa", displayName: "Malay"),
        ElevenLabsLanguage(id: "mt", iso639_3: "mlt", displayName: "Maltese"),
        ElevenLabsLanguage(id: "my", iso639_3: "mya", displayName: "Burmese"),
        ElevenLabsLanguage(id: "ne", iso639_3: "nep", displayName: "Nepali"),
        ElevenLabsLanguage(id: "nl", iso639_3: "nld", displayName: "Dutch"),
        ElevenLabsLanguage(id: "no", iso639_3: "nor", displayName: "Norwegian"),
        ElevenLabsLanguage(id: "oc", iso639_3: "oci", displayName: "Occitan"),
        ElevenLabsLanguage(id: "or", iso639_3: "ori", displayName: "Odia"),
        ElevenLabsLanguage(id: "pa", iso639_3: "pan", displayName: "Punjabi"),
        ElevenLabsLanguage(id: "pl", iso639_3: "pol", displayName: "Polish"),
        ElevenLabsLanguage(id: "ps", iso639_3: "pus", displayName: "Pashto"),
        ElevenLabsLanguage(id: "pt", iso639_3: "por", displayName: "Portuguese"),
        ElevenLabsLanguage(id: "ro", iso639_3: "ron", displayName: "Romanian"),
        ElevenLabsLanguage(id: "ru", iso639_3: "rus", displayName: "Russian"),
        ElevenLabsLanguage(id: "sa", iso639_3: "san", displayName: "Sanskrit"),
        ElevenLabsLanguage(id: "sd", iso639_3: "snd", displayName: "Sindhi"),
        ElevenLabsLanguage(id: "si", iso639_3: "sin", displayName: "Sinhala"),
        ElevenLabsLanguage(id: "sk", iso639_3: "slk", displayName: "Slovak"),
        ElevenLabsLanguage(id: "sl", iso639_3: "slv", displayName: "Slovenian"),
        ElevenLabsLanguage(id: "sn", iso639_3: "sna", displayName: "Shona"),
        ElevenLabsLanguage(id: "so", iso639_3: "som", displayName: "Somali"),
        ElevenLabsLanguage(id: "sq", iso639_3: "sqi", displayName: "Albanian"),
        ElevenLabsLanguage(id: "sr", iso639_3: "srp", displayName: "Serbian"),
        ElevenLabsLanguage(id: "su", iso639_3: "sun", displayName: "Sundanese"),
        ElevenLabsLanguage(id: "sv", iso639_3: "swe", displayName: "Swedish"),
        ElevenLabsLanguage(id: "sw", iso639_3: "swa", displayName: "Swahili"),
        ElevenLabsLanguage(id: "ta", iso639_3: "tam", displayName: "Tamil"),
        ElevenLabsLanguage(id: "te", iso639_3: "tel", displayName: "Telugu"),
        ElevenLabsLanguage(id: "tg", iso639_3: "tgk", displayName: "Tajik"),
        ElevenLabsLanguage(id: "th", iso639_3: "tha", displayName: "Thai"),
        ElevenLabsLanguage(id: "tk", iso639_3: "tuk", displayName: "Turkmen"),
        ElevenLabsLanguage(id: "tl", iso639_3: "tgl", displayName: "Tagalog"),
        ElevenLabsLanguage(id: "tr", iso639_3: "tur", displayName: "Turkish"),
        ElevenLabsLanguage(id: "tt", iso639_3: "tat", displayName: "Tatar"),
        ElevenLabsLanguage(id: "uk", iso639_3: "ukr", displayName: "Ukrainian"),
        ElevenLabsLanguage(id: "ur", iso639_3: "urd", displayName: "Urdu"),
        ElevenLabsLanguage(id: "uz", iso639_3: "uzb", displayName: "Uzbek"),
        ElevenLabsLanguage(id: "vi", iso639_3: "vie", displayName: "Vietnamese"),
        ElevenLabsLanguage(id: "yi", iso639_3: "yid", displayName: "Yiddish"),
        ElevenLabsLanguage(id: "yo", iso639_3: "yor", displayName: "Yoruba"),
        ElevenLabsLanguage(id: "zh", iso639_3: "cmn", displayName: "Chinese (Mandarin)"),
        ElevenLabsLanguage(id: "zu", iso639_3: "zul", displayName: "Zulu"),
    ]

    /// Fast lookup table from ISO 639-1 → ISO 639-3.
    private static let lookupTable: [String: String] = {
        var table: [String: String] = [:]
        for lang in all {
            table[lang.id] = lang.iso639_3
        }
        return table
    }()
}
