import 'dart:async';

import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/features/admin/data/admin_bookings_repository.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_delete.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_bookings.dart';

/// Stands in for Firestore in tests of the admin bookings list. Nothing
/// here contacts Firebase, and every value in the tests is made up.
class FakeAdminBookingsRepository implements AdminBookingsRepository {
  /// Every query that was started, with the limit it asked for.
  final limits = <int>[];

  final _controllers = <StreamController<RawBookingsResult>>[];

  /// How many queries are being listened to right now.
  var activeListeners = 0;

  /// How often the cars were read.
  var carReads = 0;

  /// What readAllCars answers.
  List<Car> cars = const [];

  /// When set, readAllCars fails with it.
  Object? carsError;

  /// When set, readAllCars waits for it.
  Completer<void>? carsPending;

  /// Makes the newest query answer with [documents].
  void emit(List<RawBookingDocument> documents, {bool fromCache = false}) {
    _controllers.last.add(
      RawBookingsResult(documents: documents, fromCache: fromCache),
    );
  }

  /// Makes the newest query fail with [error].
  void fail(Object error) => _controllers.last.addError(error);

  @override
  Stream<RawBookingsResult> watchNewestBookings({required int limit}) {
    limits.add(limit);
    final controller = StreamController<RawBookingsResult>(
      onListen: () => activeListeners += 1,
      onCancel: () => activeListeners -= 1,
    );
    _controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<List<Car>> readAllCars() async {
    carReads += 1;
    if (carsPending != null) await carsPending!.future;
    if (carsError != null) throw carsError!;
    return cars;
  }

  /// Every single booking that was asked for, by its ID, in order.
  final watchedBookingIds = <String>[];

  final _bookingControllers = <StreamController<RawBookingAnswer>>[];

  /// How many single bookings are being listened to right now.
  var activeBookingListeners = 0;

  /// Every car that was read by its ID, in order.
  final carIdsRead = <String>[];

  /// When set, readCar fails with it.
  Object? carError;

  /// Every status change that was asked for, in order.
  final statusChanges = <({String id, BookingStatus status})>[];

  /// When set, changeStatus waits for it.
  Completer<void>? statusChangePending;

  /// When set, changeStatus fails with it.
  Object? statusChangeError;

  /// Makes the newest single-booking listener answer with [document]; null
  /// means "there is no such document".
  void emitBooking(RawBookingDocument? document, {bool fromCache = false}) {
    _bookingControllers.last.add(
      RawBookingAnswer(document: document, fromCache: fromCache),
    );
  }

  /// Makes EVERY open single-booking listener answer with [document]: the
  /// detail and the edit form listen to the same booking.
  void emitBookingToAll(RawBookingDocument? document) {
    for (final controller in _bookingControllers) {
      if (controller.hasListener) {
        controller.add(RawBookingAnswer(document: document, fromCache: false));
      }
    }
  }

  /// Makes the newest single-booking listener fail with [error].
  void failBooking(Object error) => _bookingControllers.last.addError(error);

  @override
  Stream<RawBookingAnswer> watchBooking(String id) {
    watchedBookingIds.add(id);
    final controller = StreamController<RawBookingAnswer>(
      onListen: () => activeBookingListeners += 1,
      onCancel: () => activeBookingListeners -= 1,
    );
    _bookingControllers.add(controller);
    return controller.stream;
  }

  @override
  Future<Car?> readCar(String id) async {
    carIdsRead.add(id);
    if (carError != null) throw carError!;
    for (final car in cars) {
      if (car.id == id) return car;
    }
    return null;
  }

  @override
  Future<void> changeStatus(
    String id,
    BookingStatus status, {
    Duration timeout = adminStatusChangeTimeout,
  }) async {
    statusChanges.add((id: id, status: status));
    if (statusChangePending != null) await statusChangePending!.future;
    if (statusChangeError != null) throw statusChangeError!;
  }

  /// Every edit that was asked to be saved, in order.
  final updates = <({String id, Booking base, AdminBookingChanges changes})>[];

  /// When set, updateBooking waits for it.
  Completer<void>? updatePending;

  /// When set, updateBooking fails with it.
  Object? updateError;

  @override
  Future<void> updateBooking(
    String id, {
    required Booking base,
    required AdminBookingChanges changes,
    Duration timeout = adminStatusChangeTimeout,
  }) async {
    updates.add((id: id, base: base, changes: changes));
    if (updatePending != null) await updatePending!.future;
    if (updateError != null) throw updateError!;
  }

  /// Every delete that was asked for, in order.
  final deletes = <({String id, BookingStatus shownStatus})>[];

  /// When set, deleteBooking waits for it.
  Completer<void>? deletePending;

  /// When set, deleteBooking fails with it.
  Object? deleteError;

  /// What deleteBooking answers when it does not fail.
  var deleteResult = AdminBookingDeleteResult.deleted;

  @override
  Future<AdminBookingDeleteResult> deleteBooking(
    String id, {
    required BookingStatus shownStatus,
    Duration timeout = adminStatusChangeTimeout,
  }) async {
    deletes.add((id: id, shownStatus: shownStatus));
    if (deletePending != null) await deletePending!.future;
    if (deleteError != null) throw deleteError!;
    return deleteResult;
  }

  /// How many IDs were handed out. They are "new-1", "new-2", ...
  var newIds = 0;

  /// Every booking that was asked to be created, in order.
  final creates = <({String id, Booking booking})>[];

  /// The IDs that "exist on the server": a create for one of them answers
  /// "already created". A create that succeeds adds its ID.
  final existingIds = <String>{};

  /// When set, createBooking waits for it.
  Completer<void>? createPending;

  /// When set, createBooking fails with it. With [createLandsAnyway] the
  /// booking is "created on the server" all the same, as when only the
  /// answer got lost.
  Object? createError;
  var createLandsAnyway = false;

  @override
  String newBookingId() {
    newIds += 1;
    return 'new-$newIds';
  }

  @override
  Future<AdminBookingCreateResult> createBooking(
    String id,
    Booking booking, {
    Duration timeout = adminStatusChangeTimeout,
  }) async {
    creates.add((id: id, booking: booking));
    if (createPending != null) await createPending!.future;
    if (createError != null) {
      if (createLandsAnyway) existingIds.add(id);
      throw createError!;
    }
    if (existingIds.contains(id)) {
      return AdminBookingCreateResult.alreadyCreated;
    }
    existingIds.add(id);
    return AdminBookingCreateResult.created;
  }
}

/// A raw booking document as the repository hands it on: the dates are
/// already UTC DateTime values. Every value is made up.
RawBookingDocument rawBooking(
  String id, {
  String fullName = 'Test Person',
  String phone = '+995555000000',
  String carId = 'car-1',
  DateTime? pickup,
  DateTime? dropoff,
  String status = 'new',
  num totalPrice = 225,
  DateTime? createdAt,
  Map<String, dynamic> changes = const {},
}) {
  return (
    id: id,
    data: {
      'customer': {
        'fullName': fullName,
        'phone': phone,
        'whatsapp': false,
        'telegram': false,
        'email': 'person@example.com',
      },
      'carId': carId,
      // 18:00 and 20:00 in Tbilisi.
      'pickupDateTime': pickup ?? DateTime.utc(2026, 1, 10, 14),
      'dropoffDateTime': dropoff ?? DateTime.utc(2026, 1, 15, 16),
      'pickupLocation': {'id': 'tbilisiAirport'},
      'dropoffLocation': {'id': 'tbilisiOffice'},
      'extras': <String>[],
      'notes': '',
      'totalPrice': totalPrice,
      'language': 'en',
      'status': status,
      // 17:34 in Tbilisi.
      'createdAt': createdAt ?? DateTime.utc(2026, 10, 9, 13, 34),
      ...changes,
    },
  );
}

/// A made-up car for the tests.
Car testCar({String id = 'car-1', bool active = true}) {
  return Car(
    id: id,
    brand: 'Toyota',
    model: 'Prius',
    year: 2019,
    drivetrain: Drivetrain.fwd,
    transmission: Transmission.automatic,
    fuelType: FuelType.hybrid,
    seats: 5,
    engineSize: 1.8,
    pricePerDay: 45,
    description: const LocalizedText(),
    photos: const [],
    active: active,
  );
}
