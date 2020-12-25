# About

Modified `icu` library from chromium https://github.com/chromium/chromium/tree/master/base

## EXTRA FEATURES

- ported to CMake
- supports Conan
- added CMake options to disable some features
- supports starboard from cobalt.foo
- ported to WASM (emscripten) with threading support
- ported to WASM (emscripten) without threading support

## DOCS

The Chromium Projects https://www.chromium.org/developers

Chromium docs https://chromium.googlesource.com/chromium/src/+/master/docs

## HOW TO BUILD FROM SOURCE

Create conan profile, see https://github.com/blockspacer/CXXCTP#install-conan---a-crossplatform-dependency-manager-for-c

Build with created conan profile:

```
conan create . conan/stable --profile clang

# clean build cache
conan remove "*" --build --force
```

## HOW TO INSTALL FROM CONAN

```
conan install --build=missing --profile clang -o enable_tests=False ..
```

## USAGE EXAMPLES

TODO

## LICENSE

TODO

## PORT ISSUES

- Some flags from `declare_args` may be not supported.
- Some platforms may be not supported.

## How to add custom language (i18n, icu, fonts)

- modify languages in filters.json, see below.
- add font file with support of your language

## How to make icu data files smaller (ICU 64-2)

modify languages in filters.json (see ICU_DATA_FILTER_FILE below), more languages = bigger bundle size

See examples:

- thirdparty/icu_wrapper/third_party/scripts/filters.json
- https://github.com/cjbd/icu/tree/9f0f47b1e410b137762f2e3699359f0dbfcdbc05/filters

verify filters.json using jsonschemavalidator.net and (remove comments) https://github.com/unicode-org/icu/blob/release-64-2/icu4c/source/data/buildtool/filtration_schema.json

```bash
git clone -brelease-64-2 https://github.com/unicode-org/icu.git icu64
cd icu64/icu4c
PROJ_ROOT=${PWD}
ls -artl ${PROJ_ROOT}
pip3 install --index-url=https://pypi.python.org/simple/ --trusted-host pypi.org --trusted-host pypi.python.org --trusted-host files.pythonhosted.org wheel \
  --user hjson jsonschema
ICUROOT=${PROJ_ROOT}/third_party/icu
ls -artl ${ICUROOT}
cd ${ICUROOT}
chmod +x "${ICUROOT}/third_party/icu/source/configure"
chmod +x "${ICUROOT}/source/runConfigureICU"
# must exist, copy some json file from `filters` folder
ICU_FILTERS_JSON=........
file "${ICU_FILTERS_JSON}"
mkdir build
cd build
ICU_DATA_FILTER_FILE="${ICU_FILTERS_JSON}" \
  "${ICUROOT}/source/runConfigureICU" \
    Linux/gcc --disable-tests --with-data-packaging=archive \
    --enable-samples=no --enable-dyload=no \
    --enable-static --disable-shared
make clean
rm -rf build
make -j8
ls data/out
rm ${PROJ_ROOT}/resources/icu/icudtl.dat
cp ${ICUROOT}/build/data/out/icudt64l.dat ${PROJ_ROOT}/resources/icu/icudtl.dat
ls ${PROJ_ROOT}/resources/icu
```

see:
 - https://www.suninf.net/tags/chromium.html

see:
 - https://gclxry.com/custom-chromium-icu-library/
 - https://github.com/unicode-org/icu/blob/master/docs/userguide/icu_data/buildtool.md#filtering-by-language-only
 - http://userguide.icu-project.org/howtouseicu#TOC-C-With-Your-Own-Build-System
 - http://userguide.icu-project.org/icudata
 - http://cldr.unicode.org/development/development-process/design-proposals/specifying-text-break-variants-in-locale-ids
 - https://github.com/unicode-org/icu/tree/release-64-2
 - https://github.com/blockspacer/cobalt-clone-28052019/blob/89664d116629734759176d820e9923257717e09c/src/third_party/icu/README.chromium#L26
 - https://github.com/blockspacer/cobalt-clone-28052019/blob/89664d116629734759176d820e9923257717e09c/src/third_party/icu/scripts/accept_lang.list
 - http://userguide.icu-project.org/icufaq#TOC-How-can-I-reduce-the-size-of-the-ICU-data-library-
 - https://github.com/sillsdev/icu-dotnet/wiki/Making-a-minimal-build-for-ICU58-or-later
 - https://www.oipapio.com/question-4138842
 - https://qiita.com/shimacpyon/items/82d275c2f5f508cbd7f4

## How to make ICU smaller?

Define `UCONFIG_NO_COLLATION` or `UCONFIG_ONLY_COLLATION`, `UCONFIG_NO_LEGACY_CONVERSION`, `UCONFIG_ONLY_HTML_CONVERSION`, `UCONFIG_NO_IDNA`, etc.

see:
- https://github.com/sillsdev/icu-dotnet/wiki/Making-a-minimal-build-for-ICU58-or-later
- http://userguide.icu-project.org/howtouseicu
- http://transit.iut2.upmf-grenoble.fr/doc/icu-doc/html/uconfig_8h.html

## Used chromium version

```bash
from commit 07bf855b4db90ee18e4cf3452bcbc0b4f80256e5
05/13/2019 12:28 PM
Worker: Clear ResourceTimingNotifier on WorkerFetchContext::Detach()
Bug: 959508, 960626
Change-Id: I2663e5acddec0d9f88a78842c093c594fb57acb8
Reviewed-on: https://chromium-review.googlesource.com/c/chromium/src/+/1609024
```
