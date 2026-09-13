import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:mocktail/mocktail.dart';

/// A mock category lookup use case for application-service tests.
class MockGetCategoryByIdUseCase extends Mock
    implements GetCategoryByIdUseCase {}
