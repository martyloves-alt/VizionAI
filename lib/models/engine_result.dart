/// Contrat de SORTIE du moteur : la requête exacte, déjà prête, à envoyer
/// à l'API Replicate. Aucune transformation supplémentaire ne devrait être
/// nécessaire côté écran ou côté client réseau.
library;

class EngineResult {
  /// Format `"owner/name"` (ex. `"wan-video/wan-2.1-1.3b"`).
  /// Utilisé directement comme valeur du champ `"version"` envoyé à
  /// `POST https://api.replicate.com/v1/predictions` — voir
  /// `toReplicateRequest()`.
  final String modelIdentifier;

  /// Le contenu exact du champ `"input"` Replicate pour ce modèle.
  final Map<String, dynamic> input;

  /// Ajustements automatiques effectués par le moteur (ratio non supporté,
  /// valeur hors bornes, etc.). Jamais d'ajustement silencieux : tout
  /// changement de ce que l'utilisateur a demandé finit ici.
  final List<String> warnings;

  /// Estimation approximative de la durée de génération, pour l'UI
  /// (barre de progression). Ce n'est qu'une estimation, pas une garantie.
  final int estimatedSeconds;

  const EngineResult({
    required this.modelIdentifier,
    required this.input,
    this.warnings = const [],
    required this.estimatedSeconds,
  });

  /// Le corps JSON exact à poster sur
  /// `POST https://api.replicate.com/v1/predictions`.
  Map<String, dynamic> toReplicateRequest() => {
        'version': modelIdentifier,
        'input': input,
      };

  Map<String, dynamic> toJson() => {
        'modelIdentifier': modelIdentifier,
        'input': input,
        'warnings': warnings,
        'estimatedSeconds': estimatedSeconds,
      };
}
