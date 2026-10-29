import 'package:flutter/foundation.dart';

import '../../../domain/models/new_plant.dart';
import '../../services/api/models/plant.dart';

/// Meu jardim in the API (`/v1/plants`).
///
/// Every method throws a `GardenFailure` when it fails. It notifies its
/// listeners after every change it makes to the garden (a plant saved, and
/// later renamed or removed), so the Jardim list reads it again.
abstract class GardenRepository extends ChangeNotifier {
  /// The User's plants, newest first.
  Future<List<PlantSummary>> plants();

  /// Saves [plant] with its photo, which becomes the plant's.
  Future<PlantSummary> create(NewPlant plant);

  /// One plant, with its species and care guide. The first reading of a
  /// species waits while Claude writes the guide; when another reading is
  /// writing it, throws `CareGuideGenerating` instead.
  Future<Plant> plant(String id);

  /// Changes plant [id]: only the fields given (a new [commonName], the
  /// [speciesId] of a plant saved without one). Answers it as in the list.
  Future<PlantSummary> update(
    String id, {
    String? commonName,
    String? speciesId,
  });

  /// Removes plant [id] and its photo from the garden.
  Future<void> remove(String id);
}
