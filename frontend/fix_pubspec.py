import re
with open('/Users/khanak/Desktop/mess/frontend/pubspec.yaml', 'r') as f:
    text = f.read()
# find the first occurrence of flutter_launcher_icons and trim everything after it
idx = text.find('flutter_launcher_icons:')
if idx != -1:
    text = text[:idx]

text += """
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path: "assets/app_icon.png"

flutter_native_splash:
  color: "#111318"
  image: "assets/app_icon.png"
  android: true
  ios: true
"""
with open('/Users/khanak/Desktop/mess/frontend/pubspec.yaml', 'w') as f:
    f.write(text)
