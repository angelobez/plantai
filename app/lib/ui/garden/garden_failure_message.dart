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
  GardenFailure.speciesAlreadySet =>
    'Essa planta já tem uma espécie. Se ela estiver errada, remova a planta '
        'e adicione de novo.',
  GardenFailure.unknown => 'Algo deu errado. Tente de novo.',
};
