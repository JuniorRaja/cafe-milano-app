import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/database_provider.dart';
import '../../../services/backup_service.dart';
import '../../../widgets/ui/ui.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await exportAndShareBackup(ref.read(databaseProvider));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not export backup: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    final confirmed = await confirmDestructive(
      context,
      title: 'Restore backup?',
      message: 'This will permanently erase all current data on this device '
          'and replace it with the contents of the selected backup.',
      detail: 'Shops, products, prices, orders and business info. This cannot '
          'be undone.',
      confirmLabel: 'Erase & Restore',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await importBackup(ref.read(databaseProvider), File(path));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore complete'),
          content: const Text(
            'Your data has been restored. Please close and reopen the app '
            'to make sure everything is refreshed.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore failed'),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Backup & Restore',
      caption: 'Keep your data safe',
      background: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s6,
        ),
        children: [
          _ActionTile(
            icon: Icons.upload_outlined,
            title: 'Export Backup',
            subtitle:
                'Save all shops, products, prices, orders, business info and '
                'photos to a file you can store safely (e.g. Google Drive, '
                'email)',
            onTap: _busy ? null : _export,
          ),
          const SizedBox(height: AppSpace.s3),
          _ActionTile(
            icon: Icons.download_outlined,
            title: 'Import Backup',
            subtitle:
                'Restore from a previously exported backup file. This erases '
                'current data on this device.',
            onTap: _busy ? null : _import,
          ),
          if (_busy) ...[
            const SizedBox(height: AppSpace.s5),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppRadius.rS,
          ),
          child: Icon(icon, color: AppColors.brandDeep, size: 20),
        ),
        title: Text(title, style: AppType.titleS),
        subtitle: Text(
          subtitle,
          style: AppType.bodyS.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
