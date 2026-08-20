import re

file_path = "/Users/galimanideepreddy/Documents/milk_delivery/milk_delivery_frontend/lib/screens/customer/delivery_tracker_tab.dart"

with open(file_path, 'r') as f:
    content = f.read()

replacements = [
    (r'(const )?Color\(0xFF0D7C66\)', 'UiTone.primary'),
    (r'(const )?Color\(0xFF0F766E\)', 'UiTone.primary'),
    (r'(const )?Color\(0xFF10B981\)', 'UiTone.secondary'),
    (r'(const )?Color\(0xFF10B766\)', 'UiTone.secondary'),
    (r'(const )?Color\(0xFFE11D48\)', 'UiTone.error'),
    (r'(const )?Color\(0xFFDC2626\)', 'UiTone.error'),
    (r'(const )?Color\(0xFFF59E0B\)', 'UiTone.warning'),
    (r'(const )?Color\(0xFFD97706\)', 'UiTone.warning'),
    (r'(const )?Color\(0xFF475569\)', 'UiTone.softText'),
    (r'(const )?Color\(0xFFE2E8F0\)', 'UiTone.surfaceBorder'),
    (r'(const )?Color\(0xFFF8FAFC\)', 'UiTone.shellBackground'),
    (r'(const )?Color\(0xFFF1F5F9\)', 'UiTone.surfaceMuted'),
    (r'(const )?Color\(0xFF0284C7\)', 'UiTone.accentBlue'),
    (r'(const )?Color\(0xFF2563EB\)', 'UiTone.accentBlue'),
    (r'(const )?Color\(0xFF0F172A\)', 'UiTone.ink'),
]

for old, new in replacements:
    content = re.sub(old, new, content)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
