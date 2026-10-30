import Foundation

/// 画面に出す文言を、Mac の言語設定に合わせて訳す。
/// キーは英語の文言そのもので、訳は Resources/<言語>.lproj/Localizable.strings に置く（訳がなければ英語のまま出る）
func L(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: nil, table: nil)
}

/// %@ や %d を含む文言を訳して、値を埋め込む
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: Locale.current, arguments: args)
}
