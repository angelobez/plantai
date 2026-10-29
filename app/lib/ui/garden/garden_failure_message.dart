import '../../domain/models/garden_failure.dart';

/// The pt-BR message of a Meu jardim [failure]. [notFound] replaces the
/// message of [GardenFailure.notFound], which depends on what was missing.
String gardenFailureMessage(
  GardenFailure failure, {
  String notFound = 'Essa planta não está mais no seu jardim.',
}) => switch (failure) {
  GardenFailure.noConnection =>
    'Sem conexão com a internet. Confira a rede e tente de novo.',
  GardenFailure.notFound => notFound,
  GardenFailure.unknown => 'Algo deu errado. Tente de novo.',
};
