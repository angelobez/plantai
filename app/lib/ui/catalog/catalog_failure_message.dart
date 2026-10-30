import '../../domain/models/catalog_failure.dart';
import '../core/failure_messages.dart';

/// The pt-BR message of a Catálogo [failure]. [notFound] replaces the
/// message of [CatalogFailure.notFound], which only a species read expects.
String catalogFailureMessage(
  CatalogFailure failure, {
  String notFound = unknownFailureMessage,
}) => switch (failure) {
  CatalogFailure.noConnection => noConnectionMessage,
  CatalogFailure.notFound => notFound,
  CatalogFailure.unknown => unknownFailureMessage,
};
