import UIKit

final class KeyboardViewController: UIInputViewController {
    private let previewLabel = UILabel()
    private let insertButton = UIButton(type: .system)
    private let updatedLabel = UILabel()

    private var latestText: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        refreshLatestText()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshLatestText()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "Murmur"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true

        previewLabel.font = .preferredFont(forTextStyle: .body)
        previewLabel.adjustsFontForContentSizeCategory = true
        previewLabel.numberOfLines = 4
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.textColor = .label

        updatedLabel.font = .preferredFont(forTextStyle: .caption2)
        updatedLabel.adjustsFontForContentSizeCategory = true
        updatedLabel.textColor = .secondaryLabel
        updatedLabel.numberOfLines = 1

        insertButton.setTitle("Insert Latest", for: .normal)
        insertButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        insertButton.addTarget(self, action: #selector(insertLatestText), for: .touchUpInside)

        let nextKeyboardButton = UIButton(type: .system)
        nextKeyboardButton.setTitle("Next Keyboard", for: .normal)
        nextKeyboardButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        nextKeyboardButton.addTarget(self, action: #selector(showNextKeyboard), for: .touchUpInside)

        let buttonRow = UIStackView(arrangedSubviews: [insertButton, nextKeyboardButton])
        buttonRow.axis = .horizontal
        buttonRow.alignment = .fill
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 8

        let stack = UIStackView(arrangedSubviews: [titleLabel, previewLabel, updatedLabel, buttonRow])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 10
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        stack.isLayoutMarginsRelativeArrangement = true

        view.addSubview(stack)

        let heightConstraint = view.heightAnchor.constraint(greaterThanOrEqualToConstant: 216)
        heightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            heightConstraint,
        ])
    }

    private func refreshLatestText() {
        latestText = KeyboardTranscriptStore.latestText

        if let latestText {
            previewLabel.text = latestText
            updatedLabel.text = KeyboardTranscriptStore.updatedAtText
            insertButton.isEnabled = true
        } else {
            previewLabel.text = "Open Murmur to record. Enable Full Access for this keyboard to insert the latest transcript."
            updatedLabel.text = nil
            insertButton.isEnabled = false
        }
    }

    @objc private func insertLatestText() {
        refreshLatestText()
        guard let latestText, !latestText.isEmpty else { return }
        textDocumentProxy.insertText(latestText)
    }

    @objc private func showNextKeyboard() {
        advanceToNextInputMode()
    }
}

private enum KeyboardTranscriptStore {
    static let suiteName = "group.com.hydai.Murmur"
    static let latestTextKey = "latestProcessedTranscript"
    static let latestUpdatedAtKey = "latestProcessedTranscriptUpdatedAt"

    static var latestText: String? {
        let text = defaults?.string(forKey: latestTextKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    static var updatedAtText: String? {
        guard let defaults else { return nil }
        let timestamp = defaults.double(forKey: latestUpdatedAtKey)
        guard timestamp > 0 else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let text = formatter.localizedString(for: Date(timeIntervalSince1970: timestamp), relativeTo: Date())
        return "Updated \(text)"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}
