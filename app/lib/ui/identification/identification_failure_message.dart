import '../../domain/models/identification_failure.dart';
import '../core/failure_messages.dart';

/// The pt-BR message of an identification [failure].
String identificationFailureMessage(IdentificationFailure failure) =>
    switch (failure) {
      IdentificationFailure.noConnection => noConnectionMessage,
      IdentificationFailure.serviceUnavailable =>
        'O Pl@ntNet, que identifica as plantas, não respondeu. Tente de novo '
            'em instantes; esta tentativa não contou.',
      IdentificationFailure.notFound =>
        'Essa foto não está mais disponível. Tire outra foto.',
      IdentificationFailure.alreadyChosen =>
        'Você já escolheu uma opção para esta foto. Identifique de novo para '
            'escolher outra.',
      IdentificationFailure.dailyLimit =>
        'Você usou suas 10 identificações de hoje; amanhã tem mais.',
      IdentificationFailure.unknown => unknownFailureMessage,
    };
