/// Contrat D'ENTRÉE du moteur : ce que les écrans Flutter envoient au
/// moteur déterministe.
///
/// Ce fichier est 100% Dart pur (aucun `import 'package:flutter/...'`),
/// donc testable avec `dart test` / `flutter test` sans appareil ni
/// simulateur.
library;

/// Mode de génération demandé.
enum GenerationMode { textToVideo, imageToVideo }

/// Ratios d'image proposés par l'interface. Tous ne sont pas forcément
/// supportés nativement par le modèle choisi : c'est le moteur qui décide
/// de la conversion (voir `generation_engine.dart`).
enum AspectRatio {
  ratio16x9('16:9'),
  ratio9x16('9:16'),
  ratio1x1('1:1'),
  ratio4x5('4:5'),
  ratio21x9('21:9');

  final String label;
  const AspectRatio(this.label);

  static AspectRatio fromLabel(String label) {
    for (final r in AspectRatio.values) {
      if (r.label == label) return r;
    }
    throw ArgumentError('Ratio inconnu: $label');
  }
}

/// Réglages "Camera Positioning Matrix" du Director Panel.
/// -100..100, 0 = neutre (aucun mouvement demandé).
class CameraParams {
  final double pan;
  final double tilt;
  final double zoom;

  const CameraParams({this.pan = 0, this.tilt = 0, this.zoom = 0});

  factory CameraParams.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CameraParams();
    return CameraParams(
      pan: _toDouble(json['pan']) ?? 0,
      tilt: _toDouble(json['tilt']) ?? 0,
      zoom: _toDouble(json['zoom']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'pan': pan, 'tilt': tilt, 'zoom': zoom};
}

/// Réglages "Kinematics & Spatial Fluidity" du Director Panel.
/// 0..100, 50 = comportement par défaut du modèle Replicate.
class KinematicsParams {
  final double fluidity;
  final double gravity;

  const KinematicsParams({this.fluidity = 50, this.gravity = 50});

  factory KinematicsParams.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const KinematicsParams();
    return KinematicsParams(
      fluidity: _toDouble(json['fluidity']) ?? 50,
      gravity: _toDouble(json['gravity']) ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {'fluidity': fluidity, 'gravity': gravity};
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return null;
}

/// Le contrat d'entrée complet du moteur.
class GenerationParams {
  final GenerationMode mode;
  final String prompt;
  final AspectRatio aspectRatio;

  /// Durée souhaitée en secondes (1 à 5). Utilisée uniquement en
  /// texte-vers-vidéo : l'image-vers-vidéo n'expose pas ce réglage
  /// avec certitude côté API (voir generation_engine.dart).
  final int durationSeconds;

  final CameraParams camera;
  final KinematicsParams kinematics;

  /// Graine aléatoire optionnelle, pour reproduire exactement une
  /// génération. `null` = aléatoire à chaque fois.
  final int? seed;

  /// URL publique de l'image de référence (ex. hébergée sur imgbb.com).
  /// Obligatoire si `mode == GenerationMode.imageToVideo`.
  final String? referenceImageUrl;

  const GenerationParams({
    required this.mode,
    required this.prompt,
    this.aspectRatio = AspectRatio.ratio16x9,
    this.durationSeconds = 5,
    this.camera = const CameraParams(),
    this.kinematics = const KinematicsParams(),
    this.seed,
    this.referenceImageUrl,
  });

  factory GenerationParams.fromJson(Map<String, dynamic> json) {
    final modeStr = json['mode'] as String? ?? 'text_to_video';
    return GenerationParams(
      mode: modeStr == 'image_to_video'
          ? GenerationMode.imageToVideo
          : GenerationMode.textToVideo,
      prompt: (json['prompt'] as String?) ?? '',
      aspectRatio: AspectRatio.fromLabel((json['aspectRatio'] as String?) ?? '16:9'),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 5,
      camera: CameraParams.fromJson(json['camera'] as Map<String, dynamic>?),
      kinematics: KinematicsParams.fromJson(json['kinematics'] as Map<String, dynamic>?),
      seed: (json['seed'] as num?)?.toInt(),
      referenceImageUrl: json['referenceImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode == GenerationMode.imageToVideo ? 'image_to_video' : 'text_to_video',
        'prompt': prompt,
        'aspectRatio': aspectRatio.label,
        'durationSeconds': durationSeconds,
        'camera': camera.toJson(),
        'kinematics': kinematics.toJson(),
        if (seed != null) 'seed': seed,
        if (referenceImageUrl != null) 'referenceImageUrl': referenceImageUrl,
      };
}
