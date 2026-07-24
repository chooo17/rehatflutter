import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/neu.dart';

/// (Admin) Generate QR code per meja. Scan → buka web app dgn `?table=N`,
/// pesanan otomatis dine-in + nomor meja ikut ke kasir/struk.
/// Cetak halaman ini (screenshot / print browser) lalu tempel di tiap meja.
class AdminQrTablesScreen extends StatefulWidget {
  const AdminQrTablesScreen({super.key});

  @override
  State<AdminQrTablesScreen> createState() => _AdminQrTablesScreenState();
}

class _AdminQrTablesScreenState extends State<AdminQrTablesScreen> {
  int _count = 10;

  String _url(int table) => '${ApiConstants.webAppUrl}/?table=$table';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Meja')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'QR untuk tiap meja. Pelanggan scan → buka menu, pesanan otomatis '
            'dine-in dengan nomor mejanya. Cetak & tempel di meja.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Jumlah meja', style: AppTextStyles.bodyMedium),
              const Spacer(),
              _StepBtn(
                  icon: Icons.remove_rounded,
                  onTap: _count > 1 ? () => setState(() => _count--) : null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('$_count', style: AppTextStyles.titleLarge),
              ),
              _StepBtn(
                  icon: Icons.add_rounded,
                  onTap: _count < 60 ? () => setState(() => _count++) : null),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: _count,
            itemBuilder: (_, i) => _TableQr(table: i + 1, url: _url(i + 1)),
          ),
        ],
      ),
    );
  }
}

class _TableQr extends StatelessWidget {
  const _TableQr({required this.table, required this.url});
  final int table;
  final String url;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Meja $table',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.amberDark)),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Link meja $table disalin')));
            },
            child: Text('Salin link',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NeuButton(
      onPressed: onTap,
      padding: const EdgeInsets.all(8),
      minSize: 44,
      child: Icon(icon, size: 20, color: AppColors.textPrimary),
    );
  }
}
