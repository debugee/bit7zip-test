#/bin/bash
git clone http://github.com/rikyoz/bit7z -b v4.0.8

cd bit7z

git apply --ignore-whitespace ../overlays/ports/bit7z/fix_install.patch
git apply --ignore-whitespace ../overlays/ports/bit7z/fix_dependency.patch

git add .
git commit -m "Fix install and dependency"

cat ../test.patch.cmake >> CMakelists.txt

git diff > test.patch

mv test.patch ../overlays/ports/bit7z/test.patch
