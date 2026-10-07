import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('menu editor commits metadata availability and images with one save call', () {
    final source = File(
      'lib/features/menu/presentation/pages/upsertMenuItemPage.dart',
    ).readAsStringSync();

    final submitStart = source.indexOf('Future<void> _submit()');
    final submitEnd = source.indexOf('void _message(', submitStart);
    final submit = source.substring(submitStart, submitEnd);

    expect(submit, contains('_api.saveProductAtomic('));
    expect(submit, isNot(contains('_api.createProduct(')));
    expect(submit, isNot(contains('_api.updateProduct(')));
    expect(submit, isNot(contains('_api.updateAvailability(')));
    expect(submit, isNot(contains('_api.replaceProductImages(')));
  });

  test('create retries keep one stable product id', () {
    final source = File(
      'lib/features/menu/presentation/pages/upsertMenuItemPage.dart',
    ).readAsStringSync();

    expect(source, contains('late final String _saveProductId;'));
    expect(
      source,
      contains('_saveProductId = widget.item?.id ?? _newUuidV4();'),
    );
    expect(source, contains('productId: _saveProductId'));
  });

  test('multipart form fields survive auth retry paths', () {
    final source = File('lib/core/network/api_client.dart').readAsStringSync();

    expect(source, contains('request.fields.addAll(fields);'));
    expect(source, contains('fields: fields'));
  });
}
