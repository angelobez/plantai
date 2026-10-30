import '../../domain/models/photo_failure.dart';
import '../core/failure_messages.dart';

/// The pt-BR message of a photo upload [failure].
String photoFailureMessage(PhotoFailure failure) => switch (failure) {
  PhotoFailure.noConnection => noConnectionMessage,
  PhotoFailure.dailyLimit =>
    'Você já enviou 50 fotos hoje, o limite do dia. Amanhã tem mais.',
  PhotoFailure.notAnImage =>
    'Não deu para ler esta foto. Tire ou escolha outra foto.',
  PhotoFailure.unknown => unknownFailureMessage,
};
