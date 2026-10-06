#!/usr/bin/env bash
# Даёт коду веб-сборки имена с номером сборки: main.<build>.dart.js и
# flutter_bootstrap.<build>.js. Хостинг (nginx перед Apache на REG.RU) может
# отдавать .js с долгим кэшем, и браузер неделями держит старую версию;
# с новым именем у каждой сборки старый файл из кэша просто не используется.
#
# Запуск после `flutter build web`: tool/cache_bust.sh build/web <build>
set -euo pipefail
dir=${1:?папка сборки}
v=${2:?номер сборки}

mv "$dir/main.dart.js" "$dir/main.$v.dart.js"
sed -i "s/\"main\.dart\.js\"/\"main.$v.dart.js\"/g" "$dir/flutter_bootstrap.js"
mv "$dir/flutter_bootstrap.js" "$dir/flutter_bootstrap.$v.js"
sed -i "s/src=\"flutter_bootstrap\.js\"/src=\"flutter_bootstrap.$v.js\"/" "$dir/index.html"

grep -q "main.$v.dart.js" "$dir/flutter_bootstrap.$v.js"
grep -q "flutter_bootstrap.$v.js" "$dir/index.html"
echo "Сборка $v: main.$v.dart.js, flutter_bootstrap.$v.js"
