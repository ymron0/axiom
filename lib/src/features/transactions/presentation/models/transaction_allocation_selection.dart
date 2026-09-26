import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';

/// Presentation selection for one transaction allocation target.
///
/// Amounts remain owned by the transaction editor/split state. This object
/// only owns the category/jar target selection.
final class TransactionAllocationSelection {
  final CategoryId? categoryId;
  final JarId? jarId;

  const TransactionAllocationSelection({this.categoryId, this.jarId});

  bool get isEmpty => categoryId == null && jarId == null;

  TransactionAllocationSelection copyWith({
    Object? categoryId = _unsetCategory,
    Object? jarId = _unsetJar,
  }) {
    return TransactionAllocationSelection(
      categoryId: identical(categoryId, _unsetCategory)
          ? this.categoryId
          : categoryId as CategoryId?,
      jarId: identical(jarId, _unsetJar) ? this.jarId : jarId as JarId?,
    );
  }
}

const Object _unsetCategory = Object();
const Object _unsetJar = Object();
