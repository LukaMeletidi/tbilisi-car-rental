import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_detail.dart';
import 'package:tbilisi_car_rental/features/admin/domain/admin_booking_edit.dart';
import 'package:tbilisi_car_rental/features/admin/presentation/admin_texts.dart';
import 'package:tbilisi_car_rental/features/booking/domain/booking_limits.dart';

void main() {
  group('the texts of the form errors', () {
    test('every error has a text that ends like a sentence', () {
      for (final error in AdminBookingError.values) {
        final text = adminBookingErrorText(error);
        expect(text, isNotEmpty, reason: error.name);
        expect(text.endsWith('.'), true, reason: error.name);
      }
    });

    test('the numbers in the texts are the limits', () {
      expect(
        adminBookingErrorText(AdminBookingError.nameTooLong),
        contains('$bookingNameMaxLength characters'),
      );
      expect(
        adminBookingErrorText(AdminBookingError.rentalTooLong),
        contains('$bookingMaxRentalDays days'),
      );
      expect(
        adminBookingErrorText(AdminBookingError.pickupLocationTextTooLong),
        contains('$bookingOtherLocationMaxLength characters'),
      );
      expect(
        adminBookingErrorText(AdminBookingError.notesTooLong),
        contains('$bookingNotesMaxLength characters'),
      );
    });

    test('a stored value in a format the rules refuse names its part', () {
      const parts = {
        AdminBookingError.nameStoredFormat: 'The name',
        AdminBookingError.phoneStoredFormat: 'The phone number',
        AdminBookingError.emailStoredFormat: 'The e-mail address',
        AdminBookingError.pickupLocationStoredFormat: 'The pickup place',
        AdminBookingError.dropoffLocationStoredFormat: 'The drop-off place',
      };
      for (final entry in parts.entries) {
        expect(
          adminBookingErrorText(entry.key),
          '${entry.value} is stored in a format the app does not accept. '
          'Edit it to correct it.',
        );
      }
    });

    test('a few texts, word for word', () {
      expect(
        adminBookingErrorText(AdminBookingError.carMissing),
        'This car no longer exists. Choose another car.',
      );
      expect(
        adminBookingErrorText(AdminBookingError.totalChoiceRequired),
        'Choose which total to save.',
      );
      expect(
        adminBookingErrorText(AdminBookingError.dropoffNotAfterPickup),
        'The drop-off must be after the pickup.',
      );
    });
  });

  group('the texts after a save', () {
    test('one "Saved"; "no answer" is neither saved nor "not saved"; the '
        'conflict has its own words; the rest say "Not saved."', () {
      final texts = {
        for (final notice in AdminBookingSaveNotice.values)
          notice: adminSaveNoticeText(notice),
      };

      expect(texts.values.toSet(), hasLength(texts.length));
      expect(texts[AdminBookingSaveNotice.saved], 'Saved');
      expect(
        texts[AdminBookingSaveNotice.noAnswer],
        isNot(contains('Not saved')),
      );
      expect(
        texts[AdminBookingSaveNotice.noAnswer],
        startsWith('No answer from the server.'),
      );
      for (final notice in AdminBookingSaveNotice.values) {
        if (const [
          AdminBookingSaveNotice.saved,
          AdminBookingSaveNotice.noAnswer,
          AdminBookingSaveNotice.conflict,
        ].contains(notice)) {
          continue;
        }
        expect(texts[notice], startsWith('Not saved. '), reason: notice.name);
      }
    });

    test('the four texts shared with the status change are the same', () {
      const shared = {
        AdminBookingSaveNotice.noConnection:
            AdminStatusChangeNotice.noConnection,
        AdminBookingSaveNotice.refused: AdminStatusChangeNotice.refused,
        AdminBookingSaveNotice.bookingMissing:
            AdminStatusChangeNotice.bookingMissing,
        AdminBookingSaveNotice.unknown: AdminStatusChangeNotice.unknown,
        AdminBookingSaveNotice.noCreatedAt: AdminStatusChangeNotice.noCreatedAt,
      };
      for (final entry in shared.entries) {
        expect(
          adminSaveNoticeText(entry.key),
          adminStatusNoticeText(entry.value),
        );
      }
      expect(
        adminSaveNoticeText(
          AdminBookingSaveNotice.unknownFields,
          fields: ['zzTest'],
        ),
        adminStatusNoticeText(
          AdminStatusChangeNotice.unknownFields,
          fields: ['zzTest'],
        ),
      );
    });

    test('unknown fields are named: one, several, or none known', () {
      expect(
        adminSaveNoticeText(
          AdminBookingSaveNotice.unknownFields,
          fields: ['zzTest'],
        ),
        'Not saved. This booking has a field the app does not know: zzTest. '
        'Remove it in the Firebase console.',
      );
      expect(
        adminUnknownFieldsText(['updatedAt', 'zzTest']),
        'This booking has fields the app does not know: updatedAt, zzTest. '
        'Remove them in the Firebase console.',
      );
      expect(
        adminUnknownFieldsText(const []),
        'This booking has a field the app does not know. '
        'Remove it in the Firebase console.',
      );
    });

    test('no creation date', () {
      expect(
        adminSaveNoticeText(AdminBookingSaveNotice.noCreatedAt),
        'Not saved. This booking has no creation date and cannot be changed '
        'from the app.',
      );
    });

    test('the car is gone', () {
      expect(
        adminSaveNoticeText(AdminBookingSaveNotice.carMissing),
        'Not saved. This car no longer exists. Choose another car.',
      );
    });

    test('a stored value in a form the rules refuse: one sentence for '
        'each part, in the order of the form; a general one when no part '
        'is known', () {
      expect(
        adminStatusNoticeText(
          AdminStatusChangeNotice.storedFormat,
          fields: ['phoneStoredFormat'],
        ),
        'Not saved. The phone number is stored in a format the app does '
        'not accept. Edit it to correct it.',
      );
      expect(
        adminStoredFormatNoticeText([
          'emailStoredFormat',
          'nameStoredFormat',
          'somethingElse',
        ]),
        'The name is stored in a format the app does not accept. Edit it '
        'to correct it. The e-mail address is stored in a format the app '
        'does not accept. Edit it to correct it.',
      );
      expect(
        adminStoredFormatNoticeText(const []),
        'A value of this booking is stored in a format the app does not '
        'accept. Edit it to correct it.',
      );
      expect(
        adminSaveNoticeText(
          AdminBookingSaveNotice.storedFormat,
          fields: ['phoneStoredFormat'],
        ),
        adminStatusNoticeText(
          AdminStatusChangeNotice.storedFormat,
          fields: ['phoneStoredFormat'],
        ),
      );
    });

    test('the banner before a save names the parts in words', () {
      expect(
        adminChangedElsewhereBanner(['carId', 'notes']),
        'This booking was changed elsewhere (car, notes). '
        'Saving will be refused.',
      );
    });

    test('the texts of the form: cars, places, extras and totals', () {
      expect(
        adminCarHidden('Toyota Prius, 2019'),
        'Toyota Prius, 2019 (hidden)',
      );
      expect(adminCarNotFound('gone-car'), 'gone-car (not found)');
      expect(
        adminPlaceNotInList('oldPlace'),
        'oldPlace (not in the list any more)',
      );
      expect(
        adminExtraWithPrice(Extra.childSeat, 5),
        'Child seat · \$5 per day',
      );
      expect(adminExtraWithPrice(Extra.childSeat, null), 'Child seat');
      expect(adminStoredTotal(1, 45), 'Stored total: 1 day · \$45');
      expect(adminKeepStoredTotal(225), 'Keep the stored total (\$225)');
      expect(adminUseNewTotal(360.5), 'Use the new total (\$360.50)');
      expect(adminEditTooltip, 'Edit');
      expect(adminDiscardTitle, 'Discard your changes?');
      expect(adminKeepEditing, 'Keep editing');
      expect(adminDiscard, 'Discard');
      expect(adminLoadCurrent, 'Load the current booking');
    });

    test('a conflict names the parts in words', () {
      expect(
        adminSaveNoticeText(
          AdminBookingSaveNotice.conflict,
          fields: ['carId', 'pickupDateTime'],
        ),
        'This booking was changed elsewhere (car, pickup time). '
        'Your changes were not saved.',
      );
      expect(
        adminSaveNoticeText(AdminBookingSaveNotice.conflict),
        'This booking was changed elsewhere. Your changes were not saved.',
      );
    });

    test('every editable part has a name in words', () {
      final names = {
        for (final field in AdminBookingField.values)
          adminFieldName(field.storedKey),
      };
      expect(names, hasLength(AdminBookingField.values.length));
      for (final field in AdminBookingField.values) {
        expect(
          adminFieldName(field.storedKey) == field.storedKey &&
              field.storedKey != 'notes' &&
              field.storedKey != 'extras' &&
              field.storedKey != 'language' &&
              field.storedKey != 'customer',
          false,
          reason: field.name,
        );
      }
      expect(adminFieldName('somethingElse'), 'somethingElse');
    });
  });
}
