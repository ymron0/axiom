// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'entity_icon.mapper.dart';

/// A stable icon identity that can be assigned to an entity.
///
/// This enum contains semantic icon choices only. It deliberately avoids
/// Flutter's `IconData` so that the domain remains independent of the
/// presentation framework.
///
/// The presentation layer maps these values to the corresponding Material
/// Symbols or other visual representation.
///
/// An entity icon also acts as the fallback visual when no [EntityLogo] is
/// available.
@MappableEnum()
enum EntityIcon {
  accountBalance,
  accountBalanceWallet,
  savings,
  payments,
  creditCard,
  wallet,
  safe,
  currencyExchange,
  trendingUp,
  showChart,
  monitoring,
  storefront,
  business,
  apartment,
  public,
  smartphone,
  token,
  attachMoney,
  euro,
  currencyFranc,
  other,
}