import 'package:flutter/material.dart';

import '../data/store.dart';
import '../fa.dart';
import '../services/reminders.dart';
import '../theme.dart';
import 'assessment.dart';
import 'guide.dart';

class SettingsScreen extends StatefulWidget {
  final AppState app;
  const SettingsScreen({super.key, required this.app});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppState get app => widget.app;

  Future<void> _applyReminder() async {
    try {
      if (app.reminderOn) {
        await Reminders.schedule(app.reminderHour, app.reminderMinute);
      } else {
        await Reminders.cancel();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تنظیم یادآوری ممکن نشد.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('تنظیمات', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('زمان مکث پیش از هر عبارت', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text('${faNum(app.waitTarget, 1)} ثانیه', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
              Slider(
                value: app.waitTarget,
                min: AppState.minWait,
                max: AppState.maxWait,
                divisions: 11,
                onChanged: (v) => setState(() => app.waitTarget = double.parse(v.toStringAsFixed(1))),
                onChangeEnd: (_) => app.save(),
              ),
              const Text('اپ بعد از سه جلسه‌ی موفق پشت سر هم، این زمان را ۰٫۲ ثانیه کم می‌کند. اگر گفتاردرمانگرت عدد دیگری گفته، همین‌جا تنظیمش کن.',
                  style: TextStyle(fontSize: 12, height: 1.7, color: C.muted)),
            ]),
          ),
          if (Reminders.supported) const SizedBox(height: 12),
          if (Reminders.supported) AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('یادآوری روزانه', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                value: app.reminderOn,
                onChanged: (v) async {
                  setState(() => app.reminderOn = v);
                  await app.save();
                  await _applyReminder();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: app.reminderOn,
                title: const Text('ساعت یادآوری'),
                trailing: Text(faTime(app.reminderHour, app.reminderMinute),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                onTap: () async {
                  final t = await showTimePicker(
                      context: context, initialTime: TimeOfDay(hour: app.reminderHour, minute: app.reminderMinute));
                  if (t == null) return;
                  setState(() {
                    app.reminderHour = t.hour;
                    app.reminderMinute = t.minute;
                  });
                  await app.save();
                  await _applyReminder();
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('با گفتاردرمانگر کار می‌کنم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                subtitle: const Text('زمان مکث و تکنیک‌ها را طبق نظر درمانگر تنظیم کن'),
                value: app.withTherapist,
                onChanged: (v) async {
                  setState(() => app.withTherapist = v);
                  await app.save();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('حالت کودک', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                subtitle: const Text('متن‌های کودکانه و پرسش‌ها خطاب به والدین'),
                value: app.forChild,
                onChanged: (v) async {
                  setState(() => app.forChild = v);
                  await app.save();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline, color: C.brandDark),
                title: const Text('راهنمای روش‌ها'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GuideScreen())),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.refresh, color: C.brandDark),
                title: const Text('تکرار ارزیابی اولیه'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AssessmentFlow(app: app))),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline, color: C.warn),
                title: const Text('پاک کردن همه‌ی داده‌ها', style: TextStyle(color: C.warn)),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('همه‌ی داده‌ها پاک شود؟'),
                      content: const Text('جلسه‌ها، ارزیابی و تنظیمات از این گوشی حذف می‌شوند.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('پاک کن')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await app.reset();
                    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(
            'گفتارین ابزار تمرین است و جایگزین تشخیص یا درمان گفتاردرمانگر نیست. همه‌ی داده‌ها فقط روی همین گوشی ذخیره می‌شوند و صدا ضبط یا ارسال نمی‌شود.',
            style: TextStyle(fontSize: 12, height: 1.8, color: C.muted),
          ),
          const SizedBox(height: 8),
          const Text('نسخه‌ی ۰٫۲ · آزمایشی · متن‌ها در حال بازبینی گفتاردرمانگر', style: TextStyle(fontSize: 12, color: C.muted)),
        ],
      ),
    );
  }
}
