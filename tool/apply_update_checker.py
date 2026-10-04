from pathlib import Path

MAIN = Path('lib/main.dart')
s = MAIN.read_text()

if "import 'update_service.dart';" not in s:
    s = s.replace(
        "import 'package:url_launcher/url_launcher.dart';",
        "import 'package:url_launcher/url_launcher.dart';\nimport 'update_service.dart';",
        1,
    )

old_load = '''  Future<void> _load() async {
    await db.load();
    if (mounted) setState(() => loading = false);
  }'''
new_load = '''  Future<void> _load() async {
    await db.load();
    if (!mounted) return;
    setState(() => loading = false);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) showUpdateCheck(context, silent: true);
    });
  }

  Future<void> checkForUpdateNow() async {
    if (!mounted) return;
    await showUpdateCheck(context);
  }'''
s = s.replace(old_load, new_load, 1)

old_home = """                IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())), icon: const Icon(Icons.settings_outlined)),
                IconButton(onPressed: () => showAbout(context), icon: const Icon(Icons.info_outline_rounded)),"""
new_home = """                IconButton(onPressed: () => showUpdateCheck(context), icon: const Icon(Icons.notifications_none_rounded)),
                IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())), icon: const Icon(Icons.settings_outlined)),"""
s = s.replace(old_home, new_home, 1)

new_settings = r'''Future<void> showUpdateCheck(BuildContext context, {bool silent = false}) async {
  if (!silent) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(color: primary),
          SizedBox(width: 18),
          Expanded(child: Text('Checking for updates...')),
        ]),
      ),
    );
  }

  final info = await UpdateService.check();
  if (!context.mounted) return;
  if (!silent) Navigator.of(context).pop();

  if (info == null) {
    if (!silent) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Check'),
          content: const Text('Could not connect to PaliaAPK HUB. Please try again later.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
    return;
  }

  if (!info.isNewer) {
    if (!silent) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('You are up to date'),
          content: Text('RentFlow $rentFlowCurrentVersion is the latest version.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: !info.forceUpdate,
    builder: (context) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.system_update_rounded, color: primary),
        SizedBox(width: 10),
        Expanded(child: Text('Update available')),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RentFlow ${info.version} is available.', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(info.releaseNotes),
          const SizedBox(height: 10),
          const Text('Open PaliaAPK HUB to download the latest APK.', style: TextStyle(color: muted)),
        ],
      ),
      actions: [
        if (!info.forceUpdate)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
        FilledButton.icon(
          onPressed: () async {
            await UpdateService.openUpdate(info);
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.download_rounded),
          label: const Text('Update Now'),
        ),
      ],
    ),
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> openWebsite(BuildContext context) async {
    final uri = Uri.parse(websiteUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open website')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: mint,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                const Brand(size: 64),
                const SizedBox(width: 16),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RentFlow', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    Text('By PaliaAPK HUB', style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
                    Text('Developer by ShanPalia', style: TextStyle(color: muted)),
                  ],
                )),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.system_update_rounded, color: primary),
                title: const Text('Check for App Update', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Check PaliaAPK HUB for a newer RentFlow APK'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showUpdateCheck(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language_rounded, color: primary),
                title: const Text('PaliaAPK HUB Website', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Open website'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openWebsite(context),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const Center(child: Text('RentFlow 1.0.0', style: TextStyle(color: muted))),
          const SizedBox(height: 4),
          const Center(child: Text('By PaliaAPK HUB • Developer by ShanPalia', style: TextStyle(color: muted))),
        ],
      ),
    );
  }
}
'''

start = s.find('class SettingsPage extends StatelessWidget {')
end = s.find('void showAbout(BuildContext context) {')
if start == -1 or end == -1:
    raise SystemExit('Could not locate SettingsPage boundaries')
s = s[:start] + new_settings + '\n' + s[end:]

MAIN.write_text(s)
print('RentFlow update checker applied successfully.')
