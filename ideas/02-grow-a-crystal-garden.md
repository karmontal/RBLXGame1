# الفكرة 2: Grow a Crystal Garden (زراعة خامل وتبادل)

> انسخ كل شي تحت خط "البرومبت" والصقه بجلسة Claude Code جديدة على هاد الريبو.

---

## البرومبت

بدي تبني لعبة روبلوكس اسمها **Grow a Crystal Garden** بهاد الريبو. اللعبة من نوع "idle-grow simulator" مع تبادل بين اللاعبين، على طريقة Grow a Garden، وهاد من أكثر الأنواع رواجًا على روبلوكس سنة 2026.

### الفكرة الأساسية
- كل لاعب إله **حديقة** فيها خانات (Plots) بيزرع فيها **بذور بلورات**.
- البلورات **بتكبر مع الوقت الحقيقي**، حتى وإنت مش موجود باللعبة. بنحسبها من `os.time()` عند الدخول.
- لما تكبر البلورة بتحصدها وبتبيعها عند **التاجر** أو بتحتفظ فيها.
- **متجر البذور** بيتجدد كل 5 دقائق بمخزون محدود وندرات عشوائية.

### الأنظمة المطلوبة
1. **البذور والندرات:** Common لـ Prismatic، ولكل بلورة وقت نمو وسعر بيع.
2. **الطقس:** بيتغير كل 10 دقائق، ومنه Rain وStorm وAurora وMeteor Shower. كل طقس بيعطي **طفرات** للبلورات اللي عم تكبر، مثل Charged ×3 وFrozen ×2 وCosmic ×8، والطفرات بتتراكم.
3. **التبادل (Trading):** طلب تبادل، نافذة فيها الطرفين، تأكيد مزدوج مع عدّاد 5 ثواني. التبادل لازم يكون **ذرّي على السيرفر** ومحمي من التكرار (dupe) بـ session locking.
4. **الحيوانات المساعدة (Pets):** بتسرّع النمو أو بتزيد نسبة الطفرات.
5. **التوسيع:** بتشتري خانات زراعة إضافية.
6. **حفظ البيانات** بـ DataStoreService مع ProfileService-style session locking، لأن التبادل بيخلي الـ dupe خطر حقيقي.
7. **Leaderboard** عالمي لأغلى حديقة (OrderedDataStore).

### الموديلات بـ Higgsfield MCP
- لكل بلورة 3 مراحل نمو (صغيرة، متوسطة، كاملة). بنعمل `generate_image` ثم `generate_3d` للمرحلة الكاملة، والمراحل الأصغر بتكون Scale للموديل نفسه.
- الستايل الموحّد: *"stylized glowing crystal plant, low-poly, gem-like translucent facets, soft pastel glow, Roblox game asset, isolated on plain white background"*.
- كمان منحتاج موديلات: التاجر، كشك البذور، 3 Pets.
- خزّن الملفات بـ `assets/` وسجلها بـ `assets/manifest.json`، وارفعها بـ Open Cloud Assets API.
- لازم يكون في Placeholder من Parts وNeon لكل شي ما إله assetId.

### التقنيات
- **Rojo** لتنظيم الكود (Luau)، والماب بينبني بالكود.
- **GitHub Actions:** build + publish بـ Open Cloud Place Publishing API عند كل push على `main`.
- **Secrets:** `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`, `ROBLOX_PLACE_ID`, `ROBLOX_CREATOR_ID`, `ROBLOX_CREATOR_TYPE`.

### المراحل
1. **MVP:** حديقة + زراعة + نمو offline + حصاد وبيع + متجر بذور + حفظ + نشر تلقائي.
2. **الطقس والطفرات.**
3. **التبادل الآمن والـ Pets.**
4. **Game Passes** (خانات إضافية، نمو أسرع) و**Developer Products** (بذرة نادرة، تغيير الطقس للسيرفر).

### متى بيكون الشغل خالص
- المشروع بينبني بـ `rojo build` بدون أخطاء.
- النمو offline محسوب صح.
- التبادل ما فيه أي طريقة للتكرار، حتى لو اللاعب طلع بنص التبادل.
- النشر التلقائي شغّال.
