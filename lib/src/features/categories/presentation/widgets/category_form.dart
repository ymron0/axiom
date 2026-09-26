import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_color_resolver.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_icon_resolver.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/enums/entity_color.dart';
import '../../../../core/domain/enums/entity_icon.dart';
import '../../domain/entities/category.dart';
import '../../domain/enums/category_kind.dart';
import '../state/category_form_state.dart';

final class CategoryForm extends StatefulWidget {
  final CategoryFormState value;
  final List<Category> categories;
  final CategoryId? editedCategoryId;
  final bool enabled;
  final ValueChanged<CategoryFormState> onChanged;
  final VoidCallback onSubmit;
  final String submitLabel;

  const CategoryForm({
    required this.value,
    required this.categories,
    required this.enabled,
    required this.onChanged,
    required this.onSubmit,
    required this.submitLabel,
    this.editedCategoryId,
    super.key,
  });

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

final class _CategoryFormState extends State<CategoryForm> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.value.name);
  }

  @override
  void didUpdateWidget(covariant CategoryForm oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value.name != _nameController.text &&
        widget.value.name != oldWidget.value.name) {
      _nameController.text = widget.value.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentCandidates = widget.categories
        .where(
          (category) =>
              !category.isDeleted && category.id != widget.editedCategoryId,
        )
        .toList(growable: false);

    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            enabled: widget.enabled,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            onChanged: (value) {
              widget.onChanged(widget.value.copyWith(name: value));
            },
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Enter a category name.';
              }

              return null;
            },
          ),
          const SizedBox(height: 20),
          Text('Type', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<CategoryKind>(
            segments: const [
              ButtonSegment(
                value: CategoryKind.expense,
                icon: Icon(Icons.arrow_upward_rounded),
                label: Text('Expense'),
              ),
              ButtonSegment(
                value: CategoryKind.income,
                icon: Icon(Icons.arrow_downward_rounded),
                label: Text('Income'),
              ),
            ],
            selected: {widget.value.kind},
            onSelectionChanged: widget.enabled
                ? (selection) {
                    widget.onChanged(
                      widget.value.copyWith(kind: selection.single),
                    );
                  }
                : null,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<CategoryId?>(
            initialValue: widget.value.parentCategoryId,
            decoration: const InputDecoration(labelText: 'Parent category'),
            items: [
              const DropdownMenuItem<CategoryId?>(
                value: null,
                child: Text('No parent'),
              ),
              ...parentCandidates.map(
                (category) => DropdownMenuItem<CategoryId?>(
                  value: category.id,
                  child: Text(category.name),
                ),
              ),
            ],
            onChanged: widget.enabled
                ? (value) {
                    widget.onChanged(
                      widget.value.copyWith(parentCategoryId: value),
                    );
                  }
                : null,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<EntityIcon>(
            initialValue: widget.value.icon,
            decoration: const InputDecoration(labelText: 'Icon'),
            items: EntityIcon.values
                .map(
                  (icon) => DropdownMenuItem(
                    value: icon,
                    child: Row(
                      children: [
                        Icon(EntityIconResolver.resolve(icon)),
                        const SizedBox(width: 12),
                        Text(_enumLabel(icon.name)),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: widget.enabled
                ? (value) {
                    if (value == null) {
                      return;
                    }

                    widget.onChanged(widget.value.copyWith(icon: value));
                  }
                : null,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<EntityColor>(
            initialValue: widget.value.color,
            decoration: const InputDecoration(labelText: 'Color'),
            items: EntityColor.values
                .map((color) {
                  final palette = EntityColorResolver.resolve(
                    color,
                    Theme.of(context).brightness,
                  );

                  return DropdownMenuItem(
                    value: color,
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(_enumLabel(color.name)),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
            onChanged: widget.enabled
                ? (value) {
                    if (value == null) {
                      return;
                    }

                    widget.onChanged(widget.value.copyWith(color: value));
                  }
                : null,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: widget.enabled && widget.value.isValid
                ? widget.onSubmit
                : null,
            child: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

String _enumLabel(String value) {
  if (value.isEmpty) {
    return value;
  }

  return '${value[0].toUpperCase()}${value.substring(1)}';
}
