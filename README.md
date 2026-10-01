# Steal a Pet Monster 🐾

لعبة روبلوكس من نوع **"اسرق ودافع"** (steal-and-defend tycoon). بتشتري وحوش لطيفة من السير المتحرك، وكل وحش بيطلعلك فلوس كل ثانية. بتقدر تسرق وحوش اللاعبين الثانيين وبتدافع عن قاعدتك بالقفل.

موديلات الوحوش معمولة بـ **Higgsfield**: بنولّد صورة، وبعدين بنحولها لموديل 3D بصيغة GLB. النشر على روبلوكس بيصير **تلقائيًا** بـ GitHub Actions.

أفكار الألعاب الثانية (برومبتات جاهزة) موجودة بمجلد [`ideas/`](ideas).

## طريقة اللعب
| الشي | كيف بيشتغل |
|---|---|
| السير المتحرك | كل 3 ثواني بيطلع وحش عشوائي. بتقرب منه وبتضغط **E** لتشتريه. |
| الدخل | كل وحش بقاعدتك بيجمّع فلوس. بتدوس على المربع الأخضر لتجمعها. |
| السرقة | بتفوت على قاعدة لاعب ثاني وبتضغط مطولًا على **Steal**، وبعدين بتركض لقاعدتك. إذا مسكك صاحب القاعدة أو متت، الوحش بيرجع لصاحبه. |
| القفل | الزر الأحمر بيقفل قاعدتك 60 ثانية وبيطرد أي حدا جوّاها، وبعدها في انتظار 30 ثانية. |
| البيع | بتضغط مطولًا على **F** على وحش عندك، وبترجعلك نص قيمته. |
| Rebirth | العمود الذهبي بيصفّر كل شي، وبيعطيك +50% دخل بشكل دائم. |
| الندرات | 7 ندرات من Common لـ Secret، ومعها طفرات: Gold ×2، Diamond ×3، Fire ×4، Rainbow ×10. |

## بنية المشروع
```
src/shared/     إعدادات اللعبة (Config, Monsters, Rarities, Mutations) → ReplicatedStorage.Shared
src/server/     السيرفر: بناء الماب، القواعد، السير، السرقة، حفظ البيانات → ServerScriptService
src/client/     الواجهة: الفلوس، الإشعارات، إظهار الـ prompts → StarterPlayerScripts
assets/         manifest.json: روابط موديلات Higgsfield والـ asset ids على روبلوكس
scripts/        upload_assets.py (رفع الموديلات) + install_tools.sh
.github/        ci.yml (فحص وبناء) + deploy.yml (رفع ونشر تلقائي)
```
كل الماب بينبني بالكود، يعني ما في ملفات `.rbxl` بالريبو.

## إعداد النشر التلقائي (مرة وحدة)
1. اعمل لعبة جديدة فاضية من [Creator Hub](https://create.roblox.com/dashboard/creations) وخذ منها:
   - **Universe ID**: هو رقم الـ Experience.
   - **Place ID**: هو رقم الـ Start Place.
2. اعمل **API Key** من [create.roblox.com/credentials](https://create.roblox.com/credentials) فيه:
   - `universe-places` → **write** على هاي اللعبة.
   - `asset` → **read + write**.
   - `game-pass` و `developer-product` → **read + write** (للمتجر).
   - بالـ IP: حط `0.0.0.0/0` لأن GitHub Actions ما إله IP ثابت.
3. بالريبو روح على **Settings → Secrets and variables → Actions** وضيف:
   | Secret | القيمة |
   |---|---|
   | `ROBLOX_API_KEY` | المفتاح |
   | `ROBLOX_UNIVERSE_ID` | رقم الـ Universe |
   | `ROBLOX_PLACE_ID` | رقم الـ Place |
   | `ROBLOX_CREATOR_ID` | رقم حسابك (أو رقم الـ Group إذا اللعبة لقروب) |
   | `ROBLOX_CREATOR_TYPE` | `User` أو `Group` |
4. من إعدادات اللعبة بالـ Creator Hub:
   - فعّل **Enable Studio Access to API Services** إذا بدك تجرب الحفظ من Studio.
   - خلّي **Max Players** يساوي **8** (عدد القواعد بالماب).
   - عبّي استبيان العمر (Maturity questionnaire).
   - خلّي اللعبة **Public**.

بعد هيك، **كل push على `main` بيعمل التالي:**
1. بيرفع أي موديل جديد بـ `assets/manifest.json` لروبلوكس.
2. بيسجل الـ asset id بالريبو.
3. بيبني اللعبة وبينشرها.

## إضافة وحش جديد بـ Higgsfield
1. ولّد صورة بالستايل الموحّد (موجود بـ `ideas/01-steal-a-pet-monster.md`).
2. حوّلها لموديل 3D بـ `tripo_h3_1_image_to_3d` مع `face_limit: 8000`.
3. ضيف الوحش لـ `src/shared/Monsters.luau`.
4. ضيف رابط الـ GLB لـ `assets/manifest.json` تحت `monsters.<Id>.model_url`.
5. اعمل push على `main`، والـ workflow بيكمّل الباقي.

## Game Passes و Developer Products
مصدر المتجر الوحيد هو ملف `assets/store.json`، وفيه الاسم والوصف والسعر والأيقونة والـ ID. الملف `src/shared/Monetization.luau` بيتولّد منه لحاله، فلا تعدّله بإيدك.

| النوع | المفتاح | الاسم | شو بيعمل | السعر |
|---|---|---|---|---|
| Pass | `DoubleCash` | 2x Cash | دخل مضاعف للأبد | 199 R$ |
| Pass | `SuperLock` | Super Lock | القفل دقيقتين وانتظار 15 ثانية بس | 149 R$ |
| Pass | `SpeedBoost` | Speed Boost | سرعة 22 بدل 16، وأسرع وإنت حامل وحش | 99 R$ |
| Pass | `AutoCollect` | Auto Collect | الدخل بيروح للفلوس مباشرة | 79 R$ |
| Product | `CashSmall` | Bag of Cash | دخل 5 دقائق، وأقل شي $5K | 25 R$ |
| Product | `CashLarge` | Chest of Cash | دخل ساعة، وأقل شي $100K | 149 R$ |
| Product | `LuckyEgg` | Lucky Egg | وحش عشوائي من ندرة Epic أو أعلى | 99 R$ |

**إنشاء العناصر تلقائيًا:** مع كل نشر، `scripts/setup_store.py` بيعمل التالي:
1. بيدوّر على أي عنصر ما إله `id`.
2. إذا في عنصر بنفس الاسم على روبلوكس، بياخذ رقمه وما بيعمل نسخة ثانية.
3. وإذا ما في، بيعمله عن طريق Open Cloud، مع السعر والأيقونة.
4. بيسجّل الأرقام بالريبو.

**شرط واحد:** لازم الـ API Key يكون فيه صلاحيات `game-pass` و`developer-product`، الاثنين **read + write**، على اللعبة.

**تعديل سعر أو اسم بعد الإنشاء:** بيصير من Creator Hub. السكربت ما بيعدّل عناصر موجودة.

**الحماية من التكرار:** رقم كل عملية شراء بيتسجل ببيانات اللاعب قبل ما نأكد الشراء لروبلوكس.

## أكواد التسويق (Redeem Codes)
زر **🎁 CODES** باللعبة بيفتح نافذة بيكتب فيها اللاعب الكود. الأكواد موجودة بـ `src/server/Codes.luau`، وهاد ملف على السيرفر بس، فاللاعبين ما بيقدروا يشوفوه.

روبلوكس ما بيسمح تعطي Game Pass حقيقي بكود. فالكود بيعطي **نفس ميزة الـ Pass** جوّا اللعبة، إما للأبد أو لعدد ساعات.

| الكود | المكافأة | الشروط |
|---|---|---|
| `RELEASE` | $10,000 + Lucky Egg | بيخلص بـ 1/11/2026 |
| `SPEEDY` | Speed Boost لـ 24 ساعة | بيخلص بـ 31/12/2026 |
| `DOUBLEUP` | 2x Cash لساعة | بيخلص بـ 31/12/2026 |
| `MONSTER100` | Auto Collect للأبد | لأول 100 لاعب بس |

- **حدود الاستخدام:** كل كود بينستخدم مرة وحدة لكل لاعب. `MaxRedemptions` بيحدد عدد الاستخدامات الكلي على كل السيرفرات، وبينحسب بـ DataStore.
- **الميزة المؤقتة:** بتخلص لحالها، وبتطلع للاعب رسالة "اشتريها للأبد من المتجر". إذا اللاعب اشترى الـ Pass الحقيقي، الميزة ما بتنشال عنه أبدًا.
- **إضافة كود جديد:** ضيف سطر بـ `Codes.luau` واعمل push على `main`، وبينتشر لحاله.

## الأيقونة وصورة الغلاف
معمولين بـ Higgsfield، وروابطهم موجودة بـ `assets/manifest.json` تحت `branding`.

بترفعهم مرة وحدة بإيدك من **Creator Hub ← اللعبة ← Places ← Start Place**:
- **Icon**: الصورة المربعة.
- **Thumbnails**: الصورة العريضة 16:9.

## التطوير المحلي
```bash
rokit install           # بينزّل rojo و selene
rojo serve              # وبعدين Connect من إضافة Rojo داخل Studio
selene src              # فحص الكود
rojo build -o place.rbxl
```
