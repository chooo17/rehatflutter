// lib/features/delivery/data/delivery_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/delivery_models.dart';

class DeliveryRepository {
  DeliveryRepository({required DioClient client}) : _client = client;
  final DioClient _client;

  Map<String, dynamic> _map(dynamic body) {
    final inner = body is Map ? body['data'] : null;
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return body is Map ? Map<String, dynamic>.from(body) : const {};
  }

  List<Map<String, dynamic>> _list(dynamic body) {
    final inner = body is Map ? body['data'] : body;
    return inner is List
        ? inner.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
  }

  // Pelanggan ----------------------------------------------------------
  Future<DeliveryConfig> fetchConfig() async =>
      DeliveryConfig.fromJson(_map((await _client.get<dynamic>(ApiConstants.deliveryConfig)).data));

  Future<DeliveryQuote> quote({required String addressId, required int itemsNet}) async {
    final res = await _client.post<dynamic>(ApiConstants.deliveryQuote,
        data: {'address_id': addressId, 'items_net': itemsNet < 0 ? 0 : itemsNet});
    return DeliveryQuote.fromJson(_map(res.data));
  }

  Future<List<AddressModel>> fetchAddresses() async =>
      _list((await _client.get<dynamic>(ApiConstants.myAddresses)).data).map(AddressModel.fromJson).toList();

  Future<AddressModel> createAddress(AddressModel a) async =>
      AddressModel.fromJson(_map((await _client.post<dynamic>(ApiConstants.myAddresses, data: a.toJson())).data));

  Future<AddressModel> updateAddress(String id, AddressModel a) async =>
      AddressModel.fromJson(_map((await _client.patch<dynamic>(ApiConstants.myAddress(id), data: a.toJson())).data));

  Future<void> deleteAddress(String id) => _client.delete<dynamic>(ApiConstants.myAddress(id));

  // Kurir --------------------------------------------------------------
  Future<CourierDeliveries> fetchCourierDeliveries() async =>
      CourierDeliveries.fromJson(_map((await _client.get<dynamic>(ApiConstants.courierDeliveries)).data));

  Future<void> setDuty(bool onDuty) => _client.patch<dynamic>(ApiConstants.courierDuty, data: {'on_duty': onDuty});

  Future<void> claim(String orderId) => _client.post<dynamic>(ApiConstants.courierAction(orderId, 'claim'));
  Future<void> markOnTheWay(String orderId) => _client.post<dynamic>(ApiConstants.courierAction(orderId, 'on-the-way'));
  Future<void> markDelivered(String orderId) => _client.post<dynamic>(ApiConstants.courierAction(orderId, 'delivered'));
  Future<void> markFailed(String orderId, String reason) =>
      _client.post<dynamic>(ApiConstants.courierAction(orderId, 'failed'), data: {'reason': reason});

  // Admin --------------------------------------------------------------
  Future<(StoreSettings, List<StoreHour>)> fetchStoreSettings() async {
    final data = _map((await _client.get<dynamic>(ApiConstants.adminStoreSettings)).data);
    final s = data['settings'] is Map ? Map<String, dynamic>.from(data['settings']) : <String, dynamic>{};
    final hours = (data['hours'] is List ? data['hours'] as List : const [])
        .whereType<Map>()
        .map((e) => StoreHour.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    return (StoreSettings.fromJson(s), hours);
  }

  Future<void> updateStoreSettings(StoreSettings s) =>
      _client.patch<dynamic>(ApiConstants.adminStoreSettings, data: s.toJson());

  Future<void> saveStoreHours(List<StoreHour> hours) =>
      _client.put<dynamic>(ApiConstants.adminStoreHours, data: [for (final h in hours) h.toJson()]);

  Future<List<CourierInfo>> fetchCouriers() async =>
      _list((await _client.get<dynamic>(ApiConstants.adminCouriers)).data).map(CourierInfo.fromJson).toList();

  Future<void> addCourier(String phone) => _client.post<dynamic>(ApiConstants.adminCouriers, data: {'phone': phone});
  Future<void> removeCourier(String id) => _client.delete<dynamic>(ApiConstants.adminCourier(id));

  Future<void> assignCourier(String orderId, String courierId) =>
      _client.post<dynamic>(ApiConstants.adminAssignCourier(orderId), data: {'courier_id': courierId});

  Future<void> refundDelivery(String orderId, String reason) =>
      _client.post<dynamic>(ApiConstants.adminDeliveryRefund(orderId), data: {'reason': reason, 'mode': 'wallet'});
}

final deliveryRepositoryProvider =
    Provider<DeliveryRepository>((ref) => DeliveryRepository(client: ref.watch(dioClientProvider)));

final deliveryConfigProvider = FutureProvider.autoDispose<DeliveryConfig>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchConfig());

final addressesProvider = FutureProvider.autoDispose<List<AddressModel>>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchAddresses());

final courierDeliveriesProvider = FutureProvider.autoDispose<CourierDeliveries>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchCourierDeliveries());

final storeSettingsProvider = FutureProvider.autoDispose<(StoreSettings, List<StoreHour>)>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchStoreSettings());

final couriersProvider = FutureProvider.autoDispose<List<CourierInfo>>(
    (ref) => ref.watch(deliveryRepositoryProvider).fetchCouriers());
