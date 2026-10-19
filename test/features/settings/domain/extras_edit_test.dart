import 'package:flutter_test/flutter_test.dart';

import 'package:tbilisi_car_rental/core/models/extra.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_edit.dart';
import 'package:tbilisi_car_rental/features/settings/domain/extras_price_input.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';

/// Made-up sample prices; not the real ones.
ExtrasPrices prices({
  num snowChains = 7,
  num childSeat = 4.5,
  num infantSeat = 0,
  num boosterSeat = 3,
}) => ExtrasPrices.fromMap({
  'pricesPerDay': {
    'snowChains': snowChains,
    'childSeat': childSeat,
    'infantSeat': infantSeat,
    'boosterSeat': boosterSeat,
  },
});

ExtrasDraft draftWith(Extra extra, String text) => {
  ...extrasDraftOf(prices()),
  extra: text,
};

void main() {
  group('extrasDraftOf', () {
    test('whole prices without decimals, others as they are', () {
      expect(extrasDraftOf(prices()), {
        Extra.snowChains: '7',
        Extra.childSeat: '4.5',
        Extra.infantSeat: '0',
        Extra.boosterSeat: '3',
      });
    });

    test('a stored price with more decimals is shown in full', () {
      expect(extrasDraftOf(prices(childSeat: 4.555))[Extra.childSeat], '4.555');
    });

    test('cannot be changed', () {
      expect(
        () => extrasDraftOf(prices())[Extra.snowChains] = '1',
        throwsUnsupportedError,
      );
    });
  });

  group('extrasDraftProblems', () {
    test('the form as it opens has none', () {
      expect(extrasDraftProblems(extrasDraftOf(prices())), isEmpty);
    });

    test('each problem belongs to its extra', () {
      final draft = {
        Extra.snowChains: '',
        Extra.childSeat: 'abc',
        Extra.infantSeat: '100.01',
        Extra.boosterSeat: '5',
      };
      expect(extrasDraftProblems(draft), {
        Extra.snowChains: ExtraPriceProblem.required,
        Extra.childSeat: ExtraPriceProblem.invalid,
        Extra.infantSeat: ExtraPriceProblem.tooHigh,
      });
    });

    test('a missing extra counts as nothing typed', () {
      expect(extrasDraftProblems({Extra.snowChains: '5'}).keys, {
        Extra.childSeat,
        Extra.infantSeat,
        Extra.boosterSeat,
      });
    });

    test('stored prices that a console edit made invalid show problems', () {
      expect(
        extrasDraftProblems(
          extrasDraftOf(prices(childSeat: 4.555, boosterSeat: 150)),
        ),
        {
          Extra.childSeat: ExtraPriceProblem.invalid,
          Extra.boosterSeat: ExtraPriceProblem.tooHigh,
        },
      );
    });
  });

  group('extrasDraftChanged', () {
    test('the form as it opens is no change', () {
      expect(extrasDraftChanged(prices(), extrasDraftOf(prices())), false);
    });

    test('the same value written differently is no change', () {
      for (final text in ['7.00', '7,0', ' 7 ']) {
        expect(
          extrasDraftChanged(prices(), draftWith(Extra.snowChains, text)),
          false,
          reason: text,
        );
      }
    });

    test('another value is a change', () {
      expect(
        extrasDraftChanged(prices(), draftWith(Extra.snowChains, '8')),
        true,
      );
    });

    test('a text with a problem is a change', () {
      expect(
        extrasDraftChanged(prices(), draftWith(Extra.snowChains, '')),
        true,
      );
    });

    test('an untouched invalid stored price is no change; fixing it is', () {
      final stored = prices(childSeat: 4.555);
      expect(extrasDraftChanged(stored, extrasDraftOf(stored)), false);
      expect(
        extrasDraftChanged(stored, {
          ...extrasDraftOf(stored),
          Extra.childSeat: '4.56',
        }),
        true,
      );
    });
  });

  test('every save failure has its notice', () {
    expect(
      noticeForSettingsWriteFailure(SettingsWriteFailure.noConnection),
      ExtrasSaveNotice.noConnection,
    );
    expect(
      noticeForSettingsWriteFailure(SettingsWriteFailure.refused),
      ExtrasSaveNotice.refused,
    );
    expect(
      noticeForSettingsWriteFailure(SettingsWriteFailure.changedElsewhere),
      ExtrasSaveNotice.changedElsewhere,
    );
    expect(
      noticeForSettingsWriteFailure(SettingsWriteFailure.unknown),
      ExtrasSaveNotice.unknown,
    );
  });
}
