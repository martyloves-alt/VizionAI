Contrat JSON — Moteur VizionAI

Ce document décrit les échanges entre les écrans Flutter et le moteur
déterministe (lib/engine/generation_engine.dart), ainsi que la requête
finale envoyée à Replicate. Étape 1/4 du plan (moteur + contrat) — les
écrans qui produiront ce JSON viendront à l'étape 3.


1. Entrée : GenerationParams

Ce que l'écran envoie au moteur.


{
  "mode": "text_to_video",
  "prompt": "Un astronaute marche sur une planète dorée, cinématique",
  "aspectRatio": "9:16",
  "durationSeconds": 5,
  "camera": { "pan": 0, "tilt": 0, "zoom": 40 },
  "kinematics": { "fluidity": 50, "gravity": 50 },
  "seed": null,
  "referenceImageUrl": null
}

Champ	Type	Détail
mode	string	"text_to_video" ou "image_to_video"
prompt	string	requis, non vide
aspectRatio	string	"16:9" | "9:16" | "1:1" | "4:5" | "21:9"
durationSeconds	int	1 à 5, approximatif (texte-vers-vidéo uniquement)
camera.pan/tilt/zoom	double	-100 à 100, 0 = neutre
kinematics.fluidity/gravity	double	0 à 100, 50 = comportement par défaut du modèle
referenceImageUrl	string?	obligatoire si mode = "image_to_video" (URL publique, ex. imgbb.com)

2. Sortie : EngineResult

Ce que le moteur renvoie — prêt à poster sur Replicate tel quel.


{
  "modelIdentifier": "wan-video/wan-2.1-1.3b",
  "input": {
    "prompt": "Un astronaute marche sur une planète dorée, cinématique, the camera zooms slightly in",
    "aspect_ratio": "9:16",
    "frame_num": 81,
    "resolution": "480p",
    "sample_steps": 30,
    "sample_guide_scale": 6.0,
    "sample_shift": 8.0
  },
  "warnings": [],
  "estimatedSeconds": 40
}

EngineResult.toReplicateRequest() donne directement le corps à poster sur
POST https://api.replicate.com/v1/predictions :


{ "version": "wan-video/wan-2.1-1.3b", "input": { "...": "..." } }

Aucun hash de version figé en dur : wan-video/wan-2.1-1.3b est un modèle
officiel Replicate, donc owner/name suffit et pointe toujours vers la
dernière version. C'est le principal bug structurel corrigé par rapport à
l'ancien code Kotlin (qui figeait un hash unique, sans savoir à quel modèle
il correspondait réellement).


3. Règles déterministes appliquées

Curseur interface	Effet dans le moteur
fluidity (0-100)	→ sample_steps (10-50) ; 50 → 30 (défaut Replicate)
gravity (0-100)	→ sample_shift (4-12) ; 50 → 8 (défaut Replicate)
pan / tilt / zoom	→ phrase ajoutée au prompt si |valeur| ≥ 25 (zone morte en dessous, 2 paliers d'intensité au-dessus)
aspectRatio (texte-vers-vidéo)	16:9 et 9:16 passent tels quels ; 1:1 et 4:5 → 9:16 ; 21:9 → 16:9
aspectRatio (image-vers-vidéo)	ignoré : Replicate reprend le ratio de l'image envoyée
durationSeconds	arrondi à la valeur la plus proche parmi ~1/2/3/4/5s (texte-vers-vidéo uniquement)

Chaque ajustement automatique ajoute un message dans warnings — jamais
rien de silencieux. C'est ce tableau que les tests unitaires de l'étape
suivante vont vérifier ligne par ligne.


4. Ce qui reste à vérifier avant un premier vrai test


Image-vers-vidéo (wavespeedai/wan-2.1-i2v-480p) : le statut "modèle officiel" n'est pas confirmé, ni les noms exacts de sample_steps / sample_guide_scale / sample_shift pour CE modèle précis (déduits par recoupement de sources, pas lus dans son code source à lui). Si Replicate refuse la requête, le message d'erreur précise le nom du champ fautif — correction en un endroit unique : lib/engine/model_specs.dart (identifiant) ou _buildImageToVideo dans generation_engine.dart (noms de champs).

Texte-vers-vidéo (wan-video/wan-2.1-1.3b) : schéma vérifié dans le code source officiel du prédicteur Replicate — fiable à 100%.


5. Fichiers livrés à cette étape

lib/
  models/
    generation_params.dart   # contrat d'entrée
    engine_result.dart       # contrat de sortie
  engine/
    model_specs.dart         # identifiants des modèles Replicate
    generation_engine.dart   # le moteur déterministe lui-même
pubspec.yaml
analysis_options.yaml
.gitignore
.github/workflows/ci.yml     # vérifie automatiquement `flutter analyze` à chaque push

Prochaine étape : tests unitaires du moteur (couvrant le tableau du §3),
puis écrans Flutter complets, puis notifications + alarmes Android.

