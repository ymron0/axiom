import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'record_already_exists_failure.mapper.dart';

@MappableClass()
final class RecordAlreadyExistsFailure
    extends Failure<RecordAlreadyExistsFailure>
    with RecordAlreadyExistsFailureMappable {
  const RecordAlreadyExistsFailure({String? message}) : super(message);

  static const typeId = 'persistence.recordAlreadyExists';

  @override
  RecordAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
