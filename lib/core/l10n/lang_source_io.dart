// On Android, Windows and Mac there is no Office In 1 page around ProDFOS: the device's language is used.
String? hostLanguage() => null;
void listenHostLanguage(void Function(String code) onChange) {}
