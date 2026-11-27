import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/order_model.dart';

/// Nomor 08xx -> 628xx untuk link wa.me.
String waNumber(String phone) {
  final d = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return d.startsWith('0') ? '62${d.substring(1)}' : d;
}

class DeliveryInfoCard extends StatelessWidget {
  const DeliveryInfoCard({super.key, required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final a = order.deliveryAddress;
    final s = order.deliveryStatus;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(s?.icon ?? Icons.delivery_dining_rounded, color: AppColors.amberDark),
              const SizedBox(width: 8),
              Text(s?.label ?? 'Menunggu pembayaran', style: AppTextStyles.titleMedium),
            ]),
            if (order.courierName != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text('Kurir: ${order.courierName}', style: AppTextStyles.bodyMedium)),
                if (order.courierPhone != null) ...[
                  IconButton(
                    tooltip: 'Telepon kurir',
                    icon: const Icon(Icons.call_rounded),
                    onPressed: () => launchUrl(Uri.parse('tel:${order.courierPhone}')),
                  ),
                  IconButton(
                    tooltip: 'WhatsApp kurir',
                    icon: const Icon(Icons.chat_rounded),
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/${waNumber(order.courierPhone!)}'),
                        mode: LaunchMode.externalApplication),
                  ),
                ],
              ]),
            ],
            if (a != null) ...[
              const Divider(height: 20),
              Text('Diantar ke ${a.label}', style: AppTextStyles.label),
              Text(a.addressText, style: AppTextStyles.bodyMedium),
              if (a.notes != null) Text(a.notes!, style: AppTextStyles.bodySmall),
              Text('${a.recipientName} • ${a.recipientPhone}', style: AppTextStyles.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
