import 'package:transliteration/transliteration.dart';

class Translations {
  static final _kannadaTransliterator = KannadaTransliterator();

  static String transliterateToKannada(String text) {
    return _kannadaTransliterator.transliterate(text);
  }

  static String translate(String key, {Map<String, String>? args, String locale = 'en'}) {
    if (key == 'name_to_kannada' && args != null && args.containsKey('name')) {
      return transliterateToKannada(args['name']!);
    } else if (key == 'village_to_kannada' && args != null && args.containsKey('village')) {
      return transliterateToKannada(args['village']!);
    }
    return key; // Return the original key if no translation is needed
  }
}