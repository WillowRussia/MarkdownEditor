//
//  ContentView.swift
//  MarkdownEditor
//
//  Created by Илья Востров on 16.11.2024.
//

import SwiftUI
import Markdown

class MarkdownEditorController: ObservableObject {
    private weak var textView: UITextView?
    private var fontSizeView: CGFloat = 24

    func setTextView(_ textView: UITextView) {
        self.textView = textView
    }

    func getCurrentText() -> String {
        return convertAttributedTextToMarkdown(textView ?? UITextView())
    }

    func convertAttributedTextToMarkdown(_ textView: UITextView) -> String {
        guard let attributedText = textView.attributedText else { return "" }
        var markdownText = ""
        
        attributedText.enumerateAttributes(in: NSRange(location: 0, length: attributedText.length), options: []) { attributes, range, _ in
            let substring = (attributedText.string as NSString).substring(with: range)
            
            switch attributes {
            case let attrs where (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) == true && ((fontSizeView)...).contains((attrs[.font] as? UIFont)!.pointSize):
                switch (attrs[.font] as? UIFont)?.pointSize {
                case fontSizeView + 10:
                    markdownText.append("# \(substring)")
                case fontSizeView + 8:
                    markdownText.append("## \(substring)")
                case fontSizeView + 6:
                    markdownText.append("### \(substring)")
                case fontSizeView + 4:
                    markdownText.append("#### \(substring)")
                case fontSizeView + 2:
                    markdownText.append("##### \(substring)")
                case fontSizeView:
                    markdownText.append("###### \(substring)")
                default:
                    break
                }
                
                
            case let attrs where (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) == true &&
                (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true:
                markdownText.append("***\(substring)***")
                
            case let attrs where (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) == true:
                markdownText.append("**\(substring)**")
                
            case let attrs where (attrs[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true:
                markdownText.append("_\(substring)_")
                
            case let attrs where (attrs[.link] as? URL) != nil:
                if let link = attributes[.link] as? URL {
                    markdownText.append("[\(substring)](\(link.absoluteString))")
                }
                
            case let attrs where (attrs[.strikethroughStyle] as? Int) == NSUnderlineStyle.single.rawValue:
                markdownText.append("~~\(substring.dropLast(2))~~")
                
            case let attrs where (attrs[.font] as? UIFont)?.fontName.contains("Courier") == true:
                markdownText.append("`\(substring.dropLast(2))`")
                
            default:
                markdownText.append(substring)
            }
        }
        
        return markdownText
    }

}

struct MarkdownEditor: UIViewRepresentable {
    @Binding var text: String
    var controller: MarkdownEditorController

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.backgroundColor = UIColor.systemBackground
        textView.isScrollEnabled = true
        textView.isSelectable = true
        textView.dataDetectorTypes = [.link]
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .yes
        textView.text = text
        
        controller.setTextView(textView)

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let selectedRange = uiView.selectedRange
        let oldLenText = uiView.text.count
        context.coordinator.applyMarkdownStyles(to: uiView)
        let newLenText = uiView.text.count
        let correctedRange = NSRange(
            location: selectedRange.location - (oldLenText - newLenText),
                length: 0
            )
        uiView.selectedRange = correctedRange
        
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }


    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownEditor
        var fontSizeView: CGFloat = 18

        init(_ parent: MarkdownEditor) {
            self.parent = parent
        }
        
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            UIApplication.shared.open(URL, options: [:], completionHandler: nil)
            return false
        }
        
        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if text == "\n" {
                handleNewLine(textView, range: range)
                return false
            } else if text == " " {
                let plainSpace = NSAttributedString(string: " ", attributes: [
                    .font: UIFont.systemFont(ofSize: fontSizeView),
                    .foregroundColor: UIColor.label
                ])
                let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
                mutableAttributedString.replaceCharacters(in: range, with: plainSpace)
                textView.attributedText = mutableAttributedString
                let cursorPosition = NSRange(location: range.location + 1, length: 0)
                textView.selectedRange = cursorPosition

                parent.text = textView.attributedText.string
                return false
            }
            return true
        }

        private func handleNewLine(_ textView: UITextView, range: NSRange) {
            let currentText = textView.text ?? ""
            let previousLineRange = (currentText as NSString).lineRange(for: NSRange(location: range.location, length: 0))
            let previousLine = (currentText as NSString).substring(with: previousLineRange).trimmingCharacters(in: .whitespaces)

            if previousLine.starts(with: "-") {
                let newText = "\n- "
                textView.textStorage.replaceCharacters(in: range, with: newText)
                textView.selectedRange = NSRange(location: range.location + newText.count, length: 0)
            } else if let match = previousLine.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let numberString = String(previousLine[match]).trimmingCharacters(in: .whitespaces)
                if let number = Int(numberString.replacingOccurrences(of: ".", with: "")) {
                    let newText = "\n\(number + 1). "
                    textView.textStorage.replaceCharacters(in: range, with: newText)
                    textView.selectedRange = NSRange(location: range.location + newText.count, length: 0)
                }
            } else {
                textView.textStorage.replaceCharacters(in: range, with: "\n")
                textView.selectedRange = NSRange(location: range.location + 1, length: 0)
            }

            applyMarkdownStyles(to: textView)
        }
        
        //MARK: - Markdown to Text convert
        
        func applyMarkdownStyles(to textView: UITextView) {
            guard let attributedText = textView.attributedText.mutableCopy() as? NSMutableAttributedString else { return }
            
            let document = Document(parsing: attributedText.string)
            processMarkdownBlock(document.children, in: attributedText)
            
            textView.attributedText = attributedText
        }

        private func processMarkdownBlock(_ blocks: MarkupChildren, in attributedText: NSMutableAttributedString) {
            for block in blocks {
                switch block {
                case let heading as Heading:
                    applyHeadingStyle(heading, in: attributedText)
                    
                case let paragraph as Paragraph:
                    processMarkdownInline(paragraph.inlineChildren, in: attributedText)

                    
                case let list as UnorderedList:
                    for listItem in list.listItems {
                        processMarkdownBlock(listItem.children, in: attributedText)
                    }
                case let list as OrderedList:
                    for listItem in list.listItems {
                        processMarkdownBlock(listItem.children, in: attributedText)
                    }
                    
                default:
                    continue
                }
            }
        }

        private func processMarkdownInline(_ inlines: LazyMapSequence<MarkupChildren, InlineMarkup>, in attributedText: NSMutableAttributedString) {
            for inline in inlines {
                switch inline {
                case let strong as Strong:
                    if let range = attributedText.string.range(of: "**\(strong.plainText)**") {
                        applyBoldFormatting(to: strong.plainText, markdown: "**", in: attributedText, range: range)
                    } else if let range = attributedText.string.range(of: "__\(strong.plainText)__") {
                        applyBoldFormatting(to: strong.plainText, markdown: "__", in: attributedText, range: range)
                    }
                    
                case let emphasis as Emphasis:
                        for emhasisStrong in emphasis.inlineChildren {
                            switch emhasisStrong {
                            case let strong as Strong:
      
                                applyBoldItalicFormatting(to: strong.plainText, markdown: "***", in: attributedText)
                                applyBoldItalicFormatting(to: strong.plainText, markdown: "___", in: attributedText)
                           
                            default:
                                if let range = attributedText.string.range(of: "_\(emphasis.plainText)_") {
                                    applyItalicFormatting(to: emphasis.plainText, markdown: "_", in: attributedText, range: range)
                                }
                                else if let range = attributedText.string.range(of: "*\(emphasis.plainText)*") {
                                    applyItalicFormatting(to: emphasis.plainText, markdown: "*", in: attributedText, range: range)
                                }
                            }
                        }
                case let link as Markdown.Link:
                    applyLinkFormatting(link, in: attributedText)
                    
                case let code as InlineCode:
                    applyInlineCodeFormatting(code, in: attributedText)
                    
                case let strikethrough as Strikethrough:
                    applyStrikethroughFormatting(strikethrough, in: attributedText)
                    
                default:
                    continue
                }
            }
        }
        
        //MARK: - Setting up styles

        private func applyHeadingStyle(_ heading: Heading, in attributedText: NSMutableAttributedString) {
            let rawHeadingText = heading.plainText
            let markdownPrefix = String(repeating: "#", count: heading.level) + " "
            
            if let range = attributedText.string.range(of: markdownPrefix + rawHeadingText) {
                let nsRange = NSRange(range, in: attributedText.string)

                attributedText.replaceCharacters(in: nsRange, with: rawHeadingText)

                let styledRange = NSRange(location: nsRange.location, length: rawHeadingText.count)
                attributedText.addAttributes(
                    [
                        .font: UIFont.boldSystemFont(ofSize: CGFloat(fontSizeView * 2 - CGFloat(heading.level * 2))),
                        .foregroundColor: UIColor.label
                    ],
                    range: styledRange
                )
            }
        }

        
        private func applyBoldFormatting(to text: String, markdown: String, in attributedText: NSMutableAttributedString, range: Range<String.Index>) {
            let nsRange = NSRange(range, in: attributedText.string)
            attributedText.replaceCharacters(in: nsRange, with: text)
            let newRange = NSRange(location: nsRange.location, length: text.count)

            attributedText.addAttributes(
                [.font: UIFont.boldSystemFont(ofSize: fontSizeView)],
                range: newRange
            )
        }
        
        private func applyItalicFormatting(to text: String, markdown: String, in attributedText: NSMutableAttributedString, range: Range<String.Index>) {
            let nsRange = NSRange(range, in: attributedText.string)
            attributedText.replaceCharacters(in: nsRange, with: text)
            let newRange = NSRange(location: nsRange.location, length: text.count)

            attributedText.addAttributes(
                [.font: UIFont.italicSystemFont(ofSize: fontSizeView)],
                range: newRange
            )
        }
        
        private func applyBoldItalicFormatting(to text: String, markdown: String, in attributedText: NSMutableAttributedString) {
            if let range = attributedText.string.range(of: "\(markdown)\(text)\(markdown)") {
                let nsRange = NSRange(range, in: attributedText.string)
                attributedText.replaceCharacters(in: nsRange, with: text)

                let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                    .withSymbolicTraits([.traitBold, .traitItalic])
                attributedText.addAttributes(
                    [
                        .font: UIFont(descriptor: fontDescriptor!, size: fontSizeView)
                    ],
                    range: NSRange(location: nsRange.location, length: text.count)
                )
            }
        }

        
        private func applyInlineCodeFormatting(_ code: InlineCode, in attributedText: NSMutableAttributedString) {

            if let range = attributedText.string.range(of: code.plainText) {
                let nsRange = NSRange(range, in: attributedText.string)
                attributedText.replaceCharacters(in: nsRange, with: String(code.plainText.dropFirst().dropLast()))
                
                attributedText.addAttributes(
                    [
                        .font: UIFont(name: "Courier", size: fontSizeView) ?? UIFont.systemFont(ofSize: fontSizeView),
                        .foregroundColor: UIColor.systemBlue
                    ],
                    range: NSRange(location: nsRange.location, length: code.plainText.count)
                )
            }
        }

        
        private func applyStrikethroughFormatting(_ strikethrough: Strikethrough, in attributedText: NSMutableAttributedString) {
            if let range = attributedText.string.range(of: "~\(strikethrough.plainText)~") {
                let nsRange = NSRange(range, in: attributedText.string)
                attributedText.replaceCharacters(in: nsRange, with: String(strikethrough.plainText.dropFirst().dropLast()))
                attributedText.addAttributes(
                    [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .font: UIFont.systemFont(ofSize: fontSizeView)
                    ],
                    range: NSRange(location: nsRange.location, length: strikethrough.plainText.count)
                )
            }
        }
        
        private func applyLinkFormatting(_ link: Markdown.Link, in attributedText: NSMutableAttributedString) {
            let linkText = link.plainText
            let markdownLink = "[\(linkText)](\(link.destination ?? ""))"
            
            if let range = attributedText.string.range(of: markdownLink) {
                let nsRange = NSRange(range, in: attributedText.string)
                attributedText.replaceCharacters(in: nsRange, with: linkText)
                
                attributedText.addAttributes(
                    [
                        .link: URL(string: link.destination ?? "") ?? "",
                        .font: UIFont.systemFont(ofSize: fontSizeView),
                        .foregroundColor: UIColor.systemBlue
                    ],
                    range: NSRange(location: nsRange.location, length: linkText.count)
                )
            }
        }
        
        
    }
}

struct MarkdownEditorView: View {
    @State private var markdownText: String = """
    # Заголовок
    Это **жирный текст**, а это _курсив_.
    текст ~~зачеркнутый~~ \n
     ***жирный курсив*** 
    `Что-то` 

    
    [Ссылка](https://www.deepl.com/ru/translator)
    1. *Пункт 1*
    2. __Пункт 2__
    3. ***Пункт 3***

    - *Пункт 1*
    - __Пункт 2__
    - ***Пункт 3*** 
    """

    @StateObject private var controller = MarkdownEditorController()

    var body: some View {
            VStack {
                Text("Markdown Editor")
                    .font(.headline)
                    .padding()
                MarkdownEditor(text: $markdownText, controller: controller)
                    .padding()
                    .border(Color.gray, width: 1)
                Button("Вернуть текст") {
                    print(controller.getCurrentText())
                    
                }.padding()
            }
            .padding()
        }
}


#Preview {
    MarkdownEditorView()
}
