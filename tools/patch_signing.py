import glob
import sys

paths = glob.glob('android/app/build.gradle*')
print('gradle files:', paths)
patched = False
for p in paths:
    s = open(p, encoding='utf-8').read()
    if p.endswith('.kts'):
        old = 'signingConfig = signingConfigs.getByName("debug")'
        new = ('signingConfig = signingConfigs.create("mysaathi") { '
               'storeFile = project.file(System.getenv("KS_FILE") ?: ""); '
               'storePassword = System.getenv("KS_PASS") ?: ""; '
               'keyAlias = System.getenv("KS_ALIAS") ?: ""; '
               'keyPassword = System.getenv("KS_PASS") ?: "" }')
    else:
        old = 'signingConfig signingConfigs.debug'
        new = ('signingConfig signingConfigs.create("mysaathi") { '
               'storeFile file(System.getenv("KS_FILE")); '
               'storePassword System.getenv("KS_PASS"); '
               'keyAlias System.getenv("KS_ALIAS"); '
               'keyPassword System.getenv("KS_PASS") }')
    if old in s:
        open(p, 'w', encoding='utf-8').write(s.replace(old, new))
        print('patched', p)
        patched = True
    else:
        print('pattern not found in', p)
if not patched:
    print('ERROR: could not patch signing config')
    sys.exit(1)
print('signing patch done')
