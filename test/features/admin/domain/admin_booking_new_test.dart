import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_new.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';

import '../../../support/fake_admin_bookings_repository.dart';

const places = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Airport'),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Office'),
  ),
];

final prices = ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': 5,
    'childSeat': 4,
    'infantSeat': 3,
    'boosterSeat': 2.5,
  },
});

/// A form that is filled in completely and correctly; every value is made
/// up. 5 days with the car of 45 per day.
AdminNewBookingDraft filled({
  BookingFormInput Function(BookingFormInput input)? change,
  String carId = 'car-1',
  AppLanguage language = AppLanguage.en,
  BookingStatus status = BookingStatus.confirmed,
  bool noEmail = false,
}) {
  final input = BookingFormInput(
    fullName: ' Test Person ',
    phone: '+995 555 00-00-00',
    whatsapp: true,
    email: ' person@example.com ',
    pickup: TbilisiDateTime(2026, 1, 10, 18, 0),
    dropoff: TbilisiDateTime(2026, 1, 15, 20, 0),
    pickupLocation: const BookingLocation.fixed('tbilisiAirport'),
    dropoffLocation: const BookingLocation.other(' Made-up Street 1 '),
    extras: const {Extra.childSeat},
    notes: ' A note. ',
  );
  return AdminNewBookingDraft(
    fields: AdminBookingDraft(
      input: change == null ? input : change(input),
      carId: carId,
      language: language,
    ),
    status: status,
    noEmail: noEmail,
  );
}

Set<AdminBookingError> validate(
  AdminNewBookingDraft draft, {
  Set<String>? carIds = const {'car-1', 'car-2'},
  List<PickupLocation>? locations = places,
}) => validateNewBooking(draft, carIds: carIds, locations: locations);

void main() {
  group('the constants', () {
    test('createdBy is the fixed word "admin"', () {
      expect(adminCreatedByValue, 'admin');
      expect(adminCreatedByValue.trim(), adminCreatedByValue);
      expect(
        adminCreatedByValue.length,
        lessThanOrEqualTo(bookingNameMaxLength),
      );
      expect(adminCreatedByValue.contains('@'), false);
    });

    test('the placeholder for "no e-mail" is an address that the app and '
        'the rules accept and that can never receive mail', () {
      expect(noEmailPlaceholder, 'none@no-email.invalid');
      expect(noEmailPlaceholder.endsWith('.invalid'), true);
      expect(isValidEmail(noEmailPlaceholder), true);
      expect(isNoEmailPlaceholder(noEmailPlaceholder), true);
      expect(isNoEmailPlaceholder('person@example.com'), false);
      expect(isNoEmailPlaceholder(' $noEmailPlaceholder'), false);
    });

    test('"new" would pass as a booking ID, so it is reserved', () {
      expect(adminNewBookingPathSegment, 'new');
    });
  });

  group('the empty form', () {
    test('everything empty, English, Confirmed, no car, no dates', () {
      const draft = AdminNewBookingDraft.empty;

      expect(draft.fields.input.fullName, '');
      expect(draft.fields.input.pickup, isNull);
      expect(draft.fields.input.dropoff, isNull);
      expect(draft.fields.input.pickupLocation, isNull);
      expect(draft.fields.input.extras, isEmpty);
      expect(draft.fields.carId, '');
      expect(draft.fields.language, AppLanguage.en);
      expect(draft.status, BookingStatus.confirmed);
      expect(draft.noEmail, false);
      expect(newDraftIsDirty(draft), false);
    });

    test('anything entered or chosen makes it dirty', () {
      const empty = AdminNewBookingDraft.empty;
      final changed = [
        empty.copyWith(status: BookingStatus.pending),
        empty.copyWith(noEmail: true),
        empty.copyWith(fields: empty.fields.copyWith(carId: 'car-1')),
        empty.copyWith(fields: empty.fields.copyWith(language: AppLanguage.ka)),
        empty.copyWith(
          fields: empty.fields.copyWith(
            input: empty.fields.input.copyWith(notes: 'x'),
          ),
        ),
        empty.copyWith(
          fields: empty.fields.copyWith(
            input: empty.fields.input.copyWith(extras: {Extra.snowChains}),
          ),
        ),
      ];
      for (final draft in changed) {
        expect(newDraftIsDirty(draft), true);
      }
    });
  });

  group('validateNewBooking', () {
    test('a completely filled form is valid', () {
      expect(validate(filled()), isEmpty);
    });

    test('the empty form reports every required field', () {
      expect(validate(AdminNewBookingDraft.empty), {
        AdminBookingError.nameRequired,
        AdminBookingError.phoneRequired,
        AdminBookingError.emailRequired,
        AdminBookingError.carRequired,
        AdminBookingError.pickupRequired,
        AdminBookingError.dropoffRequired,
        AdminBookingError.pickupLocationRequired,
        AdminBookingError.dropoffLocationRequired,
      });
    });

    test('with "no e-mail" the e-mail field is not checked, whatever it '
        'holds', () {
      for (final email in ['', 'not an address', 'person@example.com']) {
        expect(
          validate(
            filled(change: (i) => i.copyWith(email: email), noEmail: true),
          ),
          isEmpty,
          reason: email,
        );
      }
      expect(validate(filled(change: (i) => i.copyWith(email: ''))), {
        AdminBookingError.emailRequired,
      });
    });

    test('a fixed place must be in settings: a new booking has no place '
        '"it already has"', () {
      final draft = filled(
        change: (i) =>
            i.copyWith(pickupLocation: const BookingLocation.fixed('oldPlace')),
      );
      expect(validate(draft), {AdminBookingError.pickupLocationUnknown});
      // While the places are not loaded no fixed place can be accepted.
      expect(validate(filled(), locations: null), {
        AdminBookingError.pickupLocationUnknown,
      });
    });

    test('nothing is "stored in another format" for a new booking', () {
      // The phone is typed with spaces; that is fine in a form.
      expect(validate(filled()).intersection(storedFormatErrorKinds), isEmpty);
    });

    test('a pickup in the past and a hidden car are allowed', () {
      final past = filled(
        change: (i) => i.copyWith(
          pickup: TbilisiDateTime(2020, 1, 1, 10, 0),
          dropoff: TbilisiDateTime(2020, 1, 3, 10, 0),
        ),
        carId: 'car-2',
      );
      expect(validate(past), isEmpty);
    });

    test('a car that does not exist, and the usual limits', () {
      expect(validate(filled(carId: 'gone-car')), {
        AdminBookingError.carMissing,
      });
      expect(validate(filled(change: (i) => i.copyWith(fullName: 'A'))), {
        AdminBookingError.nameTooShort,
      });
      expect(validate(filled(change: (i) => i.copyWith(phone: '555'))), {
        AdminBookingError.phoneInvalid,
      });
      expect(
        validate(
          filled(
            change: (i) =>
                i.copyWith(dropoff: TbilisiDateTime(2026, 1, 10, 18, 0)),
          ),
        ),
        {AdminBookingError.dropoffNotAfterPickup},
      );
      expect(validate(filled(change: (i) => i.copyWith(notes: 'a' * 501))), {
        AdminBookingError.notesTooLong,
      });
    });

    test('validateAdminBooking without a base is what it uses', () {
      final draft = filled();
      expect(
        validateAdminBooking(
          draft.fields,
          carIds: const {'car-1'},
          locations: places,
        ),
        validate(draft),
      );
    });
  });

  group('the total', () {
    final car = testCar(); // 45 per day
    AdminNewTotal total(
      AdminNewBookingDraft draft, {
      Car? withCar,
      bool noCar = false,
      bool noPrices = false,
    }) => newBookingTotal(
      draft: draft,
      car: noCar ? null : withCar ?? car,
      extrasPrices: noPrices ? null : prices,
    );

    test('days x (car + extras), at the current prices', () {
      final result = total(filled());

      expect(result.state, AdminNewTotalState.ready);
      expect(result.price!.days, 5);
      expect(result.carPricePerDay, 45);
      expect(result.extrasPerDay, 4);
      // 5 x (45 + 4)
      expect(result.price!.totalCents, 24500);
      expect(result.totalToSave, 245);
      expect(newTotalErrors(result), isEmpty);
      expect(
        adminNewBookingTotalText(result),
        'Total: 5 days × (\$45 car + \$4 extras) = \$245',
      );
    });

    test('more than 7 days: marked as an estimate, and still saved', () {
      final result = total(
        filled(
          change: (i) =>
              i.copyWith(dropoff: TbilisiDateTime(2026, 1, 20, 18, 0)),
        ),
      );

      expect(result.state, AdminNewTotalState.ready);
      expect(result.price!.isIndividualPrice, true);
      expect(
        adminNewBookingTotalText(result),
        'Total: 10 days × (\$45 car + \$4 extras) = \$490 · estimate',
      );
      expect(result.totalToSave, 490);
    });

    test('no car, no dates or dates that cannot be priced: incomplete, '
        'nothing to save, and no error of its own', () {
      final drafts = [
        AdminNewBookingDraft.empty,
        filled(carId: ''),
        filled(
          change: (i) =>
              i.copyWith(dropoff: TbilisiDateTime(2026, 1, 9, 18, 0)),
        ),
        filled(
          change: (i) =>
              i.copyWith(dropoff: TbilisiDateTime(2028, 1, 10, 18, 0)),
        ),
      ];
      for (final draft in drafts) {
        final result = total(draft, noCar: draft.fields.carId.isEmpty);
        expect(result.state, AdminNewTotalState.incomplete);
        expect(result.price, isNull);
        expect(result.totalToSave, isNull);
        expect(newTotalErrors(result), isEmpty);
        expect(
          adminNewBookingTotalText(result),
          'Choose a car and the dates to see the total.',
        );
      }
    });

    test('a car that is not in the list gives no total', () {
      expect(total(filled(), noCar: true).state, AdminNewTotalState.incomplete);
    });

    test('prices not loaded: no total, an error, and its text', () {
      final result = total(filled(), noPrices: true);

      expect(result.state, AdminNewTotalState.pricesNotLoaded);
      expect(result.totalToSave, isNull);
      expect(newTotalErrors(result), {AdminBookingError.newTotalUnavailable});
      expect(
        adminNewBookingTotalText(result),
        'The total cannot be calculated: the prices could not be loaded.',
      );
    });

    test('above the highest total of the rules: shown, an error, not '
        'saved', () {
      const goldCar = Car(
        id: 'car-1',
        brand: 'Made',
        model: 'Up',
        year: 2024,
        drivetrain: Drivetrain.fwd,
        transmission: Transmission.automatic,
        fuelType: FuelType.hybrid,
        seats: 2,
        engineSize: 6,
        pricePerDay: 3000,
        description: LocalizedText(),
        photos: [],
        active: true,
      );
      final result = total(
        filled(
          change: (i) =>
              i.copyWith(dropoff: TbilisiDateTime(2027, 1, 10, 18, 0)),
        ),
        withCar: goldCar,
      );

      expect(result.state, AdminNewTotalState.tooHigh);
      expect(result.totalToSave, isNull);
      expect(newTotalErrors(result), {AdminBookingError.totalTooHigh});
      expect(adminNewBookingTotalText(result), startsWith('Total: 365 days'));
    });

    test('exactly the highest total is still fine', () {
      const car = Car(
        id: 'car-1',
        brand: 'Made',
        model: 'Up',
        year: 2024,
        drivetrain: Drivetrain.fwd,
        transmission: Transmission.automatic,
        fuelType: FuelType.hybrid,
        seats: 2,
        engineSize: 6,
        pricePerDay: 200000,
        description: LocalizedText(),
        photos: [],
        active: true,
      );
      final result = total(
        filled(change: (i) => i.copyWith(extras: const {})),
        withCar: car,
      );

      expect(result.price!.totalCents, bookingMaxTotalPrice * 100);
      expect(result.state, AdminNewTotalState.ready);
    });

    test('the texts about the total', () {
      expect(adminTotalUsesTodaysPrices, "The total uses today's prices.");
      expect(adminNoEmail, 'No e-mail');
    });
  });

  group('newBookingFromDraft', () {
    test('cleans the texts, puts the phone into its plain form, turns '
        'Tbilisi times into UTC and takes the given total', () {
      final booking = newBookingFromDraft(draft: filled(), total: 245);

      expect(booking.id, isNull);
      expect(booking.createdAt, isNull);
      expect(booking.customer.fullName, 'Test Person');
      expect(booking.customer.phone, '+995555000000');
      expect(booking.customer.whatsapp, true);
      expect(booking.customer.telegram, false);
      expect(booking.customer.email, 'person@example.com');
      expect(booking.carId, 'car-1');
      expect(booking.pickup, DateTime.utc(2026, 1, 10, 14));
      expect(booking.dropoff, DateTime.utc(2026, 1, 15, 16));
      expect(
        booking.pickupLocation,
        const BookingLocation.fixed('tbilisiAirport'),
      );
      expect(booking.dropoffLocation.text, 'Made-up Street 1');
      expect(booking.extras, {Extra.childSeat});
      expect(booking.notes, 'A note.');
      expect(booking.totalPrice, 245);
      expect(booking.language, AppLanguage.en);
    });

    test('createdBy is always "admin"', () {
      expect(
        newBookingFromDraft(draft: filled(), total: 245).createdBy,
        'admin',
      );
    });

    test('the status is the chosen one; Confirmed unless changed', () {
      expect(
        newBookingFromDraft(draft: filled(), total: 245).status,
        BookingStatus.confirmed,
      );
      for (final status in BookingStatus.values) {
        expect(
          newBookingFromDraft(draft: filled(status: status), total: 245).status,
          status,
        );
      }
    });

    test('with "no e-mail" the placeholder is stored, whatever the field '
        'holds', () {
      for (final email in ['', 'typed@example.com']) {
        final booking = newBookingFromDraft(
          draft: filled(change: (i) => i.copyWith(email: email), noEmail: true),
          total: 245,
        );
        expect(booking.customer.email, noEmailPlaceholder);
      }
    });

    test('the language and the car are the chosen ones', () {
      final booking = newBookingFromDraft(
        draft: filled(carId: 'car-2', language: AppLanguage.ka),
        total: 600,
      );
      expect(booking.carId, 'car-2');
      expect(booking.language, AppLanguage.ka);
      expect(booking.totalPrice, 600);
    });

    test('a form that is not valid is refused', () {
      expect(
        () => newBookingFromDraft(draft: AdminNewBookingDraft.empty, total: 0),
        throwsArgumentError,
      );
      expect(
        () => newBookingFromDraft(draft: filled(carId: ' '), total: 245),
        throwsArgumentError,
      );
      expect(
        () => newBookingFromDraft(
          draft: filled(change: (i) => i.copyWith(phone: 'x')),
          total: 245,
        ),
        throwsArgumentError,
      );
    });
  });

  group('create failures', () {
    test('the Firestore codes map as for a status change', () {
      expect(
        createFailureFromCode('unavailable'),
        AdminBookingCreateFailure.noConnection,
      );
      expect(
        createFailureFromCode('deadline-exceeded'),
        AdminBookingCreateFailure.noConnection,
      );
      expect(
        createFailureFromCode('permission-denied'),
        AdminBookingCreateFailure.refused,
      );
      // "not found" has no meaning for a create.
      expect(
        createFailureFromCode('not-found'),
        AdminBookingCreateFailure.unknown,
      );
      expect(
        createFailureFromCode('aborted'),
        AdminBookingCreateFailure.unknown,
      );
      expect(
        createFailureFromCode('already-exists'),
        AdminBookingCreateFailure.unknown,
      );
    });

    test('each failure has its own notice, never "saved", "no answer" or '
        '"still unknown"', () {
      final notices = {
        for (final failure in AdminBookingCreateFailure.values)
          noticeForCreateFailure(failure),
      };

      expect(notices, hasLength(AdminBookingCreateFailure.values.length));
      expect(notices, isNot(contains(AdminBookingCreateNotice.saved)));
      expect(notices, isNot(contains(AdminBookingCreateNotice.noAnswer)));
      expect(notices, isNot(contains(AdminBookingCreateNotice.stillUnknown)));
      for (final failure in AdminBookingCreateFailure.values) {
        expect(noticeForCreateFailure(failure).name, failure.name);
      }
    });

    test('the texts: one "Saved"; "no answer" and "still unknown" promise '
        'that nothing is created twice; the rest say "Not saved."', () {
      final texts = {
        for (final notice in AdminBookingCreateNotice.values)
          notice: adminCreateNoticeText(notice),
      };

      expect(texts.values.toSet(), hasLength(texts.length));
      expect(texts[AdminBookingCreateNotice.saved], 'Saved');
      expect(
        texts[AdminBookingCreateNotice.noAnswer],
        'No answer from the server. Press "Check again": the booking will '
        'not be created twice.',
      );
      for (final notice in [
        AdminBookingCreateNotice.noAnswer,
        AdminBookingCreateNotice.stillUnknown,
      ]) {
        expect(texts[notice], isNot(contains('Not saved')));
        expect(texts[notice], contains('will not be created twice'));
        expect(texts[notice], contains(adminCheckAgain));
      }
      for (final failure in AdminBookingCreateFailure.values) {
        expect(
          texts[noticeForCreateFailure(failure)],
          startsWith('Not saved. '),
        );
      }
    });

    test('the exceptions carry no Firestore type and no customer data', () {
      expect(
        const AdminBookingCreateException(
          AdminBookingCreateFailure.refused,
        ).toString(),
        'AdminBookingCreateException(refused)',
      );
      expect(
        const AdminBookingCreateNoAnswer().toString(),
        'AdminBookingCreateNoAnswer',
      );
    });
  });
}
