import Carbon.HIToolbox
import Testing
@testable import RedditReminder

@Test func shortcutRecorderCancelsOnEscape() {
    let result = ShortcutRecorderInput.evaluate(
        keyCode: UInt16(kVK_Escape),
        modifiers: [.maskCommand],
        keyDisplay: "Escape"
    )

    #expect(result == .cancelled)
}

@Test func shortcutRecorderRejectsModifierOnlyInput() {
    let result = ShortcutRecorderInput.evaluate(
        keyCode: 35,
        modifiers: [.maskShift],
        keyDisplay: "P"
    )

    #expect(result == .invalid(ShortcutRecorderInput.validationMessage))
}

@Test func shortcutRecorderBuildsValidCustomShortcut() {
    let result = ShortcutRecorderInput.evaluate(
        keyCode: 35,
        modifiers: [.maskCommand, .maskAlternate],
        keyDisplay: "P"
    )

    #expect(result == .shortcut(KeyboardShortcutConfig.custom(
        keyCode: 35,
        modifiers: [.maskCommand, .maskAlternate],
        keyDisplay: "P"
    )))
}

@Test func shortcutRecorderNormalizesCharacterDisplay() {
    #expect(ShortcutRecorderInput.keyDisplay(keyCode: 35, charactersIgnoringModifiers: " p ") == "P")
}

@Test func shortcutRecorderUsesFallbackDisplayForBlankCharacters() {
    #expect(ShortcutRecorderInput.keyDisplay(keyCode: 1234, charactersIgnoringModifiers: " ") == "Key 1234")
}

@Test func shortcutRecorderNamesSpecialKeysWithoutEventConstruction() {
    #expect(ShortcutRecorderInput.keyDisplay(keyCode: UInt16(kVK_Space), charactersIgnoringModifiers: nil) == "Space")
}
