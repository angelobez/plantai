import '../../domain/models/garden_failure.dart';
import '../core/failure_messages.dart';

/// The pt-BR message of a Meu jardim [failure]. [notFound] replaces the
/// message of [GardenFailure.notFound], which depends on what was missing.
String gardenFailureMessage(
  GardenFailure failure, {
  String notFound = 'Essa planta não está mais no seu jardim.',
}) => switch (failure) {
  GardenFailure.noConnection => noConnectionMessage,
  GardenFailure.notFound => notFound,
  GardenFailure.speciesAlreadySet =>
    'Essa planta já tem uma espécie. Se ela estiver errada, remova a planta '
        'e adicione de novo.',
  GardenFailure.unknown => unknownFailureMessage,
};
