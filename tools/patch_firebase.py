import glob

for p in glob.glob('android/settings.gradle*'):
    s = open(p, encoding='utf-8').read()
    if 'com.google.gms.google-services' in s:
        print('settings already patched:', p)
        continue
    if p.endswith('.kts'):
        line = '    id("com.google.gms.google-services") version "4.4.2" apply false'
    else:
        line = '    id "com.google.gms.google-services" version "4.4.2" apply false'
    if 'plugins {' in s:
        s = s.replace('plugins {', 'plugins {\n' + line, 1)
        open(p, 'w', encoding='utf-8').write(s)
        print('patched settings:', p)
    else:
        print('no plugins block in', p)

for p in glob.glob('android/app/build.gradle*'):
    s = open(p, encoding='utf-8').read()
    if 'com.google.gms.google-services' in s:
        print('app already patched:', p)
        continue
    if p.endswith('.kts'):
        old = 'id("com.android.application")'
        new = 'id("com.android.application")\n    id("com.google.gms.google-services")'
    else:
        old = "id 'com.android.application'"
        new = "id 'com.android.application'\n    id 'com.google.gms.google-services'"
    if old in s:
        s = s.replace(old, new, 1)
        open(p, 'w', encoding='utf-8').write(s)
        print('patched app:', p)
    else:
        print('application id line not found in', p)

print('firebase gradle patch done')
