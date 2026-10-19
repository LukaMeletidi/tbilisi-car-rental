import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tbilisi_car_rental/core/data/server_answer.dart';
import 'package:tbilisi_car_rental/core/models/extras_prices.dart';
import 'package:tbilisi_car_rental/core/models/pickup_location.dart';
import 'package:tbilisi_car_rental/features/settings/domain/company_info.dart';
import 'package:tbilisi_car_rental/features/settings/domain/settings_write.dart';

/// Access to the "settings" collection. A document that is invalid, or
/// that the SERVER says does not exist, makes the stream report a
/// [FormatException]; it never falls back to default values. The one
/// exception is settings/company: when the server says it does not exist,
/// [watchCompany] gives null ("not filled in yet").
///
/// A document that is missing only because the server has not answered yet
/// is something else: it is waited out, and after [serverAnswerWait] the
/// stream reports a [NoServerAnswerException]. Metadata changes are
/// included, so that the answer of the server always arrives.
///
/// The admin saves settings/extras and settings/company (step 6.4). Every
/// save runs in a transaction, tried once, with [settingsWriteTimeout]: a
/// transaction is never kept in the offline queue, so without a connection
/// it fails instead of being sent later. A [SettingsWriteNoAnswer] does NOT
/// mean "not saved". Nothing is logged except, in debug builds, the type of
/// an unexpected error (mapSettingsWriteError).
class SettingsRepository {
  SettingsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Live per-day prices of the extras, from settings/extras.
  Stream<ExtrasPrices> watchExtrasPrices() {
    return extrasPricesFrom(_answers('extras'));
  }

  /// Live list of the fixed pickup and drop-off places, from
  /// settings/locations, in the order of the document.
  Stream<List<PickupLocation>> watchPickupLocations() {
    return pickupLocationsFrom(_answers('locations'));
  }

  /// The company information, live, from settings/company. null when the
  /// SERVER says the document does not exist ("not filled in yet"). The
  /// same waiting as the other settings reads; an invalid document makes
  /// the stream report a [FormatException].
  Stream<CompanyInfo?> watchCompany() {
    return companyInfoFrom(_answers('company'));
  }

  /// Saves the four prices as the WHOLE settings/extras document (set) in
  /// a transaction, tried once, with [timeout]. [base] is what the form
  /// loaded (decideSettingsSave). Throws a [SettingsWriteException] when it
  /// certainly did not happen, and a [SettingsWriteNoAnswer] when the
  /// server did not answer in time.
  Future<void> saveExtrasPrices(
    ExtrasPrices prices, {
    required ExtrasPrices base,
    Duration timeout = settingsWriteTimeout,
  }) => _save<ExtrasPrices>(
    'extras',
    target: prices,
    base: base,
    document: extrasDocument(prices),
    read: ExtrasPrices.fromMap,
    timeout: timeout,
  );

  /// Saves [company] as the WHOLE settings/company document (set), as
  /// [saveExtrasPrices]. [base] is null when the form started from "does
  /// not exist": the first save then expects no document.
  Future<void> saveCompany(
    CompanyInfo company, {
    required CompanyInfo? base,
    Duration timeout = settingsWriteTimeout,
  }) => _save<CompanyInfo>(
    'company',
    target: company,
    base: base,
    document: company.toMap(),
    read: CompanyInfo.fromMap,
    timeout: timeout,
  );

  Future<void> _save<T extends Object>(
    String id, {
    required T target,
    required T? base,
    required Map<String, dynamic> document,
    required T Function(Map<String, dynamic> data) read,
    required Duration timeout,
  }) async {
    final reference = _firestore.collection('settings').doc(id);
    final SettingsSaveDecision decision;
    try {
      decision = await _firestore
          .runTransaction<SettingsSaveDecision>(
            (transaction) async {
              final snapshot = await transaction.get(reference);
              final data = snapshot.data();
              T? stored;
              if (data != null) {
                try {
                  stored = read(data);
                } on FormatException {
                  stored = null;
                }
              }
              final decision = decideSettingsSave<T>(
                storedExists: snapshot.exists,
                stored: stored,
                base: base,
                target: target,
              );
              if (decision == SettingsSaveDecision.write) {
                transaction.set(reference, document);
              }
              return decision;
            },
            timeout: timeout,
            maxAttempts: 1,
          )
          // As for the cars: the plugin's own timeout does not cover every
          // platform and every stage of the transaction.
          .timeout(timeout);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(mapSettingsWriteError(error), stackTrace);
    }
    if (decision == SettingsSaveDecision.changedElsewhere) {
      throw const SettingsWriteException(SettingsWriteFailure.changedElsewhere);
    }
  }

  Stream<DocumentAnswer> _answers(String document) {
    return _firestore
        .collection('settings')
        .doc(document)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) =>
              (data: snapshot.data(), fromCache: snapshot.metadata.isFromCache),
        );
  }
}

/// The prices of the extras for each answer of the live read of
/// settings/extras; see [SettingsRepository] for what a missing document
/// means.
Stream<ExtrasPrices> extrasPricesFrom(
  Stream<DocumentAnswer> answers, {
  Duration wait = serverAnswerWait,
}) {
  return waitForServerAnswer(
    answers,
    isEmpty: (answer) => answer.data == null,
    fromCache: (answer) => answer.fromCache,
    read: (answer) => ExtrasPrices.fromMap(answer.data),
    wait: wait,
  );
}

/// The fixed places for each answer of the live read of
/// settings/locations; see [SettingsRepository] for what a missing
/// document means.
Stream<List<PickupLocation>> pickupLocationsFrom(
  Stream<DocumentAnswer> answers, {
  Duration wait = serverAnswerWait,
}) {
  return waitForServerAnswer(
    answers,
    isEmpty: (answer) => answer.data == null,
    fromCache: (answer) => answer.fromCache,
    read: (answer) => parsePickupLocations(answer.data),
    wait: wait,
  );
}

/// The company information for each answer of the live read of
/// settings/company: null when the SERVER says it does not exist; see
/// [SettingsRepository] for what an answer from memory means.
Stream<CompanyInfo?> companyInfoFrom(
  Stream<DocumentAnswer> answers, {
  Duration wait = serverAnswerWait,
}) {
  return waitForServerAnswer(
    answers,
    isEmpty: (answer) => answer.data == null,
    fromCache: (answer) => answer.fromCache,
    read: (answer) {
      final data = answer.data;
      return data == null ? null : CompanyInfo.fromMap(data);
    },
    wait: wait,
  );
}

/// Turns an error of a settings save into what the caller handles: no
/// answer in time -> [SettingsWriteNoAnswer]; a Firestore error -> its
/// reason; our own exceptions stay; anything else (also the raw offline
/// error of Chrome, which is not a FirebaseException) -> unknown. An error
/// that ends as "unknown" prints its type (and for a FirebaseException only
/// its code) in debug builds; never a message or a value.
Object mapSettingsWriteError(Object error) {
  if (error is SettingsWriteException || error is SettingsWriteNoAnswer) {
    return error;
  }
  if (error is TimeoutException) return const SettingsWriteNoAnswer();
  if (error is FirebaseException) {
    final failure = settingsWriteFailureFromCode(error.code);
    if (failure == SettingsWriteFailure.unknown && kDebugMode) {
      debugPrint(
        'An unexpected error in a settings save: '
        'FirebaseException(code: ${error.code})',
      );
    }
    return SettingsWriteException(failure);
  }
  if (kDebugMode) {
    debugPrint('An unexpected error in a settings save: ${error.runtimeType}');
  }
  return const SettingsWriteException(SettingsWriteFailure.unknown);
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(FirebaseFirestore.instance),
);
