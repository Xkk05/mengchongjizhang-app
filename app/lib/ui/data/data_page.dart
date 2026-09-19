import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/csv/ledger_csv.dart';
import '../../state/providers.dart';
import '../common/app_card.dart';

/// 数据管理：账单的 CSV 导出 / 导入。
///
/// 导出走系统分享（写临时文件再 Share），导入走系统选文件 + 预览确认，
/// 页面本身不碰解析逻辑 —— 解析与去重都在领域层 / 仓库层，这里只管交互。
class DataPage extends ConsumerStatefulWidget {
  const DataPage({super.key});

  @override
  ConsumerState<DataPage> createState() => _DataPageState();
}

class _DataPageState extends ConsumerState<DataPage> {
  bool _busy = false;

  LedgerRepository get _repo => ref.read(ledgerRepositoryProvider);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------------ 导出

  Future<void> _exportFile() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final rows = await _repo.exportRows();
      if (rows.isEmpty) {
        _toast('还没有账目可以导出');
        return;
      }
      final text = LedgerCsv.encode(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${LedgerCsv.fileName(DateTime.now())}');
      await file.writeAsString(text, flush: true);
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: '随心宠记账 · 账单导出',
        ),
      );
      _toast('已导出 ${rows.length} 笔账单');
    } catch (e) {
      _toast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyToClipboard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final rows = await _repo.exportRows();
      if (rows.isEmpty) {
        _toast('还没有账目可以导出');
        return;
      }
      await Clipboard.setData(ClipboardData(text: LedgerCsv.encode(rows)));
      _toast('已复制 ${rows.length} 笔账单到剪贴板');
    } catch (e) {
      _toast('复制失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------ 导入

  Future<void> _pickAndImport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: '选择账单 CSV',
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
      );
      if (!mounted || picked == null) return; // 用户取消

      // readAsBytes 在 file / content / blob 各来源上都能拿到内容。
      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      // allowMalformed：第三方导出的 CSV 偶尔混入非 UTF-8 字节，别因此整份丢弃。
      final parsed = LedgerCsv.parse(utf8.decode(bytes, allowMalformed: true));
      if (!parsed.hasContent) {
        _toast('文件里没有可识别的账单数据');
        return;
      }

      final preview = await _repo.previewImport(parsed);
      if (!mounted) return;

      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
        builder: (_) =>
            ImportPreviewSheet(preview: preview, fileName: picked.name),
      );
      if (confirmed != true || !mounted) return;

      final outcome = await _repo.importRows(parsed);
      final parts = <String>['新增 ${outcome.inserted} 笔'];
      if (outcome.duplicates > 0) parts.add('跳过重复 ${outcome.duplicates} 笔');
      if (outcome.newCategories > 0) parts.add('新建分类 ${outcome.newCategories} 个');
      if (outcome.newAccounts > 0) parts.add('新建账户 ${outcome.newAccounts} 个');
      _toast('导入完成 · ${parts.join('，')}');
    } catch (e) {
      _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        title: const Text('数据管理'),
        backgroundColor: c.pageBg,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
            children: [
              _SectionCard(
                icon: Icons.ios_share_rounded,
                color: c.mint,
                title: '导出账单',
                desc: '把全部流水导出为 CSV：Excel 能直接打开，也可以分享给别人备份。',
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _exportFile,
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text('导出 CSV 文件'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    OutlinedButton(
                      onPressed: _busy ? null : _copyToClipboard,
                      child: const Text('复制'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SectionCard(
                icon: Icons.file_download_outlined,
                color: c.coral,
                title: '导入账单',
                desc: '选择 CSV 文件导入历史账单。导完会先给你看一份预览，确认后才写库。',
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : _pickAndImport,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('选择 CSV 文件'),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates_outlined,
                            size: 16, color: c.ink3),
                        const SizedBox(width: 6),
                        Text(
                          '导入规则',
                          style: TextStyle(
                            fontSize: AppFontSizes.md,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _bullet(c, '重复的记录会自动跳过，重复导入同一个文件不会产生副本。'),
                    _bullet(c, '文件里出现本 App 没有的分类 / 账户时会自动新建，预览里会先列出来。'),
                    _bullet(c, '识别不了的行会被跳过并标注行号，不影响其余行导入。'),
                    _bullet(c, '导入的历史账单不计入宠物成长（不发经验与金币）。'),
                    const SizedBox(height: 6),
                    Text(
                      '支持的列：日期、类型、分类、账户、金额、备注（表头可用常见别名，如「交易时间 / 收支 / 支付方式」）。',
                      style: TextStyle(
                        fontSize: AppFontSizes.sm,
                        color: c.ink3,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2.5),
            ),
        ],
      ),
    );
  }

  Widget _bullet(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: c.ink3,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: AppFontSizes.sm,
                  color: c.ink2,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
}

/// 带图标标题 + 说明 + 操作区的一张卡。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftIcon(icon: icon, color: color, size: 36, iconSize: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppFontSizes.lg,
                    fontWeight: FontWeight.w800,
                    color: c.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            desc,
            style: TextStyle(
              fontSize: AppFontSizes.sm,
              color: c.ink3,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// 导入预览：把「将发生什么」摊开给用户看，确认后才真正写库。
///
/// 公开而非私有 —— 预览是这条路里信息量最大的一屏，值得单独挂测试。
class ImportPreviewSheet extends StatelessWidget {
  const ImportPreviewSheet({
    super.key,
    required this.preview,
    required this.fileName,
  });

  final ImportPreview preview;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxH = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导入预览',
                    style: TextStyle(
                      fontSize: AppFontSizes.xl,
                      fontWeight: FontWeight.w800,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      label: '可导入',
                      value: '${preview.importable} 笔',
                      color: c.mintText,
                    ),
                    _StatRow(
                      label: '跳过重复',
                      value: '${preview.duplicates} 笔',
                      color: c.ink3,
                    ),
                    _StatRow(
                      label: '异常行',
                      value: '${preview.errors.length} 行',
                      color: preview.errors.isEmpty ? c.ink3 : c.coralText,
                    ),
                    if (preview.newExpenseCategories.isNotEmpty ||
                        preview.newIncomeCategories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _ChipLine(
                        label: '将新建分类',
                        names: [
                          ...preview.newExpenseCategories,
                          ...preview.newIncomeCategories,
                        ],
                        color: c.coral,
                      ),
                    ],
                    if (preview.newAccounts.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _ChipLine(
                        label: '将新建账户',
                        names: preview.newAccounts,
                        color: c.mint,
                      ),
                    ],
                    if (preview.errors.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '异常行（已跳过）',
                        style: TextStyle(
                          fontSize: AppFontSizes.md,
                          fontWeight: FontWeight.w700,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final e in preview.errors.take(8))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '· ${e.toString()}',
                            style: TextStyle(
                              fontSize: AppFontSizes.sm,
                              color: c.ink3,
                              height: 1.4,
                            ),
                          ),
                        ),
                      if (preview.errors.length > 8)
                        Text(
                          '… 还有 ${preview.errors.length - 8} 行',
                          style:
                              TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
                        ),
                    ],
                    if (preview.importable == 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        preview.duplicates > 0
                            ? '这些记录都已经存在，无需重复导入。'
                            : '文件里没有可导入的记录。',
                        style: TextStyle(
                          fontSize: AppFontSizes.sm,
                          color: c.ink3,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: c.border),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: preview.importable == 0
                          ? null
                          : () => Navigator.of(context).pop(true),
                      child: Text('确认导入 ${preview.importable} 笔'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: AppFontSizes.md, color: c.ink2),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: AppFontSizes.md,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipLine extends StatelessWidget {
  const _ChipLine({
    required this.label,
    required this.names,
    required this.color,
  });

  final String label;
  final List<String> names;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: AppFontSizes.sm, color: c.ink3),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final n in names)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  n,
                  style: TextStyle(
                    fontSize: AppFontSizes.sm,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
