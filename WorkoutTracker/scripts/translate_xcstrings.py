import json
import os
import re
from deep_translator import GoogleTranslator

# Target languages (Google Translate codes)
TARGET_LANGS = ["ru", "es", "fr", "de", "it"]
XCSTRINGS_PATH = "Localizable.xcstrings"

def translate_text(text, target_lang):
    if not text or len(text.strip()) == 0:
        return text
    
    # Simple placeholder protection (Google Translate sometimes breaks %@, %lld)
    # Replace %@ with a very rare word or tag, e.g. <x>
    protected_text = text
    placeholders = re.findall(r'(%[@dfl]|%[0-9]*\.[0-9]*[f])', text)
    
    for i, p in enumerate(placeholders):
        protected_text = protected_text.replace(p, f"__PH{i}__", 1)
        
    try:
        translated = GoogleTranslator(source='en', target=target_lang).translate(protected_text)
        
        # Restore placeholders
        for i, p in enumerate(placeholders):
            translated = translated.replace(f"__PH{i}__", p)
            
        return translated
    except Exception as e:
        print(f"Error translating '{text}' to {target_lang}: {e}")
        return text

def main():
    if not os.path.exists(XCSTRINGS_PATH):
        print(f"Error: Could not find {XCSTRINGS_PATH}")
        return

    with open(XCSTRINGS_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)

    strings = data.get("strings", {})
    total_translated = 0

    print(f"Loaded {len(strings)} strings from Localizable.xcstrings.")

    for key, item in strings.items():
        # The english text is usually the key itself, 
        # unless there's a specific 'en' localization value, but Apple default is the key.
        en_text = key
        
        if "localizations" not in item:
            item["localizations"] = {}
            
        for lang in TARGET_LANGS:
            needs_translation = False
            
            if lang not in item["localizations"]:
                needs_translation = True
            else:
                string_unit = item["localizations"][lang].get("stringUnit", {})
                state = string_unit.get("state", "")
                if state != "translated" or not string_unit.get("value"):
                    needs_translation = True

            if needs_translation:
                print(f"Translating: [{lang}] '{en_text}'...")
                translated_text = translate_text(en_text, lang)
                
                # Update JSON
                item["localizations"][lang] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": translated_text
                    }
                }
                total_translated += 1

    if total_translated > 0:
        with open(XCSTRINGS_PATH, 'w', encoding='utf-8') as f:
            # Apple uses 2 spaces indent and sorted keys for .xcstrings
            json.dump(data, f, indent=2, ensure_ascii=False, sort_keys=True)
        print(f"\n✅ Successfully translated {total_translated} missing entries!")
    else:
        print("\n✅ All strings are already translated!")

if __name__ == "__main__":
    main()
