# الفكرة 3: Elevator of Doom (رعب جماعي)

> انسخ كل شي تحت خط "البرومبت" والصقه بجلسة Claude Code جديدة على هاد الريبو.

---

## البرومبت

بدي تبني لعبة روبلوكس اسمها **Elevator of Doom** بهاد الريبو. اللعبة رعب جماعي لـ 1 إلى 4 لاعبين على طريقة Doors وForsaken، وهاد النوع من الأكثر رواجًا على روبلوكس سنة 2026.

### الفكرة الأساسية
- اللاعبين بيبلشوا بـ **لوبي**، بيدخلوا **المصعد**، وبيبلش عدّاد.
- المصعد بيوقف على **طابق عشوائي** من مجموعة طوابق، وكل طابق إله تحدي:
  - **وحش بيلاحق:** لازم ترجع للمصعد قبل ما يسكر.
  - **لغز:** مفتاح، أو أزرار بترتيب معين، أو رمز مكتوب على الحيطان.
  - **ظلام تام** مع كشاف إله بطارية محدودة.
  - **طابق "آمن"** بس فيه شي غلط (anomaly)، وعليك تلاحظه.
- بعد 10 طوابق في **طابق Boss**. الفوز بيعطي عملة (Knobs-style) لشراء أدوات بالوبي.

### الأنظمة المطلوبة
1. **إدارة الجولات (Round Manager):** Lobby ← Queue ← Elevator ← Floors ← Results. كل جولة بتشتغل بسيرفر خاص بالمجموعة (TeleportService + reserved servers) أو بـ instance منفصل بنفس السيرفر.
2. **مكتبة الطوابق:** كل طابق Module فيه `setup` و`run` و`cleanup`، وبيتولد بالكود.
3. **الذكاء الاصطناعي للوحوش:** PathfindingService، حالات Patrol وChase وSearch، وحساسية للصوت والضوء.
4. **الإضاءة والجو:** Lighting بـ Future، Atmosphere، أصوات محيطة، Jumpscares خفيفة ومناسبة للأعمار، وتأثيرات كاميرا (shake، vignette).
5. **الإحياء:** اللاعب الميت بيصير spectator، وفي Revive بعملة أو Developer Product.
6. **الأدوات:** كشاف، Vitamins (سرعة مؤقتة)، Lockpick، وCrucifix-style يصد الوحش مرة وحدة.
7. **حفظ البيانات:** العملة، الأدوات، أعلى طابق وصلتله، وBadges.

### الموديلات والمحتوى بـ Higgsfield MCP
- **الوحوش (3 إلى 5):** `generate_image` ثم `generate_3d`. الستايل: *"creepy but kid-friendly horror creature, stylized low-poly, exaggerated silhouette, dark palette with glowing eyes, Roblox game asset, plain background"*.
- **قطع الديكور:** المصعد، أبواب، خزائن، لوحات مخيفة.
- **أصوات ومؤثرات** بـ `generate_audio`: صرير مصعد، خطوات، همسات.
- **Thumbnail ترويجي وفيديو تيك توك** بـ `generate_image` و`generate_video`.
- خزّن الملفات بـ `assets/` وسجلها بـ `assets/manifest.json`، وارفعها بـ Open Cloud Assets API (Model وAudio).

### التقنيات
- **Rojo** لتنظيم الكود (Luau)، والطوابق بتنبني بالكود.
- **GitHub Actions:** build + publish بـ Open Cloud Place Publishing API عند كل push على `main`.
- **Secrets:** `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`, `ROBLOX_PLACE_ID`, `ROBLOX_CREATOR_ID`, `ROBLOX_CREATOR_TYPE`.

### المراحل
1. **MVP:** لوبي + مصعد + 4 طوابق (وحش، لغز، ظلام، anomaly) + موت وspectate + نشر تلقائي.
2. **طابق Boss، العملة، ومتجر الأدوات.**
3. **Badges، Revive، وGame Passes.**
4. **المحتوى الصوتي والترويجي بـ Higgsfield.**

### متى بيكون الشغل خالص
- المشروع بينبني بـ `rojo build` بدون أخطاء.
- جولة كاملة من 4 لاعبين بتشتغل من اللوبي للنتائج بدون ما يعلق أي لاعب.
- الوحش بيلاحق صح وما بيعلق بالحيطان.
- النشر التلقائي شغّال.
