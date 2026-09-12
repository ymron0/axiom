import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_kind.mapper.dart';

/// Describes the type of institution or location that holds accounts.
///
/// Custodian kind is descriptive metadata used for presentation, filtering,
/// grouping, and future custodian-specific behavior.
@MappableEnum()
enum CustodianKind { bank, broker, exchange, selfCustody }
