/// What the API reported about itself and its database.
class Health {
  const Health({required this.apiVersion, required this.postgisVersion});

  final String apiVersion;
  final String postgisVersion;
}
