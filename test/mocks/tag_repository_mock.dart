import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Mock tag repository used by application-layer tests.
class MockTagRepository extends Mock implements TagRepository {}
