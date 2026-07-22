import 'dart:async';

import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around the two Plaid Edge Functions plus the plaid_flutter
/// Link SDK. Secrets stay server-side (see supabase/functions/plaid-*) — this
/// class only ever sees a short-lived link token and a public token.
class PlaidService {
  PlaidService(this._client);

  final SupabaseClient _client;

  Future<void> openLink({
    required void Function(LinkSuccess success) onSuccess,
    required void Function(LinkExit exit) onExit,
  }) async {
    final response = await _client.functions.invoke('plaid-link-token');
    final linkToken = (response.data as Map)['link_token'] as String?;
    if (linkToken == null) {
      throw Exception('Could not create a Plaid Link token: ${response.data}');
    }

    await PlaidLink.create(configuration: LinkTokenConfiguration(token: linkToken));

    late final StreamSubscription<LinkSuccess> successSub;
    late final StreamSubscription<LinkExit> exitSub;
    successSub = PlaidLink.onSuccess.listen((event) {
      onSuccess(event);
      successSub.cancel();
      exitSub.cancel();
    });
    exitSub = PlaidLink.onExit.listen((event) {
      onExit(event);
      successSub.cancel();
      exitSub.cancel();
    });

    await PlaidLink.open();
  }

  Future<int> exchangePublicToken({
    required String publicToken,
    required String institutionName,
  }) async {
    final response = await _client.functions.invoke(
      'plaid-exchange',
      body: {'public_token': publicToken, 'institution_name': institutionName},
    );
    return (response.data as Map)['linked_accounts'] as int? ?? 0;
  }

  Future<void> syncTransactions() {
    return _client.functions.invoke('plaid-sync-transactions');
  }
}
