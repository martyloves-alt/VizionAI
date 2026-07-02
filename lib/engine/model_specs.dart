/// Source UNIQUE de vérité pour les modèles Replicate utilisés par
/// VizionAI. Si Replicate change quelque chose, c'est CE fichier — et
/// uniquement celui-ci — qu'on modifie.
///
/// Choix volontaire : on n'utilise JAMAIS de hash de version figé en dur.
/// Depuis août 2025, l'API Replicate accepte `"version": "owner/name"`
/// pour les modèles "officiels" et résout automatiquement la dernière
/// version. C'est ce qui rendait l'ancien code Kotlin fragile (un seul
/// hash figé, jamais mis à jour) — on élimine complètement cette classe
/// de bug ici.
library;

class ModelSpec {
  final String owner;
  final String name;

  const ModelSpec({required this.owner, required this.name});

  /// Format `"owner/name"`, à utiliser tel quel comme valeur du champ
  /// Replicate `"version"`.
  String get identifier => '$owner/$name';
}

/// Texte-vers-vidéo. Modèle officiel Replicate confirmé — vérifié le
/// 02/07/2026 sur https://replicate.com/wan-video/wan-2.1-1.3b
/// (métadonnée `is_official: true`). Aucune version à gérer.
const textToVideoModel = ModelSpec(owner: 'wan-video', name: 'wan-2.1-1.3b');

/// Image-vers-vidéo.
///
/// ⚠️ Statut "modèle officiel" NON confirmé pour celui-ci (maintenu par un
/// partenaire, wavespeedai, pas par Replicate directement). À vérifier lors
/// du tout premier appel réel :
/// - Si Replicate répond avec une erreur du type "invalid version" :
///   1. Ouvre https://replicate.com/wavespeedai/wan-2.1-i2v-480p/versions
///   2. Copie le hash de la version la plus récente
///   3. Remplace la ligne ci-dessous par :
///      `const imageToVideoModel = ModelSpec(owner: 'wavespeedai', name: 'wan-2.1-i2v-480p:LE_HASH_COPIÉ');`
///      (le hash devient alors juste une partie de `name`, car
///      `identifier` produit directement la chaîne finale)
const imageToVideoModel = ModelSpec(owner: 'wavespeedai', name: 'wan-2.1-i2v-480p');
