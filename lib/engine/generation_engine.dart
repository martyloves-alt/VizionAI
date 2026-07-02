import '../models/engine_result.dart';
import '../models/generation_params.dart';
import 'model_specs.dart';

/// Levée quand les paramètres d'entrée sont invalides (prompt vide, image
/// de référence manquante en mode image-vers-vidéo...).
class EngineValidationException implements Exception {
  final String message;
  const EngineValidationException(this.message);

  @override
  String toString() => 'EngineValidationException: $message';
}

/// Le moteur déterministe de VizionAI.
///
/// `build()` transforme des [GenerationParams] en [EngineResult] — la
/// requête exacte à envoyer à Replicate. AUCUN appel réseau, AUCUN état,
/// AUCUN horodatage ni aléatoire caché : mêmes entrées => toujours
/// exactement la même sortie. C'est ce qui rend cette classe testable à
/// 100% (voir l'étape suivante : tests unitaires) sans serveur, sans clé
/// API, sans téléphone.
class GenerationEngine {
  const GenerationEngine();

  static const int _maxPromptLength = 500;

  /// Nombre de frames accepté par le modèle texte-vers-vidéo (~16 fps).
  /// Correspond à environ 1s, 2s, 3s, 4s, 5s.
  static const List<int> _frameChoices = [17, 33, 49, 65, 81];

  EngineResult build(GenerationParams params) {
    final warnings = <String>[];

    // --- Validation stricte : échoue franchement, jamais en silence ---
    final trimmedPrompt = params.prompt.trim();
    if (trimmedPrompt.isEmpty) {
      throw const EngineValidationException('Le prompt ne peut pas être vide.');
    }
    if (params.mode == GenerationMode.imageToVideo &&
        (params.referenceImageUrl == null || params.referenceImageUrl!.trim().isEmpty)) {
      throw const EngineValidationException(
          'Une image de référence est requise en mode image-vers-vidéo.');
    }

    // --- Tolérance souple : corrige + avertit, ne casse jamais l'appel ---
    var safePrompt = trimmedPrompt;
    if (safePrompt.length > _maxPromptLength) {
      safePrompt = safePrompt.substring(0, _maxPromptLength);
      warnings.add('Prompt tronqué à $_maxPromptLength caractères pour la fiabilité de l\'API.');
    }

    final camera = _clampCamera(params.camera, warnings);
    final kinematics = _clampKinematics(params.kinematics, warnings);

    // --- Traduction déterministe des curseurs caméra en texte de prompt ---
    // (Le modèle Wan n'a pas de paramètre API "pan/tilt/zoom" natif : on
    // exprime le mouvement de caméra en langage naturel, de façon fixe et
    // reproductible, plutôt que d'inventer un faux paramètre API.)
    final cameraPhrase = _cameraPhrase(camera);
    final finalPrompt = cameraPhrase.isEmpty ? safePrompt : '$safePrompt, $cameraPhrase';

    if (params.mode == GenerationMode.textToVideo) {
      return _buildTextToVideo(
        prompt: finalPrompt,
        aspectRatio: params.aspectRatio,
        durationSeconds: params.durationSeconds,
        kinematics: kinematics,
        seed: params.seed,
        warnings: warnings,
      );
    } else {
      if (params.aspectRatio != AspectRatio.ratio16x9) {
        warnings.add(
            'Le ratio d\'image est ignoré en mode image-vers-vidéo : Replicate reprend automatiquement le ratio de l\'image envoyée.');
      }
      return _buildImageToVideo(
        prompt: finalPrompt,
        referenceImageUrl: params.referenceImageUrl!,
        kinematics: kinematics,
        seed: params.seed,
        warnings: warnings,
      );
    }
  }

  // ---------------------------------------------------------------------
  // Construction par mode
  // ---------------------------------------------------------------------

  EngineResult _buildTextToVideo({
    required String prompt,
    required AspectRatio aspectRatio,
    required int durationSeconds,
    required KinematicsParams kinematics,
    required int? seed,
    required List<String> warnings,
  }) {
    final mappedRatio = _mapAspectRatioForT2V(aspectRatio, warnings);
    final frameNum = _nearestFrameCount(durationSeconds, warnings);
    final sampleSteps = _fluidityToSteps(kinematics.fluidity);
    final sampleShift = _gravityToShift(kinematics.gravity);

    final input = <String, dynamic>{
      'prompt': prompt,
      'aspect_ratio': mappedRatio,
      'frame_num': frameNum,
      'resolution': '480p',
      'sample_steps': sampleSteps,
      'sample_guide_scale': 6.0,
      'sample_shift': sampleShift,
      if (seed != null) 'seed': seed,
    };

    return EngineResult(
      modelIdentifier: textToVideoModel.identifier,
      input: input,
      warnings: warnings,
      estimatedSeconds: 40,
    );
  }

  EngineResult _buildImageToVideo({
    required String prompt,
    required String referenceImageUrl,
    required KinematicsParams kinematics,
    required int? seed,
    required List<String> warnings,
  }) {
    warnings.add(
        'Schéma image-vers-vidéo non confirmé à 100% côté Replicate : à vérifier au premier appel réel (voir model_specs.dart).');
    warnings.add(
        'Durée non paramétrée pour l\'image-vers-vidéo (nom de champ non confirmé) : le modèle utilisera sa valeur par défaut.');

    final sampleSteps = _fluidityToSteps(kinematics.fluidity);
    final sampleShift = _gravityToShift(kinematics.gravity);

    final input = <String, dynamic>{
      'image': referenceImageUrl,
      'prompt': prompt,
      'sample_steps': sampleSteps,
      'sample_guide_scale': 5.0,
      'sample_shift': sampleShift,
      if (seed != null) 'seed': seed,
    };

    return EngineResult(
      modelIdentifier: imageToVideoModel.identifier,
      input: input,
      warnings: warnings,
      estimatedSeconds: 45,
    );
  }

  // ---------------------------------------------------------------------
  // Règles déterministes
  // ---------------------------------------------------------------------

  /// Le modèle texte-vers-vidéo ne supporte QUE 16:9 et 9:16 (confirmé
  /// dans le code source du prédicteur Replicate). Les 3 autres ratios de
  /// l'interface sont ramenés au plus proche, jamais envoyés tels quels.
  String _mapAspectRatioForT2V(AspectRatio ratio, List<String> warnings) {
    switch (ratio) {
      case AspectRatio.ratio16x9:
        return '16:9';
      case AspectRatio.ratio9x16:
        return '9:16';
      case AspectRatio.ratio21x9:
        warnings.add('Ratio 21:9 non supporté par ce modèle, remplacé par 16:9.');
        return '16:9';
      case AspectRatio.ratio4x5:
        warnings.add('Ratio 4:5 non supporté par ce modèle, remplacé par 9:16.');
        return '9:16';
      case AspectRatio.ratio1x1:
        warnings.add('Ratio 1:1 non supporté par ce modèle, remplacé par 9:16.');
        return '9:16';
    }
  }

  int _nearestFrameCount(int durationSeconds, List<String> warnings) {
    final targetFrames = durationSeconds * 16;
    var best = _frameChoices.first;
    var bestDiff = (targetFrames - best).abs();
    for (final f in _frameChoices.skip(1)) {
      final diff = (targetFrames - f).abs();
      if (diff < bestDiff) {
        best = f;
        bestDiff = diff;
      }
    }
    if (best != targetFrames) {
      final actualSeconds = (best / 16).toStringAsFixed(1);
      warnings.add(
          'Durée ajustée à environ ${actualSeconds}s (le modèle n\'accepte que ~1s/2s/3s/4s/5s).');
    }
    return best;
  }

  /// fluidity 0..100 -> sample_steps 10..50. À 50 (valeur par défaut du
  /// curseur), on retombe exactement sur 30 : le défaut Replicate.
  int _fluidityToSteps(double fluidity) {
    final raw = 10 + (fluidity / 100) * 40;
    var steps = raw.round();
    if (steps < 10) steps = 10;
    if (steps > 50) steps = 50;
    return steps;
  }

  /// gravity 0..100 -> sample_shift 4..12. À 50 (valeur par défaut du
  /// curseur), on retombe exactement sur 8 : le défaut Replicate.
  double _gravityToShift(double gravity) {
    var shift = 4 + (gravity / 100) * 8;
    shift = double.parse(shift.toStringAsFixed(2));
    if (shift < 0) shift = 0;
    if (shift > 20) shift = 20;
    return shift;
  }

  CameraParams _clampCamera(CameraParams camera, List<String> warnings) {
    return CameraParams(
      pan: _clampAndWarn(camera.pan, -100, 100, 'Pan', warnings),
      tilt: _clampAndWarn(camera.tilt, -100, 100, 'Tilt', warnings),
      zoom: _clampAndWarn(camera.zoom, -100, 100, 'Zoom', warnings),
    );
  }

  KinematicsParams _clampKinematics(KinematicsParams kinematics, List<String> warnings) {
    return KinematicsParams(
      fluidity: _clampAndWarn(kinematics.fluidity, 0, 100, 'Fluidity', warnings),
      gravity: _clampAndWarn(kinematics.gravity, 0, 100, 'Gravity', warnings),
    );
  }

  double _clampAndWarn(
      double value, double min, double max, String label, List<String> warnings) {
    if (value < min) {
      warnings.add('$label hors limites ($value), ramené à $min.');
      return min;
    }
    if (value > max) {
      warnings.add('$label hors limites ($value), ramené à $max.');
      return max;
    }
    return value;
  }

  /// Traduit pan/tilt/zoom en phrase descriptive, avec une zone morte sous
  /// 25 (pour ignorer les micro-mouvements de curseur non intentionnels)
  /// et deux paliers d'intensité au-dessus.
  String _cameraPhrase(CameraParams camera) {
    final parts = <String>[];
    final pan = _motionPhrase(camera.pan, 'the camera pans', 'to the right', 'to the left');
    final tilt = _motionPhrase(camera.tilt, 'the camera tilts', 'upward', 'downward');
    final zoom = _motionPhrase(camera.zoom, 'the camera zooms', 'in', 'out');
    if (pan != null) parts.add(pan);
    if (tilt != null) parts.add(tilt);
    if (zoom != null) parts.add(zoom);
    return parts.join(', ');
  }

  String? _motionPhrase(
      double value, String subject, String positiveDirection, String negativeDirection) {
    final magnitude = value.abs();
    if (magnitude < 25) return null;
    final direction = value > 0 ? positiveDirection : negativeDirection;
    final intensity = magnitude >= 70 ? 'dramatically' : 'slightly';
    return '$subject $intensity $direction';
  }
}
