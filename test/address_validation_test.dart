import 'package:flutter_test/flutter_test.dart';
import 'package:rehat_app/features/delivery/presentation/address_form_screen.dart';
import 'package:rehat_app/features/delivery/presentation/widgets/delivery_info_card.dart';

void main() {
  group('validateRecipientPhone', () {
    test('menerima format umum', () {
      expect(validateRecipientPhone('0812-3456-7890'), isNull);
      expect(validateRecipientPhone('+62 812 3456 7890'), isNull);
      expect(validateRecipientPhone('(021) 555 1234'), isNull);
    });
    test('menolak huruf, terlalu pendek/panjang', () {
      expect(validateRecipientPhone('0812abc45678'), isNotNull);
      expect(validateRecipientPhone('1234567'), isNotNull);
      expect(validateRecipientPhone('((((((((((a'), isNotNull);
      expect(validateRecipientPhone('1' * 26), isNotNull);
      expect(validateRecipientPhone('+-+-+-+-+-+-'), isNotNull);
      expect(validateRecipientPhone(null), isNotNull);
    });
  });

  group('waNumber', () {
    test('08xx -> 628xx', () => expect(waNumber('0812-345'), '62812345'));
    test('8xx -> 628xx', () => expect(waNumber('812345678'), '62812345678'));
    test('62xx tetap', () => expect(waNumber('+62 812 345'), '62812345'));
  });
}
