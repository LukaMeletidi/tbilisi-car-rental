import 'dart:async';

import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/features/settings/data/settings_repository.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';

/// Stands in for the settings repository in tests. Nothing here contacts
/// Firebase. The live reads are faked with stream controllers; the saves
/// record their calls and answer as the test says.
class FakeSettingsRepository implements SettingsRepository {
  final _extrasControllers = <StreamController<ExtrasPrices>>[];
  final _locationsControllers = <StreamController<List<PickupLocation>>>[];
  final _companyControllers = <StreamController<CompanyInfo?>>[];

  /// How many reads of settings/company were started.
  var companyReads = 0;

  /// How many reads of settings/company are being listened to right now.
  var activeCompanyListeners = 0;

  /// How many reads of settings/extras are being listened to right now.
  var activeExtrasListeners = 0;

  /// The calls of saveExtrasPrices: the prices to save and their base.
  final extrasSaves = <({ExtrasPrices prices, ExtrasPrices base})>[];

  /// The calls of saveCompany: the company to save and its base.
  final companySaves = <({CompanyInfo company, CompanyInfo? base})>[];

  /// What a save does: null returns normally (saved); otherwise it throws
  /// this error (SettingsWriteNoAnswer or a SettingsWriteException).
  Object? saveError;

  /// When set, a save waits for it before it answers.
  Completer<void>? writeGate;

  /// Makes the newest read of settings/extras answer with [prices].
  void emitExtras(ExtrasPrices prices) => _extrasControllers.last.add(prices);

  /// Makes the newest read of settings/extras fail with [error].
  void failExtras(Object error) => _extrasControllers.last.addError(error);

  /// Makes the newest read of settings/locations answer with [locations].
  void emitLocations(List<PickupLocation> locations) =>
      _locationsControllers.last.add(locations);

  /// Makes the newest read of settings/company answer with [company]
  /// (null: the server says it does not exist).
  void emitCompany(CompanyInfo? company) =>
      _companyControllers.last.add(company);

  /// Makes the newest read of settings/company fail with [error].
  void failCompany(Object error) => _companyControllers.last.addError(error);

  @override
  Stream<ExtrasPrices> watchExtrasPrices() {
    final controller = StreamController<ExtrasPrices>(
      onListen: () => activeExtrasListeners += 1,
      onCancel: () => activeExtrasListeners -= 1,
    );
    _extrasControllers.add(controller);
    return controller.stream;
  }

  @override
  Stream<List<PickupLocation>> watchPickupLocations() {
    final controller = StreamController<List<PickupLocation>>();
    _locationsControllers.add(controller);
    return controller.stream;
  }

  @override
  Stream<CompanyInfo?> watchCompany() {
    companyReads += 1;
    final controller = StreamController<CompanyInfo?>(
      onListen: () => activeCompanyListeners += 1,
      onCancel: () => activeCompanyListeners -= 1,
    );
    _companyControllers.add(controller);
    return controller.stream;
  }

  @override
  Future<void> saveExtrasPrices(
    ExtrasPrices prices, {
    required ExtrasPrices base,
    Duration timeout = Duration.zero,
  }) async {
    extrasSaves.add((prices: prices, base: base));
    await _answer();
  }

  @override
  Future<void> saveCompany(
    CompanyInfo company, {
    required CompanyInfo? base,
    Duration timeout = Duration.zero,
  }) async {
    companySaves.add((company: company, base: base));
    await _answer();
  }

  Future<void> _answer() async {
    await writeGate?.future;
    final error = saveError;
    if (error != null) throw error;
  }
}
