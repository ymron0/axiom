import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Maps domain [EntityIcon] identities to Material Symbols.
///
/// ## Invariants
///
/// Every domain icon is mapped exhaustively.
///
/// ## Semantics
///
/// Domain code stores semantic icon identity without depending on Flutter.
/// This resolver supplies the concrete presentation representation.
///
/// ## Contract
///
/// Adding a new [EntityIcon] requires adding its corresponding presentation
/// mapping here.
///
/// Resolution is deterministic and has no expected recoverable failure.
abstract final class EntityIconResolver {
  /// Returns the Material Symbol associated with [icon].
  static IconData resolve(EntityIcon icon) {
    return switch (icon) {
      EntityIcon.accountBalance => Symbols.account_balance_rounded,
      EntityIcon.accountBalanceWallet => Symbols.account_balance_wallet_rounded,
      EntityIcon.savings => Symbols.savings_rounded,
      EntityIcon.payments => Symbols.payments_rounded,
      EntityIcon.creditCard => Symbols.credit_card_rounded,
      EntityIcon.wallet => Symbols.wallet_rounded,
      EntityIcon.lock => Symbols.lock_rounded,
      EntityIcon.currencyExchange => Symbols.currency_exchange_rounded,
      EntityIcon.trendingUp => Symbols.trending_up_rounded,
      EntityIcon.showChart => Symbols.show_chart_rounded,
      EntityIcon.monitoring => Symbols.monitoring_rounded,
      EntityIcon.storefront => Symbols.storefront_rounded,
      EntityIcon.business => Symbols.business_rounded,
      EntityIcon.apartment => Symbols.apartment_rounded,
      EntityIcon.public => Symbols.public_rounded,
      EntityIcon.smartphone => Symbols.smartphone_rounded,
      EntityIcon.token => Symbols.token_rounded,
      EntityIcon.attachMoney => Symbols.attach_money_rounded,
      EntityIcon.euro => Symbols.euro_rounded,
      EntityIcon.currencyFranc => Symbols.currency_franc_rounded,
      EntityIcon.other => Symbols.more_horiz_rounded,
    };
  }
}
