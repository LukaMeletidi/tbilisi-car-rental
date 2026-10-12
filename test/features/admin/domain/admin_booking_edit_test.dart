import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/localization/app_language.dart';
import 'package:tbilisi_car_rental/core/models/booking.dart';
import 'package:tbilisi_car_rental/core/models/booking_location.dart';
import 'package:tbilisi_car_rental/core/models/booking_status.dart';
import 'package:tbilisi_car_rental/core/models/car.dart';
import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/core/time/tbilisi_time.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_document.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_form_validation.dart';

import '../../../support/fake_admin_bookings_repository.dart';

/// A stored booking; every value is made up. 5 days, total 225.
Booking stored({Map<String, dynamic> changes = const {}}) =>
    Booking.fromMap('b1', rawBooking('b1', changes: changes).data);

const places = [
  PickupLocation(
    id: 'tbilisiAirport',
    name: LocalizedText(en: 'Airport'),
  ),
  PickupLocation(
    id: 'tbilisiOffice',
    name: LocalizedText(en: 'Office'),
  ),
  PickupLocation(
    id: 'batumi',
    name: LocalizedText(en: 'Batumi'),
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

/// A copy of the fields of [draft] with some of them changed.
AdminBookingDraft withInput(
  AdminBookingDraft draft,
  BookingFormInput Function(BookingFormInput input) change,
) => draft.copyWith(input: change(draft.input));

Set<AdminBookingError> validate(
  AdminBookingDraft draft, {
  Booking? base,
  Set<String>? carIds = const {'car-1', 'car-2'},
  List<PickupLocation>? locations = places,
}) => validateAdminBooking(
  draft,
  base: base ?? stored(),
  carIds: carIds,
  locations: locations,
);

void main() {
  final base = stored();
  final initial = AdminBookingDraft.fromBooking(base);

  group('AdminBookingField', () {
    test('names every editable field of the rules, and nothing else', () {
      final keys = [
        for (final field in AdminBookingField.values) field.storedKey,
      ];

      expect(keys.toSet(), hasLength(keys.length));
      expect(keys.toSet(), {
        for (final key in adminBookingKeys)
          if (!const ['status', 'createdAt', 'createdBy'].contains(key)) key,
      });
    });
  });

  group('AdminBookingDraft', () {
    test('fromBooking shows the booking unchanged, in Tbilisi time', () {
      expect(initial.input.fullName, 'Test Person');
      expect(initial.input.phone, '+995555000000');
      expect(initial.input.email, 'person@example.com');
      // Stored 14:00 and 16:00 UTC.
      expect(initial.input.pickup, TbilisiDateTime(2026, 1, 10, 18, 0));
      expect(initial.input.dropoff, TbilisiDateTime(2026, 1, 15, 20, 0));
      expect(
        initial.input.pickupLocation,
        const BookingLocation.fixed('tbilisiAirport'),
      );
      expect(initial.carId, 'car-1');
      expect(initial.language, AppLanguage.en);
      expect(initial.totalChoice, isNull);
    });

    test('copyWith keeps the choice of the total unless told otherwise', () {
      final chosen = initial.copyWith(totalChoice: AdminTotalChoice.useNew);

      expect(
        chosen.copyWith(carId: 'car-2').totalChoice,
        AdminTotalChoice.useNew,
      );
      expect(chosen.copyWith(keepTotalChoice: false).totalChoice, isNull);
      expect(
        chosen
            .copyWith(
              totalChoice: AdminTotalChoice.keepStored,
              keepTotalChoice: false,
            )
            .totalChoice,
        AdminTotalChoice.keepStored,
      );
    });
  });

  group('draftChanges', () {
    test('nothing for the unchanged draft', () {
      expect(
        draftChanges(initial, AdminBookingDraft.fromBooking(base)),
        isEmpty,
      );
    });

    test('each part is found', () {
      final cases = <AdminBookingField, AdminBookingDraft>{
        AdminBookingField.customer: withInput(
          initial,
          (i) => i.copyWith(telegram: true),
        ),
        AdminBookingField.car: initial.copyWith(carId: 'car-2'),
        AdminBookingField.pickup: withInput(
          initial,
          (i) => i.copyWith(pickup: TbilisiDateTime(2026, 1, 10, 19, 0)),
        ),
        AdminBookingField.dropoff: withInput(
          initial,
          (i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 16, 20, 0)),
        ),
        AdminBookingField.pickupLocation: withInput(
          initial,
          (i) => i.copyWith(
            pickupLocation: const BookingLocation.other('Made-up Street 1'),
          ),
        ),
        AdminBookingField.dropoffLocation: withInput(
          initial,
          (i) => i.copyWith(
            dropoffLocation: const BookingLocation.fixed('batumi'),
          ),
        ),
        AdminBookingField.extras: withInput(
          initial,
          (i) => i.copyWith(extras: {Extra.childSeat}),
        ),
        AdminBookingField.notes: withInput(
          initial,
          (i) => i.copyWith(notes: 'A made-up note.'),
        ),
        AdminBookingField.language: initial.copyWith(language: AppLanguage.ka),
      };

      for (final entry in cases.entries) {
        expect(draftChanges(initial, entry.value), {entry.key});
      }
    });

    test('typing counts although the cleaned value would be the same', () {
      final typed = withInput(
        initial,
        (i) => i.copyWith(fullName: 'Test Person '),
      );
      expect(draftChanges(initial, typed), {AdminBookingField.customer});
    });

    test('the choice of the total is not a field', () {
      expect(
        draftChanges(
          initial,
          initial.copyWith(totalChoice: AdminTotalChoice.useNew),
        ),
        isEmpty,
      );
    });
  });

  group('validateAdminBooking', () {
    test('a stored booking is valid as it is', () {
      expect(validate(initial), isEmpty);
    });

    test('the name: required, 2 to 100 characters after trimming', () {
      Set<AdminBookingError> name(String value) =>
          validate(withInput(initial, (i) => i.copyWith(fullName: value)));

      expect(name('   '), {AdminBookingError.nameRequired});
      expect(name(' A '), {AdminBookingError.nameTooShort});
      expect(name('Ab'), isEmpty);
      expect(name('a' * 100), isEmpty);
      expect(name('a' * 101), {AdminBookingError.nameTooLong});
    });

    test('the phone: required, international format', () {
      Set<AdminBookingError> phone(String value) =>
          validate(withInput(initial, (i) => i.copyWith(phone: value)));

      expect(phone(''), {AdminBookingError.phoneRequired});
      expect(phone('555000000'), {AdminBookingError.phoneInvalid});
      expect(phone('+995 555 00-00-00'), isEmpty);
    });

    test('the e-mail: required, a valid shape, 254 characters at most', () {
      Set<AdminBookingError> email(String value) =>
          validate(withInput(initial, (i) => i.copyWith(email: value)));

      expect(email(' '), {AdminBookingError.emailRequired});
      expect(email('person@example'), {AdminBookingError.emailInvalid});
      expect(email('${'a' * 250}@example.com'), {
        AdminBookingError.emailTooLong,
      });
      expect(email(' other@example.com '), isEmpty);
    });

    test('the car must be one of the existing cars; a hidden one is fine', () {
      // "car-2" stands for a hidden car: the list holds every car.
      expect(validate(initial.copyWith(carId: 'car-2')), isEmpty);
      expect(validate(initial.copyWith(carId: 'gone-car')), {
        AdminBookingError.carMissing,
      });
      expect(validate(initial.copyWith(carId: ' ')), {
        AdminBookingError.carRequired,
      });
    });

    test('the stored car that no longer exists is an error too', () {
      expect(validate(initial, carIds: const {'car-2'}), {
        AdminBookingError.carMissing,
      });
    });

    test('while the cars are not loaded the car is not checked here', () {
      expect(validate(initial, carIds: null), isEmpty);
    });

    test('a pickup in the past is allowed', () {
      final past = withInput(
        initial,
        (i) => i.copyWith(
          pickup: TbilisiDateTime(2020, 1, 1, 10, 0),
          dropoff: TbilisiDateTime(2020, 1, 3, 10, 0),
        ),
      );

      expect(validate(past), isEmpty);
      expect(isPickupInPast(past, now: DateTime.utc(2026, 10, 9)), true);
      expect(
        isPickupInPast(initial, now: DateTime.utc(2026, 1, 10, 13)),
        false,
      );
      expect(isPickupInPast(initial, now: DateTime.utc(2026, 1, 10, 15)), true);
    });

    test('isPickupInPast needs a UTC "now"', () {
      expect(
        () => isPickupInPast(initial, now: DateTime(2026)),
        throwsArgumentError,
      );
    });

    test('the dates: both required, drop-off after pickup, 365 days at '
        'most', () {
      Set<AdminBookingError> dates(
        TbilisiDateTime? pickup,
        TbilisiDateTime? dropoff,
      ) => validate(
        AdminBookingDraft(
          input: BookingFormInput(
            fullName: initial.input.fullName,
            phone: initial.input.phone,
            email: initial.input.email,
            pickup: pickup,
            dropoff: dropoff,
            pickupLocation: initial.input.pickupLocation,
            dropoffLocation: initial.input.dropoffLocation,
          ),
          carId: 'car-1',
          language: AppLanguage.en,
        ),
      );
      final start = TbilisiDateTime(2026, 1, 10, 18, 0);

      expect(dates(null, null), {
        AdminBookingError.pickupRequired,
        AdminBookingError.dropoffRequired,
      });
      expect(dates(start, start), {AdminBookingError.dropoffNotAfterPickup});
      expect(dates(start, TbilisiDateTime(2026, 1, 10, 17, 59)), {
        AdminBookingError.dropoffNotAfterPickup,
      });
      // 2026 is not a leap year: exactly 365 days later.
      expect(dates(start, TbilisiDateTime(2027, 1, 10, 18, 0)), isEmpty);
      expect(dates(start, TbilisiDateTime(2027, 1, 10, 18, 1)), {
        AdminBookingError.rentalTooLong,
      });
    });

    test('a fixed place must be in settings', () {
      final unknown = withInput(
        initial,
        (i) => i.copyWith(
          pickupLocation: const BookingLocation.fixed('nowhere'),
          dropoffLocation: const BookingLocation.fixed('nowhere'),
        ),
      );

      expect(validate(unknown), {
        AdminBookingError.pickupLocationUnknown,
        AdminBookingError.dropoffLocationUnknown,
      });
    });

    test('the place the booking already has stays possible when it was '
        'removed from settings, but only in its own field', () {
      const others = [
        PickupLocation(
          id: 'batumi',
          name: LocalizedText(en: 'Batumi'),
        ),
      ];
      expect(validate(initial, locations: others), isEmpty);
      expect(validate(initial, locations: null), isEmpty);

      // The stored pickup place is not accepted as the drop-off place.
      final swapped = withInput(
        initial,
        (i) => i.copyWith(
          dropoffLocation: const BookingLocation.fixed('tbilisiAirport'),
        ),
      );
      expect(validate(swapped, locations: others), {
        AdminBookingError.dropoffLocationUnknown,
      });
    });

    test('a stored place ID of a shape the rules refuse is an error', () {
      final odd = stored(
        changes: {
          'pickupLocation': {'id': 'tbilisi airport'},
        },
      );
      expect(validate(AdminBookingDraft.fromBooking(odd), base: odd), {
        AdminBookingError.pickupLocationUnknown,
      });
    });

    test('another place needs a text of 200 characters at most', () {
      Set<AdminBookingError> other(String text) => validate(
        withInput(
          initial,
          (i) => i.copyWith(
            pickupLocation: BookingLocation.other(text),
            dropoffLocation: BookingLocation.other(text),
          ),
        ),
      );

      expect(other('  '), {
        AdminBookingError.pickupLocationTextRequired,
        AdminBookingError.dropoffLocationTextRequired,
      });
      expect(other('a' * 200), isEmpty);
      expect(other('a' * 201), {
        AdminBookingError.pickupLocationTextTooLong,
        AdminBookingError.dropoffLocationTextTooLong,
      });
    });

    test('the notes: 500 characters at most', () {
      Set<AdminBookingError> notes(String value) =>
          validate(withInput(initial, (i) => i.copyWith(notes: value)));

      expect(notes(''), isEmpty);
      expect(notes('a' * 500), isEmpty);
      expect(notes('a' * 501), {AdminBookingError.notesTooLong});
    });

    test('several problems are all reported', () {
      final bad = withInput(
        initial,
        (i) => i.copyWith(fullName: '', phone: 'x', email: 'y'),
      );
      expect(validate(bad), {
        AdminBookingError.nameRequired,
        AdminBookingError.phoneInvalid,
        AdminBookingError.emailInvalid,
      });
    });
  });

  group('a stored value the rules refuse, in a part that was not '
      'touched', () {
    Map<String, dynamic> customer({
      String fullName = 'Test Person',
      String phone = '+995555000000',
      String email = 'person@example.com',
    }) => {
      'customer': {
        'fullName': fullName,
        'phone': phone,
        'whatsapp': false,
        'telegram': false,
        'email': email,
      },
    };

    /// The errors of [from] opened in the form, with only the language
    /// changed.
    Set<AdminBookingError> untouched(Booking from) => validate(
      AdminBookingDraft.fromBooking(from).copyWith(language: AppLanguage.ru),
      base: from,
    );

    test('a booking as the app writes it has no such error', () {
      expect(storedFormatErrors(base, initial), isEmpty);
      expect(untouched(base), isEmpty);
    });

    test('a phone with spaces, or in another form the app can read', () {
      for (final phone in [
        '+995 555 00-00-00',
        '+995555000000 ',
        '+995.555.000000',
        '+995 (555) 000000',
      ]) {
        expect(untouched(stored(changes: customer(phone: phone))), {
          AdminBookingError.phoneStoredFormat,
        }, reason: phone);
      }
    });

    test('a name with a space at the end, or at the start', () {
      for (final name in ['Test Person ', ' Test Person']) {
        expect(untouched(stored(changes: customer(fullName: name))), {
          AdminBookingError.nameStoredFormat,
        }, reason: '"$name"');
      }
    });

    test('an e-mail with a space at the end', () {
      expect(
        untouched(stored(changes: customer(email: 'person@example.com '))),
        {AdminBookingError.emailStoredFormat},
      );
    });

    test('a place text with a space at the end, each place by itself', () {
      expect(
        untouched(
          stored(
            changes: {
              'pickupLocation': {'id': 'other', 'text': 'Made-up Street 1 '},
            },
          ),
        ),
        {AdminBookingError.pickupLocationStoredFormat},
      );
      expect(
        untouched(
          stored(
            changes: {
              'dropoffLocation': {'id': 'other', 'text': ' Made-up Street 2'},
            },
          ),
        ),
        {AdminBookingError.dropoffLocationStoredFormat},
      );
    });

    test('notes with a space at the end stay silent: the rules accept '
        'them', () {
      expect(untouched(stored(changes: {'notes': 'Late arrival '})), isEmpty);
    });

    test('a fixed place and a clean text stay silent', () {
      expect(
        untouched(
          stored(
            changes: {
              'pickupLocation': {'id': 'other', 'text': 'Made-up Street 1'},
            },
          ),
        ),
        isEmpty,
      );
    });

    test('touching the part removes the error, and the part is then '
        'cleaned', () {
      final from = stored(
        changes: {
          ...customer(phone: '+995 555 00-00-00', fullName: 'Test Person '),
          'pickupLocation': {'id': 'other', 'text': 'Made-up Street 1 '},
        },
      );
      final start = AdminBookingDraft.fromBooking(from);
      expect(validate(start, base: from), {
        AdminBookingError.nameStoredFormat,
        AdminBookingError.phoneStoredFormat,
        AdminBookingError.pickupLocationStoredFormat,
      });

      // The admin corrects the phone: the whole customer counts as
      // touched, so the name is cleaned with it.
      final phoneFixed = withInput(
        start,
        (i) => i.copyWith(phone: '+995555000000'),
      );
      expect(validate(phoneFixed, base: from), {
        AdminBookingError.pickupLocationStoredFormat,
      });

      final allFixed = withInput(
        phoneFixed,
        (i) => i.copyWith(
          pickupLocation: const BookingLocation.other('Made-up Street 1'),
        ),
      );
      expect(validate(allFixed, base: from), isEmpty);

      final edited = editedBooking(base: from, draft: allFixed, newTotal: null);
      expect(edited.customer.phone, '+995555000000');
      expect(edited.customer.fullName, 'Test Person');
      expect(edited.pickupLocation.text, 'Made-up Street 1');
      expect(bookingChanges(from, edited), {
        AdminBookingField.customer,
        AdminBookingField.pickupLocation,
      });
    });

    test('typing the stored value back brings the error back', () {
      final from = stored(changes: customer(phone: '+995 555 00-00-00'));
      final start = AdminBookingDraft.fromBooking(from);
      final changed = withInput(start, (i) => i.copyWith(phone: '+995555'));
      final back = withInput(
        changed,
        (i) => i.copyWith(phone: '+995 555 00-00-00'),
      );

      expect(validate(back, base: from), {AdminBookingError.phoneStoredFormat});
    });

    test('a value that is wrong in another way keeps its own error only', () {
      expect(untouched(stored(changes: customer(phone: 'not a phone'))), {
        AdminBookingError.phoneInvalid,
      });
      expect(untouched(stored(changes: customer(fullName: 'A '))), {
        AdminBookingError.nameTooShort,
      });
      expect(untouched(stored(changes: customer(email: 'person@example '))), {
        AdminBookingError.emailInvalid,
      });
    });
  });

  group('storedFormatErrorsOfDocument (used by the status change)', () {
    test('a document as the app writes it: nothing', () {
      expect(
        storedFormatErrorsOfDocument('b1', rawBooking('b1').data),
        isEmpty,
      );
    });

    test('the parts stored in a form the rules refuse are found', () {
      final data = rawBooking(
        'b1',
        changes: {
          'customer': {
            'fullName': 'Test Person ',
            'phone': '+995 555 00-00-00',
            'whatsapp': false,
            'telegram': false,
            'email': 'person@example.com ',
          },
          'dropoffLocation': {'id': 'other', 'text': 'Made-up Street 2 '},
          'notes': 'Late arrival ',
        },
      ).data;

      expect(storedFormatErrorsOfDocument('b1', data), {
        AdminBookingError.nameStoredFormat,
        AdminBookingError.phoneStoredFormat,
        AdminBookingError.emailStoredFormat,
        AdminBookingError.dropoffLocationStoredFormat,
      });
    });

    test('a document that cannot be read as a booking gives nothing: the '
        'rules then decide', () {
      expect(
        storedFormatErrorsOfDocument(
          'b1',
          rawBooking('b1', changes: {'status': 'approved'}).data,
        ),
        isEmpty,
      );
      expect(storedFormatErrorsOfDocument('b1', const {}), isEmpty);
    });

    test('storedFormatErrorKinds are exactly the errors of this check', () {
      expect(storedFormatErrorKinds, {
        for (final error in AdminBookingError.values)
          if (error.name.endsWith('StoredFormat')) error,
      });
      expect(storedFormatErrorKinds, hasLength(5));
    });
  });

  group('adminPickerRange', () {
    test('5 calendar years back and 2 ahead, whole years', () {
      final range = adminPickerRange(TbilisiDateTime(2026, 10, 9, 16, 0));

      expect(adminPickerYearsBack, 5);
      expect(adminPickerYearsAhead, 2);
      expect(range.first, TbilisiDateTime(2021, 1, 1, 0, 0));
      expect(range.last, TbilisiDateTime(2028, 12, 31, 23, 59));
    });

    test('works on 29 February', () {
      final range = adminPickerRange(TbilisiDateTime(2028, 2, 29, 12, 0));

      expect(range.first, TbilisiDateTime(2023, 1, 1, 0, 0));
      expect(range.last, TbilisiDateTime(2030, 12, 31, 23, 59));
    });
  });

  group('the total', () {
    final car = testCar(); // 45 per day
    final dearCar = Car(
      id: 'car-2',
      brand: 'Toyota',
      model: 'Land Cruiser',
      year: 2022,
      drivetrain: Drivetrain.fwd,
      transmission: Transmission.automatic,
      fuelType: FuelType.hybrid,
      seats: 7,
      engineSize: 3.5,
      pricePerDay: 120,
      description: const LocalizedText(),
      photos: const [],
      active: false,
    );

    AdminTotalComparison compare(
      AdminBookingDraft draft, {
      Car? withCar,
      bool noCar = false,
      ExtrasPrices? withPrices,
      bool noPrices = false,
      Booking? from,
    }) => compareTotals(
      base: from ?? base,
      draft: draft,
      car: noCar ? null : withCar ?? car,
      extrasPrices: noPrices ? null : withPrices ?? prices,
    );

    test('nothing the price depends on changed: no choice, the stored total '
        'stays', () {
      final edited = withInput(initial, (i) => i.copyWith(notes: 'A note.'));
      final totals = compare(edited);

      expect(totals.storedCents, 22500);
      expect(totals.storedDays, 5);
      expect(totals.priceFieldsChanged, false);
      expect(totals.choiceNeeded, false);
      expect(totalErrors(totals, null), isEmpty);
      expect(totalToSave(totals, null), isNull);
      // Even a choice changes nothing then.
      expect(totalToSave(totals, AdminTotalChoice.useNew), isNull);
    });

    test('the stored total is never replaced because prices went up', () {
      // The car costs more today, but nothing of the booking changed.
      final totals = compare(initial, withCar: dearCar);

      expect(totals.newPrice!.totalCents, 60000);
      expect(totals.differs, true);
      expect(totals.choiceNeeded, false);
      expect(totalToSave(totals, AdminTotalChoice.useNew), isNull);
    });

    test('the new total: days x (car + extras), at the current prices', () {
      final edited = withInput(
        initial,
        (i) => i.copyWith(
          dropoff: TbilisiDateTime(2026, 1, 17, 20, 0),
          extras: {Extra.childSeat, Extra.boosterSeat},
        ),
      );
      final totals = compare(edited);

      expect(totals.priceFieldsChanged, true);
      expect(totals.newPrice!.days, 7);
      expect(totals.carPricePerDay, 45);
      expect(totals.extrasPerDay, 6.5);
      // 7 x (45 + 4 + 2.5)
      expect(totals.newPrice!.totalCents, 36050);
      expect(totals.newPrice!.isIndividualPrice, false);
      expect(totals.choiceNeeded, true);
      expect(totals.canUseNew, true);
    });

    test('each of car, pickup, drop-off and extras asks for a choice', () {
      final drafts = [
        initial.copyWith(carId: 'car-2'),
        withInput(
          initial,
          (i) => i.copyWith(pickup: TbilisiDateTime(2026, 1, 8, 18, 0)),
        ),
        withInput(
          initial,
          (i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 20, 20, 0)),
        ),
        withInput(initial, (i) => i.copyWith(extras: {Extra.snowChains})),
      ];
      for (final draft in drafts) {
        final totals = compare(
          draft,
          withCar: draft.carId == 'car-2' ? dearCar : car,
        );
        expect(totals.choiceNeeded, true);
        expect(totalErrors(totals, null), {
          AdminBookingError.totalChoiceRequired,
        });
      }
    });

    test('nothing is chosen for the admin: no choice, no save, no new '
        'total', () {
      final totals = compare(
        initial.copyWith(carId: 'car-2'),
        withCar: dearCar,
      );

      expect(totalErrors(totals, null), {
        AdminBookingError.totalChoiceRequired,
      });
      expect(totalToSave(totals, null), isNull);
    });

    test('"keep the stored total" writes no total', () {
      final totals = compare(
        initial.copyWith(carId: 'car-2'),
        withCar: dearCar,
      );

      expect(totalErrors(totals, AdminTotalChoice.keepStored), isEmpty);
      expect(totalToSave(totals, AdminTotalChoice.keepStored), isNull);
    });

    test('"use the new total" writes the new total', () {
      final totals = compare(
        initial.copyWith(carId: 'car-2'),
        withCar: dearCar,
      );

      expect(totalErrors(totals, AdminTotalChoice.useNew), isEmpty);
      expect(totalToSave(totals, AdminTotalChoice.useNew), 600);
    });

    test('a change that leaves the total as it is needs no choice', () {
      // One hour later on both ends: still 5 days at the same price.
      final moved = withInput(
        initial,
        (i) => i.copyWith(
          pickup: TbilisiDateTime(2026, 1, 10, 19, 0),
          dropoff: TbilisiDateTime(2026, 1, 15, 21, 0),
        ),
      );
      final totals = compare(moved);

      expect(totals.priceFieldsChanged, true);
      expect(totals.differs, false);
      expect(totals.choiceNeeded, false);
      expect(totalErrors(totals, null), isEmpty);
      expect(totalToSave(totals, null), isNull);
    });

    test('prices or car not loaded: only "keep" is possible', () {
      final edited = initial.copyWith(carId: 'car-2');
      for (final totals in [
        compare(edited, noPrices: true),
        compare(edited, noCar: true),
      ]) {
        expect(totals.newPrice, isNull);
        expect(totals.choiceNeeded, true);
        expect(totals.canUseNew, false);
        expect(totalErrors(totals, null), {
          AdminBookingError.totalChoiceRequired,
        });
        expect(totalErrors(totals, AdminTotalChoice.keepStored), isEmpty);
        expect(totalErrors(totals, AdminTotalChoice.useNew), {
          AdminBookingError.newTotalUnavailable,
        });
        expect(totalToSave(totals, AdminTotalChoice.useNew), isNull);
      }
    });

    test('dates that cannot be used give no new total', () {
      final broken = withInput(
        initial,
        (i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 9, 18, 0)),
      );
      expect(compare(broken).newPrice, isNull);
    });

    test('a new total above the highest total of the rules cannot be '
        'used', () {
      final goldCar = Car(
        id: 'car-2',
        brand: 'Made',
        model: 'Up',
        year: 2024,
        drivetrain: Drivetrain.fwd,
        transmission: Transmission.automatic,
        fuelType: FuelType.hybrid,
        seats: 2,
        engineSize: 6,
        pricePerDay: 3000,
        description: const LocalizedText(),
        photos: const [],
        active: true,
      );
      final long = withInput(
        initial.copyWith(carId: 'car-2'),
        (i) => i.copyWith(dropoff: TbilisiDateTime(2027, 1, 10, 18, 0)),
      );
      final totals = compare(long, withCar: goldCar);

      expect(totals.newPrice!.totalCents, greaterThan(100000000));
      expect(totals.canUseNew, false);
      expect(totalErrors(totals, AdminTotalChoice.useNew), {
        AdminBookingError.totalTooHigh,
      });
      expect(totalToSave(totals, AdminTotalChoice.useNew), isNull);
      expect(totalErrors(totals, AdminTotalChoice.keepStored), isEmpty);
    });

    test('more than 7 days: the new total is an estimate', () {
      final long = withInput(
        initial,
        (i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 20, 18, 0)),
      );
      expect(compare(long).newPrice!.isIndividualPrice, true);
    });
  });

  group('editedBooking', () {
    test('the unchanged draft gives the stored booking back exactly', () {
      expect(editedBooking(base: base, draft: initial, newTotal: null), base);
    });

    test('texts are cleaned and the phone is stored in its plain form', () {
      final edited = editedBooking(
        base: base,
        draft: withInput(
          initial,
          (i) => i.copyWith(
            fullName: '  Other Person ',
            phone: '+995 555 11-11-11',
            email: ' other@example.com ',
            notes: '  A note. ',
            pickupLocation: const BookingLocation.other(' Made-up Street 1 '),
          ),
        ),
        newTotal: null,
      );

      expect(edited.customer.fullName, 'Other Person');
      expect(edited.customer.phone, '+995555111111');
      expect(edited.customer.email, 'other@example.com');
      expect(edited.notes, 'A note.');
      expect(edited.pickupLocation.text, 'Made-up Street 1');
    });

    test('id, status, createdAt and createdBy are always the stored ones', () {
      final from = stored(
        changes: {'status': 'confirmed', 'createdBy': 'Made-up Staff'},
      );
      final edited = editedBooking(
        base: from,
        draft: AdminBookingDraft.fromBooking(
          from,
        ).copyWith(carId: 'car-2', language: AppLanguage.ru),
        newTotal: 600,
      );

      expect(edited.id, 'b1');
      expect(edited.status, BookingStatus.confirmed);
      expect(edited.createdAt, from.createdAt);
      expect(edited.createdBy, 'Made-up Staff');
      expect(edited.carId, 'car-2');
      expect(edited.language, AppLanguage.ru);
      expect(edited.totalPrice, 600);
    });

    test('a date that was not touched keeps its stored moment, also its '
        'seconds; a changed date is the chosen minute', () {
      final from = stored(
        changes: {
          'pickupDateTime': DateTime.utc(2026, 1, 10, 14, 0, 30, 123, 456),
          'dropoffDateTime': DateTime.utc(2026, 1, 15, 16, 0, 59),
        },
      );
      final draft = AdminBookingDraft.fromBooking(from);

      final same = editedBooking(base: from, draft: draft, newTotal: null);
      expect(same.pickup, from.pickup);
      expect(same.dropoff, from.dropoff);
      expect(bookingChanges(from, same), isEmpty);

      final moved = editedBooking(
        base: from,
        draft: withInput(
          draft,
          (i) => i.copyWith(dropoff: TbilisiDateTime(2026, 1, 16, 20, 0)),
        ),
        newTotal: null,
      );
      expect(moved.pickup, from.pickup);
      expect(moved.dropoff, DateTime.utc(2026, 1, 16, 16));
    });

    test('without a new total the stored total stays', () {
      final edited = editedBooking(
        base: base,
        draft: initial.copyWith(carId: 'car-2'),
        newTotal: null,
      );
      expect(edited.totalPrice, 225);
    });

    test('untouched notes keep their stored value exactly: stored notes '
        'with a space at the end and a name change send only the customer', () {
      final from = stored(changes: {'notes': 'Late arrival '});
      final draft = withInput(
        AdminBookingDraft.fromBooking(from),
        (i) => i.copyWith(fullName: 'Other Person'),
      );

      final edited = editedBooking(base: from, draft: draft, newTotal: null);
      final changes = AdminBookingChanges.between(from, edited);

      expect(edited.notes, 'Late arrival ');
      expect(changes.fields, {AdminBookingField.customer});
      expect(changes.values.keys, ['customer']);
    });

    test('an untouched customer keeps the stored value exactly: a stored '
        'phone in a valid but not plain form and a notes edit send only '
        'the notes', () {
      final from = stored(
        changes: {
          'customer': {
            'fullName': ' Test Person',
            'phone': '+995 555 00-00-00',
            'whatsapp': false,
            'telegram': false,
            'email': 'person@example.com ',
          },
        },
      );
      final draft = withInput(
        AdminBookingDraft.fromBooking(from),
        (i) => i.copyWith(notes: 'A note.'),
      );
      // The whole draft is still validated: the stored values the rules
      // refuse are named, so this save would not start.
      expect(validate(draft, base: from), {
        AdminBookingError.nameStoredFormat,
        AdminBookingError.phoneStoredFormat,
        AdminBookingError.emailStoredFormat,
      });

      final edited = editedBooking(base: from, draft: draft, newTotal: null);
      final changes = AdminBookingChanges.between(from, edited);

      expect(edited.customer, from.customer);
      expect(edited.customer.phone, '+995 555 00-00-00');
      expect(changes.fields, {AdminBookingField.notes});
      expect(changes.values, {'notes': 'A note.'});
    });

    test('untouched places keep their stored value exactly', () {
      final from = stored(
        changes: {
          'pickupLocation': {'id': 'other', 'text': ' Made-up Street 1 '},
          'dropoffLocation': {'id': 'other', 'text': 'Made-up Street 2 '},
        },
      );
      final draft = AdminBookingDraft.fromBooking(
        from,
      ).copyWith(language: AppLanguage.ru);

      final edited = editedBooking(base: from, draft: draft, newTotal: null);

      expect(edited.pickupLocation.text, ' Made-up Street 1 ');
      expect(edited.dropoffLocation.text, 'Made-up Street 2 ');
      expect(bookingChanges(from, edited), {AdminBookingField.language});
    });

    test('a touched part is still cleaned, and only that part', () {
      final from = stored(
        changes: {
          'notes': 'Late arrival ',
          'customer': {
            'fullName': 'Test Person',
            'phone': '+995 555 00-00-00',
            'whatsapp': false,
            'telegram': false,
            'email': 'person@example.com',
          },
          'pickupLocation': {'id': 'other', 'text': 'Made-up Street 1 '},
        },
      );
      final start = AdminBookingDraft.fromBooking(from);

      // The customer is touched (one flag): all five inputs are cleaned.
      final customer = editedBooking(
        base: from,
        draft: withInput(start, (i) => i.copyWith(whatsapp: true)),
        newTotal: null,
      );
      expect(customer.customer.phone, '+995555000000');
      expect(customer.customer.whatsapp, true);
      expect(customer.notes, 'Late arrival ');
      expect(customer.pickupLocation.text, 'Made-up Street 1 ');

      // The notes are touched: they are trimmed, the customer is not.
      final notes = editedBooking(
        base: from,
        draft: withInput(start, (i) => i.copyWith(notes: ' New note. ')),
        newTotal: null,
      );
      expect(notes.notes, 'New note.');
      expect(notes.customer.phone, '+995 555 00-00-00');

      // The place is touched: its text is trimmed.
      final place = editedBooking(
        base: from,
        draft: withInput(
          start,
          (i) => i.copyWith(
            pickupLocation: const BookingLocation.other(' Other Street 5 '),
          ),
        ),
        newTotal: null,
      );
      expect(place.pickupLocation.text, 'Other Street 5');
      expect(place.notes, 'Late arrival ');
    });

    test('a part that is not valid but was not touched does not stop '
        'editedBooking; a touched one does', () {
      final from = stored(
        changes: {
          'customer': {
            'fullName': 'Test Person',
            'phone': 'not a phone',
            'whatsapp': false,
            'telegram': false,
            'email': 'person@example.com',
          },
        },
      );
      final start = AdminBookingDraft.fromBooking(from);

      expect(
        editedBooking(
          base: from,
          draft: withInput(start, (i) => i.copyWith(notes: 'A note.')),
          newTotal: null,
        ).customer.phone,
        'not a phone',
      );
      // The validation of the whole draft is what stops such a save.
      expect(validate(start, base: from), {AdminBookingError.phoneInvalid});
      expect(
        () => editedBooking(
          base: from,
          draft: withInput(start, (i) => i.copyWith(telegram: true)),
          newTotal: null,
        ),
        throwsArgumentError,
      );
    });

    test('a draft that is not valid is refused', () {
      expect(
        () => editedBooking(
          base: base,
          draft: withInput(initial, (i) => i.copyWith(phone: 'x')),
          newTotal: null,
        ),
        throwsArgumentError,
      );
    });
  });

  group('bookingChanges and the update map', () {
    Booking edit(AdminBookingDraft draft, {double? newTotal}) =>
        editedBooking(base: base, draft: draft, newTotal: newTotal);

    test('nothing changed: no fields and an empty map', () {
      final changes = AdminBookingChanges.between(base, edit(initial));

      expect(changes.isEmpty, true);
      expect(changes.fields, isEmpty);
      expect(changes.values, isEmpty);
    });

    test('a space typed at the end of the name is no change', () {
      final typed = withInput(
        initial,
        (i) => i.copyWith(fullName: 'Test Person  '),
      );
      expect(bookingChanges(base, edit(typed)), isEmpty);
    });

    test('one changed text of the customer sends the whole customer', () {
      final changes = AdminBookingChanges.between(
        base,
        edit(withInput(initial, (i) => i.copyWith(telegram: true))),
      );

      expect(changes.fields, {AdminBookingField.customer});
      expect(changes.values, {
        'customer': {
          'fullName': 'Test Person',
          'phone': '+995555000000',
          'whatsapp': false,
          'telegram': true,
          'email': 'person@example.com',
        },
      });
    });

    test('a place is sent whole: with its text, or without one', () {
      final changes = AdminBookingChanges.between(
        base,
        edit(
          withInput(
            initial,
            (i) => i.copyWith(
              pickupLocation: const BookingLocation.other('Made-up Street 1'),
              dropoffLocation: const BookingLocation.fixed('batumi'),
            ),
          ),
        ),
      );

      expect(changes.values, {
        'pickupLocation': {'id': 'other', 'text': 'Made-up Street 1'},
        'dropoffLocation': {'id': 'batumi'},
      });
    });

    test('the extras are sent as the whole list, in the fixed order', () {
      final changes = AdminBookingChanges.between(
        base,
        edit(
          withInput(
            initial,
            (i) => i.copyWith(extras: {Extra.boosterSeat, Extra.snowChains}),
          ),
        ),
      );

      expect(changes.values, {
        'extras': ['snowChains', 'boosterSeat'],
      });
    });

    test('dates are UTC moments; car, notes, language and total are plain '
        'values', () {
      final changes = AdminBookingChanges.between(
        base,
        edit(
          withInput(
            initial.copyWith(carId: 'car-2', language: AppLanguage.ka),
            (i) => i.copyWith(
              pickup: TbilisiDateTime(2026, 1, 11, 10, 30),
              dropoff: TbilisiDateTime(2026, 1, 14, 9, 0),
              notes: 'A note.',
            ),
          ),
          newTotal: 360,
        ),
      );

      expect(changes.fields, {
        AdminBookingField.car,
        AdminBookingField.pickup,
        AdminBookingField.dropoff,
        AdminBookingField.notes,
        AdminBookingField.total,
        AdminBookingField.language,
      });
      expect(changes.values, {
        'carId': 'car-2',
        'pickupDateTime': DateTime.utc(2026, 1, 11, 6, 30),
        'dropoffDateTime': DateTime.utc(2026, 1, 14, 5),
        'notes': 'A note.',
        'totalPrice': 360.0,
        'language': 'ka',
      });
    });

    test('status, createdAt and createdBy can never be in the map', () {
      final from = stored(changes: {'createdBy': 'Made-up Staff'});
      final everything = Booking(
        id: 'other-id',
        customer: const BookingCustomer(
          fullName: 'Other Person',
          phone: '+995555111111',
          whatsapp: true,
          telegram: true,
          email: 'other@example.com',
        ),
        carId: 'car-2',
        pickup: DateTime.utc(2027, 1, 1),
        dropoff: DateTime.utc(2027, 1, 2),
        pickupLocation: const BookingLocation.fixed('batumi'),
        dropoffLocation: const BookingLocation.other('Made-up Street 1'),
        extras: const {Extra.infantSeat},
        notes: 'A note.',
        totalPrice: 1,
        language: AppLanguage.ru,
        status: BookingStatus.cancelled,
        createdAt: DateTime.utc(2020),
        createdBy: 'Somebody Else',
      );

      final changes = AdminBookingChanges.between(from, everything);

      expect(changes.fields, AdminBookingField.values.toSet());
      expect(changes.values.keys.toSet(), {
        for (final field in AdminBookingField.values) field.storedKey,
      });
      for (final key in ['status', 'createdAt', 'createdBy', 'id']) {
        expect(changes.values.containsKey(key), false, reason: key);
      }
    });

    test('only top-level fields that the rules know are sent', () {
      final map = bookingUpdateMap(base, AdminBookingField.values.toSet());
      for (final key in map.keys) {
        expect(adminBookingKeys, contains(key));
        expect(key.contains('.'), false);
      }
    });

    test('the changes cannot be altered afterwards', () {
      final changes = AdminBookingChanges.between(
        base,
        edit(initial.copyWith(carId: 'car-2')),
      );
      expect(() => changes.values['status'] = 'x', throwsUnsupportedError);
      expect(
        () => changes.fields.add(AdminBookingField.notes),
        throwsUnsupportedError,
      );
    });
  });

  group('the conflict check', () {
    final all = AdminBookingField.values.toSet();
    Map<String, dynamic> current({Map<String, dynamic> changes = const {}}) =>
        rawBooking('b1', changes: changes).data;

    test('the stored document as it was: no conflict in any part', () {
      expect(
        conflictingFields(base: base, current: current(), edited: all),
        isEmpty,
      );
    });

    test('a part that was changed elsewhere is found when it was edited', () {
      final now = current(changes: {'carId': 'car-9', 'notes': 'Changed.'});

      expect(
        conflictingFields(
          base: base,
          current: now,
          edited: {AdminBookingField.car, AdminBookingField.language},
        ),
        {AdminBookingField.car},
      );
      expect(conflictingFields(base: base, current: now, edited: all), {
        AdminBookingField.car,
        AdminBookingField.notes,
      });
    });

    test('a part that was not edited is not looked at', () {
      final now = current(changes: {'carId': 'car-9'});

      expect(
        conflictingFields(
          base: base,
          current: now,
          edited: {AdminBookingField.notes},
        ),
        isEmpty,
      );
    });

    test('a status change made elsewhere is never a conflict', () {
      expect(
        conflictingFields(
          base: base,
          current: current(changes: {'status': 'cancelled'}),
          edited: all,
        ),
        isEmpty,
      );
    });

    test('microseconds cannot make a false conflict', () {
      // The edit started from a document read with microseconds...
      final micro = DateTime.utc(2026, 1, 10, 14, 0, 0, 123, 456);
      final from = stored(changes: {'pickupDateTime': micro});
      // ...and the same moment comes back with milliseconds only, as a
      // browser delivers it, or the other way round.
      final milli = DateTime.utc(2026, 1, 10, 14, 0, 0, 123);
      final dates = {AdminBookingField.pickup, AdminBookingField.dropoff};

      expect(micro == milli, false);
      expect(
        conflictingFields(
          base: from,
          current: current(changes: {'pickupDateTime': milli}),
          edited: dates,
        ),
        isEmpty,
      );
      expect(
        conflictingFields(
          base: stored(changes: {'pickupDateTime': milli}),
          current: current(changes: {'pickupDateTime': micro}),
          edited: dates,
        ),
        isEmpty,
      );
      expect(
        conflictingFields(
          base: from,
          current: current(changes: {'pickupDateTime': micro}),
          edited: dates,
        ),
        isEmpty,
      );
    });

    test('one millisecond of difference is a real change', () {
      final from = stored(
        changes: {'pickupDateTime': DateTime.utc(2026, 1, 10, 14, 0, 0, 123)},
      );
      expect(
        conflictingFields(
          base: from,
          current: current(
            changes: {
              'pickupDateTime': DateTime.utc(2026, 1, 10, 14, 0, 0, 124),
            },
          ),
          edited: {AdminBookingField.pickup},
        ),
        {AdminBookingField.pickup},
      );
    });

    test('a date is compared as a moment, whatever its time zone flag', () {
      final local = DateTime.utc(2026, 1, 10, 14).toLocal();
      expect(
        conflictingFields(
          base: base,
          current: current(changes: {'pickupDateTime': local}),
          edited: {AdminBookingField.pickup},
        ),
        isEmpty,
      );
    });

    test('maps are compared deeply', () {
      Map<String, dynamic> customer({bool telegram = false}) => {
        'fullName': 'Test Person',
        'phone': '+995555000000',
        'whatsapp': false,
        'telegram': telegram,
        'email': 'person@example.com',
      };
      const edited = {
        AdminBookingField.customer,
        AdminBookingField.pickupLocation,
      };

      expect(
        conflictingFields(
          base: base,
          current: current(changes: {'customer': customer()}),
          edited: edited,
        ),
        isEmpty,
      );
      expect(
        conflictingFields(
          base: base,
          current: current(changes: {'customer': customer(telegram: true)}),
          edited: edited,
        ),
        {AdminBookingField.customer},
      );
      expect(
        conflictingFields(
          base: base,
          current: current(
            changes: {
              'pickupLocation': {'id': 'other', 'text': 'Made-up Street 1'},
            },
          ),
          edited: edited,
        ),
        {AdminBookingField.pickupLocation},
      );
    });

    test('the extras are compared as a set: their stored order has no '
        'meaning', () {
      final from = stored(
        changes: {
          'extras': ['boosterSeat', 'snowChains'],
        },
      );
      const edited = {AdminBookingField.extras};

      expect(
        conflictingFields(
          base: from,
          current: current(
            changes: {
              'extras': ['snowChains', 'boosterSeat'],
            },
          ),
          edited: edited,
        ),
        isEmpty,
      );
      expect(
        conflictingFields(
          base: from,
          current: current(
            changes: {
              'extras': ['snowChains'],
            },
          ),
          edited: edited,
        ),
        {AdminBookingField.extras},
      );
    });

    test('225 and 225.0 are the same total', () {
      const edited = {AdminBookingField.total};
      expect(
        conflictingFields(
          base: base,
          current: current(changes: {'totalPrice': 225.0}),
          edited: edited,
        ),
        isEmpty,
      );
      expect(
        conflictingFields(
          base: base,
          current: current(changes: {'totalPrice': 225.5}),
          edited: edited,
        ),
        {AdminBookingField.total},
      );
    });

    test('a part that is gone from the stored document is a conflict', () {
      final now = current()..remove('notes');
      expect(
        conflictingFields(
          base: base,
          current: now,
          edited: {AdminBookingField.notes},
        ),
        {AdminBookingField.notes},
      );
    });

    test('normalizedBookingValue: dates, numbers, maps and lists', () {
      final a = normalizedBookingValue({
        'when': DateTime.utc(2026, 1, 10, 14, 0, 0, 5, 999),
        'list': [1, 2.0, 'x'],
        'deep': {'n': 3},
      });
      final b = normalizedBookingValue({
        'when': DateTime.utc(2026, 1, 10, 14, 0, 0, 5),
        'list': [1.0, 2, 'x'],
        'deep': {'n': 3.0},
      });

      expect(a, b);
      // A date never equals a number with the same milliseconds.
      final date = DateTime.utc(2026);
      expect(
        normalizedBookingValue(date) ==
            normalizedBookingValue(date.millisecondsSinceEpoch),
        false,
      );
    });
  });

  group('the conflict check when the total is written', () {
    Map<String, dynamic> current({Map<String, dynamic> changes = const {}}) =>
        rawBooking('b1', changes: changes).data;

    // The admin edited the two dates and chose "use the new total".
    const datesAndTotal = {
      AdminBookingField.pickup,
      AdminBookingField.dropoff,
      AdminBookingField.total,
    };
    // The same edit with "keep the stored total".
    const datesOnly = {AdminBookingField.pickup, AdminBookingField.dropoff};

    test('fieldsToCompare: with the total, also car, dates and extras; '
        'without it, exactly the edited parts', () {
      expect(priceFields, {
        AdminBookingField.car,
        AdminBookingField.pickup,
        AdminBookingField.dropoff,
        AdminBookingField.extras,
      });
      expect(fieldsToCompare({AdminBookingField.total}), {
        AdminBookingField.total,
        ...priceFields,
      });
      expect(
        fieldsToCompare({AdminBookingField.total, AdminBookingField.notes}),
        {AdminBookingField.total, AdminBookingField.notes, ...priceFields},
      );
      expect(fieldsToCompare(datesOnly), datesOnly);
      expect(fieldsToCompare({AdminBookingField.notes}), {
        AdminBookingField.notes,
      });
      expect(fieldsToCompare(const {}), isEmpty);
    });

    test('dates edited, "use the new total", the car changed elsewhere: a '
        'conflict that names the car', () {
      expect(
        conflictingFields(
          base: base,
          current: current(changes: {'carId': 'car-9'}),
          edited: datesAndTotal,
        ),
        {AdminBookingField.car},
      );
    });

    test('the same with "keep the stored total": no conflict', () {
      expect(
        conflictingFields(
          base: base,
          current: current(changes: {'carId': 'car-9'}),
          edited: datesOnly,
        ),
        isEmpty,
      );
    });

    test('the extras changed elsewhere: a conflict only when the total is '
        'written', () {
      final now = current(
        changes: {
          'extras': ['childSeat'],
        },
      );
      expect(
        conflictingFields(base: base, current: now, edited: datesAndTotal),
        {AdminBookingField.extras},
      );
      expect(
        conflictingFields(base: base, current: now, edited: datesOnly),
        isEmpty,
      );
    });

    test('a date the admin did not edit, changed elsewhere, is a conflict '
        'when the total is written', () {
      final now = current(
        changes: {'dropoffDateTime': DateTime.utc(2026, 1, 18, 16)},
      );
      const carAndTotal = {AdminBookingField.car, AdminBookingField.total};

      expect(conflictingFields(base: base, current: now, edited: carAndTotal), {
        AdminBookingField.dropoff,
      });
      expect(
        conflictingFields(
          base: base,
          current: now,
          edited: {AdminBookingField.car},
        ),
        isEmpty,
      );
    });

    test('the same car and dates that differ only in microseconds: no '
        'conflict', () {
      final micro = DateTime.utc(2026, 1, 10, 14, 0, 0, 123, 456);
      final milli = DateTime.utc(2026, 1, 10, 14, 0, 0, 123);
      final from = stored(changes: {'pickupDateTime': micro});

      for (final edited in [
        datesAndTotal,
        {AdminBookingField.car, AdminBookingField.total},
        {AdminBookingField.total},
      ]) {
        expect(
          conflictingFields(
            base: from,
            current: current(changes: {'pickupDateTime': milli}),
            edited: edited,
          ),
          isEmpty,
        );
        expect(
          conflictingFields(
            base: stored(changes: {'pickupDateTime': milli}),
            current: current(changes: {'pickupDateTime': micro}),
            edited: edited,
          ),
          isEmpty,
        );
      }
    });

    test('a notes-only edit compares no price field at all', () {
      // Everything the price depends on was changed elsewhere.
      final now = current(
        changes: {
          'carId': 'car-9',
          'pickupDateTime': DateTime.utc(2026, 2, 1, 10),
          'dropoffDateTime': DateTime.utc(2026, 2, 9, 10),
          'extras': ['snowChains'],
          'totalPrice': 999,
        },
      );

      expect(
        conflictingFields(
          base: base,
          current: now,
          edited: {AdminBookingField.notes},
        ),
        isEmpty,
      );
    });

    test('a total changed elsewhere is a conflict when the total is '
        'written', () {
      expect(
        conflictingFields(
          base: base,
          current: current(changes: {'totalPrice': 300}),
          edited: datesAndTotal,
        ),
        {AdminBookingField.total},
      );
    });
  });

  group('a half-filled form never throws', () {
    AdminBookingDraft draftWith({
      TbilisiDateTime? pickup,
      TbilisiDateTime? dropoff,
      String carId = 'car-1',
      bool noPlaces = false,
    }) => AdminBookingDraft(
      input: BookingFormInput(
        fullName: '',
        phone: 'x',
        email: '',
        pickup: pickup,
        dropoff: dropoff,
        pickupLocation: noPlaces ? null : initial.input.pickupLocation,
        dropoffLocation: noPlaces ? null : initial.input.dropoffLocation,
        extras: const {Extra.childSeat},
      ),
      carId: carId,
      language: AppLanguage.en,
    );
    final start = TbilisiDateTime(2026, 1, 10, 18, 0);
    final drafts = {
      'no dates': draftWith(),
      'no pickup': draftWith(dropoff: start),
      'no drop-off': draftWith(pickup: start),
      'drop-off before pickup': draftWith(
        pickup: start,
        dropoff: TbilisiDateTime(2026, 1, 9, 18, 0),
      ),
      'drop-off at the pickup': draftWith(pickup: start, dropoff: start),
      'longer than 365 days': draftWith(
        pickup: start,
        dropoff: TbilisiDateTime(2028, 1, 10, 18, 0),
      ),
      'no places': draftWith(noPlaces: true),
      'a car that is not in the list': draftWith(carId: 'gone-car'),
      'no car': draftWith(carId: ''),
    };

    for (final entry in drafts.entries) {
      test(entry.key, () {
        final draft = entry.value;
        for (final car in [testCar(), null]) {
          for (final extrasPrices in [prices, null]) {
            final totals = compareTotals(
              base: base,
              draft: draft,
              car: car,
              extrasPrices: extrasPrices,
            );
            for (final choice in [null, ...AdminTotalChoice.values]) {
              totalErrors(totals, choice);
              totalToSave(totals, choice);
            }
            expect(totals.storedCents, 22500);
          }
        }
        expect(validate(draft), isNotEmpty);
        expect(draftChanges(initial, draft), isNotEmpty);
        isPickupInPast(draft, now: DateTime.utc(2026));
      });
    }

    test('dates that cannot be priced give no new total, so "use the new '
        'total" is not possible', () {
      final totals = compareTotals(
        base: base,
        draft: drafts['drop-off before pickup']!,
        car: testCar(),
        extrasPrices: prices,
      );

      expect(totals.newPrice, isNull);
      expect(totals.canUseNew, false);
      expect(totalToSave(totals, AdminTotalChoice.useNew), isNull);
    });
  });

  group('save failures', () {
    test('the Firestore codes map as for a status change', () {
      expect(
        saveFailureFromCode('unavailable'),
        AdminBookingSaveFailure.noConnection,
      );
      expect(
        saveFailureFromCode('deadline-exceeded'),
        AdminBookingSaveFailure.noConnection,
      );
      expect(
        saveFailureFromCode('permission-denied'),
        AdminBookingSaveFailure.refused,
      );
      expect(
        saveFailureFromCode('not-found'),
        AdminBookingSaveFailure.bookingMissing,
      );
      expect(saveFailureFromCode('aborted'), AdminBookingSaveFailure.unknown);
    });

    test('each failure has its own notice, never "saved" or "no answer"', () {
      final notices = {
        for (final failure in AdminBookingSaveFailure.values)
          noticeForSaveFailure(failure),
      };

      expect(notices, hasLength(AdminBookingSaveFailure.values.length));
      expect(notices, isNot(contains(AdminBookingSaveNotice.saved)));
      expect(notices, isNot(contains(AdminBookingSaveNotice.noAnswer)));
      for (final failure in AdminBookingSaveFailure.values) {
        expect(noticeForSaveFailure(failure).name, failure.name);
      }
    });

    test('the exceptions carry no Firestore type and no customer data', () {
      expect(
        const AdminBookingSaveException(
          AdminBookingSaveFailure.conflict,
          fields: ['carId'],
        ).toString(),
        'AdminBookingSaveException(conflict)',
      );
      expect(
        const AdminBookingSaveNoAnswer().toString(),
        'AdminBookingSaveNoAnswer',
      );
    });
  });
}
