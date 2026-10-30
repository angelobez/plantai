import '../../domain/models/listing_failure.dart';
import '../core/failure_messages.dart';

/// The pt-BR message of a listing [failure]. [notFound] replaces the message
/// of [ListingFailure.notFound], which depends on what was missing.
String listingFailureMessage(
  ListingFailure failure, {
  String notFound = 'Esse anúncio não existe mais.',
}) => switch (failure) {
  ListingFailure.noConnection => noConnectionMessage,
  ListingFailure.donationProfileRequired =>
    'Antes de doar, informe o seu WhatsApp e de onde você doa.',
  ListingFailure.notFound => notFound,
  ListingFailure.unknown => unknownFailureMessage,
};
