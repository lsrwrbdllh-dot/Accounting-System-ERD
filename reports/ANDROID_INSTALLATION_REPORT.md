# تقرير إصلاح التثبيت وتشغيل Android — 2026-11-12

المستودع: `lsrwrbdllh-dot/Accounting-System-ERD`، الفرع: `implementation/sqlite-flutter`.
Commit التطبيق: `d679c1efdec73eed7e104103eccdb23187e049dc`.

حالة التحقق: نجاح جميع الوظائف الأربع: SQLite وFlutter وAndroid والنشر. [عملية التحقق الفعلية](https://github.com/lsrwrbdllh-dot/Accounting-System-ERD/actions/runs/43297879442).

## التنزيل والتثبيت

[تنزيل APK مباشرة](https://github.com/lsrwrbdllh-dot/Accounting-System-ERD/releases/download/android-preview-15-d679c1efdec73eed7e104103eccdb23187e049dc/Accounting-System-Android.apk) — [صفحة الإصدار](https://github.com/lsrwrbdllh-dot/Accounting-System-ERD/releases/tag/android-preview-15-d679c1efdec73eed7e104103eccdb23187e049dc).

نزّل ملف `Accounting-System-Android.apk` نفسه وافتحه على Android. اسم التطبيق «النظام المحاسبي - تجربة». اسم الحزمة `com.accounting.system.preview` منفصل عن النسخ السابقة؛ لا تحتاج حذفها أو حذف بياناتها. عند طلب Android، اسمح بالتثبيت من التطبيق الذي فتحت منه الملف. لا تغيّر امتداد ZIP إلى APK.

الدخول التجريبي: `demo` / `Demo@2026!`. هذه نسخة بيانات تجربة منفصلة عن الإنتاج. الإصدار `1.0.1-preview`، رقم البناء `2`، والحد الأدنى الفعلي Android 7 / API 24 كما تحقق `aapt`. رفع Flutter 3.38 الحد أثناء البناء من القيمة 23 الموجودة في ملف Gradle المصدر؛ أجهزة API 23 لا تدعم هذا APK.

## نتائج التحقق

| العملية | النتيجة الفعلية |
|---|---|
| Flutter / Dart / Java | 3.38.0 / 3.10.0 / JDK 17 |
| `flutter pub get` | نجاح؛ ملف الحزم مطابق للمحفوظ في Git |
| `flutter analyze` | `No issues found!` |
| `flutter test` | 8 اختبارات ناجحة |
| اختبارات SQLite | 58 ناجحة، دون فشل أو تخطٍّ |
| اختبارا Android باستخدام sqflite | نجاح القراءة والتعديل والترحيل وإعادة فتح القاعدة؛ ونجاح الدخول عبر الواجهة وحفظ المشتريات وترحيلها وعرض المخزون |
| بناء Debug | نجاح |
| بناء Release | نجاح؛ APK فعلي 50,738,282 بايت (نحو 50.7 MB) |
| ABI | ARM64 وARMv7 وx86_64 |
| التوقيع | فحص `apksigner`: نجاح، توقيع v2 بشهادة Android Debug؛ نسخة Preview |
| التثبيت | `adb install -r` أعاد `Success` دون `-t` |
| التشغيل وإيقاف العملية ثم إعادة إطلاقها | `Status: ok` في المرتين؛ دون سجل انهيار أو علامة فشل بدء SQLite |
| فحص لقطة الشاشة | ظهرت شاشة الدخول العربية بعد إعادة التشغيل |

بصمة SHA-256 لملف APK:

```text
a419ab5d1260e30226636d5b7abe391ef040762b525d5b6e0bd592b3524dbc0a
```

السجلات النصية الدائمة: [التحقق الموحد](android-preview/verification.json)، [التحليل](android-preview/flutter-analyze.log)، [اختبارات Flutter](android-preview/flutter-test.log)، [SQLite](android-preview/sqlite-tests.log)، [اختبارات Android](android-preview/native-integration.log)، [التوقيع](android-preview/signature.txt)، [معلومات APK](android-preview/apk-info.txt)، [التثبيت](android-preview/install.txt)، [التشغيل](android-preview/launch.txt)، [إعادة التشغيل](android-preview/relaunch.txt).

[أدلة Android الأصلية ولقطة الشاشة](https://github.com/lsrwrbdllh-dot/Accounting-System-ERD/actions/runs/43297879442/artifacts/13981401087). طابقت بصمة APK المحمّل محليًا بصمة ناتج اختبار Android وبصمة الملف المنشور التي تسجلها GitHub؛ ليس ملفًا وهميًا أو ZIP غُيّر امتداده.

## العوائق والإصلاحات المثبتة

- فشل نشر APK السابق داخل Git لأن حجمه 144.90 MB يتجاوز حد الملف 100 MB. أصبح التوزيع عن طريق GitHub Releases، مع منع النشر إذا فشلت الاختبارات أو التثبيت والتشغيل.
- عالج التحديث السابق استدعاء `PRAGMA busy_timeout` عبر `execute`، الذي كان يمنع فتح SQLite على Android. بقي هذا الإصلاح محفوظًا.
- كشف اختبار واجهة Android إعادة `Future` من callback داخل `setState` عند الرجوع للرئيسية. أُصلح تحديث الملخص، وكذلك callback إعادة محاولة بدء التشغيل.
- كشف اختبار إضافة صنف تحرير `TextEditingController` أثناء بقاء نافذته في حركة الإغلاق. تنتظر النوافذ الآن إزالة مسارها قبل تحرير الحقول، وشمل التصحيح الفواتير والمرتجعات والسندات والأدلة والوحدات.
- أضيف اختبار لحفظ مسودة مشتريات فعلية، واختبار للرجوع إلى الرئيسية، مع انتظار استقرار التمرير في الاختبارات قبل الضغط.
- استُبدل الاعتماد على أداة البحث غير المثبتة في runner بأدوات النظام القياسية لفحص SDK والحزمة والسجل.
- تتحقق CI من توقيع APK، ووجود ARM64، ومن أن الملف غير `debuggable` وغير `testOnly`، ثم تثبته باستخدام `adb install -r` دون السماح الخاص بحزم الاختبار `-t`.

لا يتوفر رابط المستودع المشتق الذي اختبره المستخدم أو نص خطأ التثبيت على Redmi 12؛ لذلك لم تُنسب المشكلة على هاتفه إلى سبب محدد دون دليل. التحقق أعلاه يخص النسخة المبنية من المستودع الأصلي.

## حدود النسخة والحفظ

هذه نسخة Preview مبنية بوضع Release وموقعة بمفتاح اختبار؛ ليست توقيع إنتاج دائمًا. مفاتيح runners قد تختلف بين عمليات البناء، لذا تحديث Preview من بناء مستقل لاحق لا يُضمن قبل إعداد مفتاح مملوك محفوظ في GitHub Secrets. لا يُحفظ مفتاح خاص في Git. لا تحذف تطبيقًا يحتوي بيانات مالية لحل تعارض توقيع؛ يلزم نسخ بياناته أولًا ومسار تحديث مناسب.

التشغيل الفعلي الموثق هنا على محاكي Android 13 / API 33 في GitHub Actions؛ لم يُجرّب على هاتف Redmi 12 حقيقي. وجود مكتبة ARM64 في APK مُتحقق منه، لكنه لا يعادل تشغيله على الهاتف. اختبار البيانات يفتح SQLite ويغلقها ويعيد فتحها؛ اختبار إيقاف عملية APK وإطلاقها يفحص بدء التشغيل، ولا يفحص فاتورة محفوظة بين عمليتين منفصلتين. اختبار الواجهة يغطي مسار مشتريات واحدًا، وليس كل الشاشات والعمليات يدويًا.

لم تتغير مخططات ERD00–12 أو SQL أو المنطق المحاسبي في هذه الإصلاحات. حُفظت التعديلات بالرفع الآمن دون force. بقي `main` عند `8bf595847791a6f4c03eda27ec2b711dad07e8a6`، والفرع المجمد `archive/frozen-c680a00` عند `04d3032330f3280b08115bf4c78395a2a396c2c8`.

النتائج الأقدم في [تقرير البناء الأول](ANDROID_BUILD_REPORT.md) تخص إصدارًا سابقًا؛ التقرير الحالي هو مرجع النسخة القابلة للتنزيل أعلاه.
