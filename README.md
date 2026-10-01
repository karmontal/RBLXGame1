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

## التطوير المحلي
```bash
rokit install           # بينزّل rojo و selene
rojo serve              # وبعدين Connect من إضافة Rojo داخل Studio
selene src              # فحص الكود
rojo build -o place.rbxl
```
