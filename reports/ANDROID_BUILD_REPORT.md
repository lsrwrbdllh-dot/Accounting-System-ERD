# نتيجة بناء Android الأول — سجل تاريخي

**هذه نتيجة إصدار سابق.** النسخة الأحدث اجتازت اختبار محاكي Android وتُنشر مباشرة بصيغة APK؛ راجع [تقرير الإصلاح والتثبيت](ANDROID_INSTALLATION_REPORT.md).

المستودع `lsrwrbdllh-dot/Accounting-System-ERD`، فرع `implementation/sqlite-flutter`.

**نجح البناء الفعلي** في [GitHub Actions رقم 43125494967](https://github.com/lsrwrbdllh-dot/Accounting-System-ERD/actions/runs/43125494967)، وانتهى التشغيل بنتيجة `success` عند `2026-11-12T00:18:26Z`.

Commit الكود المبني: `14501fd6d6649962c9c792a47ca9095d590e2823`. التحديث الذي يحفظ هذا التقرير يضيف سجلات البناء وملف الحزم الفعلي وتحديث الحالة في README فقط؛ لا يغيّر كود التطبيق الذي اجتاز البناء.

| العملية | النتيجة الفعلية |
|---|---|
| Flutter SDK | 3.38.0 stable على Ubuntu 24.04.5 |
| Dart | 3.10.0 كما ظهر في `flutter doctor -v` |
| Java | Temurin OpenJDK 17.0.21 |
| Android SDK المتاح في runner | 37.0.0؛ نزّل البناء NDK 28.2.13676358 وCMake 3.22.1 تلقائيًا |
| `flutter pub get` | نجاح؛ `app/pubspec.lock` محفوظ من نفس عملية البناء الناجحة |
| `flutter analyze` | `No issues found!`، خلال 12.0 ثانية |
| `flutter test` | **6 اختبارات ناجحة**، وانتهت بـ`All tests passed!` خلال نحو 19 ثانية |
| اختبارات SQLite على Actions | **58 اختبارًا ناجحًا** خلال 0.858 ثانية |
| `flutter build apk --debug --dart-define=APP_ENV=demo` | نجاح `assembleDebug` خلال 236.0 ثانية، وإنشاء `app-debug.apk` |
| التحقق من الملف | ملف غير فارغ، مع تسجيل SHA-256، ورفع Artifact فعلي |
| تشغيل التطبيق على Android | **لم ينفذ**؛ لم يوجد هاتف أو محاكي Android متصل |

`flutter doctor -v` رصد تحذيرًا عن بعض رخص Android ومكتبات تطوير سطح مكتب Linux غير المثبتة. لم تمنع هذه التحذيرات بناء Android؛ قبلت الأدوات رخص NDK وCMake المطلوبة أثناء البناء. الأجهزة التي ظهرت كانت Linux وChrome، وليست أجهزة Android.

## تنزيل APK والأدلة

- [تنزيل Artifact: android-debug-apk](https://github.com/lsrwrbdllh-dot/Accounting-System-ERD/actions/runs/43125494967/artifacts/13902967890) — حجم ZIP على GitHub نحو 73.2 MB. فك الضغط لتحصل على `app-debug.apk`. قد يلزم تسجيل الدخول إلى GitHub لتنزيل Artifact.
- [سجلات Flutter وملف الحزم والبصمة](https://github.com/lsrwrbdllh-dot/Accounting-System-ERD/actions/runs/43125494967/artifacts/13902043645).
- [نتائج SQLite](https://github.com/lsrwrbdllh-dot/Accounting-System-ERD/actions/runs/43125494967/artifacts/13903495388).
- صلاحية Artifacts المسجلة في GitHub حتى `2027-02-10`، ما لم تُحذف من المستودع.

SHA-256 لملف APK نفسه، وليس لملف ZIP:

```text
e22cef7710fcdec39c4ee8748246071b2ec3560791fb767d76751f720fec3f0b
```

النسخة Debug للتجربة، ببيانات منفصلة عن الإنتاج. تسجيل الدخول: `demo` / `Demo@2026!`.

## الإصلاحات التي تمت

1. إصلاح تمرير سطر فاتورة nullable إلى قائمة غير nullable.
2. تصحيح فحص `BuildContext.mounted` بعد العملية غير المتزامنة وإزالة interpolation غير ضروري.
3. تهيئة SQLite الحقيقية خارج الساعة الافتراضية لاختبار الواجهة، واستخدام FFI دون isolate في هذا الاختبار لمنع التعليق.
4. تجهيز CI بإصدار Flutter ثابت وJava 17، وفحص الأدوات، وسجلات منفصلة، وفشل صحيح للخطوات عبر `pipefail`، وحد زمني للاختبارات، ورفع APK والبصمة بعد النجاح.

لم تُغيّر المخططات المحاسبية أو SQL أو عمليات الترحيل، ولم تُضف وظائف محاسبية. بقي `main` عند `8bf595847791a6f4c03eda27ec2b711dad07e8a6` والفرع الاحتياطي `archive/frozen-c680a00` عند `04d3032330f3280b08115bf4c78395a2a396c2c8`.

## حدود التحقق والخطوة التالية

اختبارات Flutter نُفذت على Linux باستخدام SQLite الحقيقية عبر FFI، ومنها اختبار شاشة الدخول. لم يُنفذ اختبار التكامل `integration_test/persistence_test.dart` على Android، ولم يُختبر التثبيت أو قتل عملية Android وإعادة فتحها أو واجهات العمليات كاملة على الهاتف.

الخطوة التالية: تنزيل APK وتثبيته على هاتف Android، ثم اختبار الدخول وإضافة وتعديل وحفظ البيانات والترحيل وإعادة فتح التطبيق. نجاح البناء لا يثبت وحده صحة جميع العمليات على Android.

السجلات النصية الدائمة في هذا المستودع:

- [doctor](android-build/flutter-doctor.log)
- [pub get](android-build/flutter-pub-get.log)
- [analyze](android-build/flutter-analyze.log)
- [Flutter tests](android-build/flutter-test.log)
- [APK build](android-build/flutter-build.log)
- [APK checksum](android-build/app-debug.apk.sha256)
