/// Label Bahasa Indonesia untuk opsi kustomisasi menu
/// (nilai mentah dari backend: 'small'|'regular'|'large', 'hot'|'iced', 0-100).
class CustomizationLabels {
  CustomizationLabels._();

  static String size(String? value) {
    switch (value) {
      case 'small':
        return 'Small';
      case 'regular':
        return 'Reguler';
      case 'large':
        return 'Large';
      default:
        return value ?? '';
    }
  }

  static String temperature(String? value) {
    switch (value) {
      case 'hot':
        return 'Panas';
      case 'iced':
        return 'Dingin';
      default:
        return value ?? '';
    }
  }

  static String sugar(int? value) {
    if (value == null) return '';
    if (value == 0) return 'Tanpa gula';
    return 'Gula $value%';
  }

  /// Ringkasan satu baris, mis. "Reguler · Dingin · Gula 50%".
  static String summary({String? size, int? sugarLevel, String? temperature}) {
    final parts = <String>[
      if (size != null && size.isNotEmpty) CustomizationLabels.size(size),
      if (temperature != null && temperature.isNotEmpty)
        CustomizationLabels.temperature(temperature),
      if (sugarLevel != null) CustomizationLabels.sugar(sugarLevel),
    ];
    return parts.join(' · ');
  }
}
