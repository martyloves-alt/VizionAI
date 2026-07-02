import 'package:flutter_test/flutter_test.dart';
import 'package:vizionai/engine/generation_engine.dart';
import 'package:vizionai/engine/model_specs.dart';
import 'package:vizionai/models/generation_params.dart';

/// Tests unitaires du moteur déterministe.
///
/// Chaque règle documentée dans CONTRAT_JSON.md (§3) a au moins un test
/// dédié ici. Comme le moteur est pur (aucun réseau, aucun état caché),
/// tous ces tests s'exécutent en quelques millisecondes, sans téléphone
/// ni serveur — juste `flutter test` via l'Action GitHub.
void main() {
  final engine = const GenerationEngine();

  GenerationParams baseT2V({
    String prompt = 'a cat',
    AspectRatio aspectRatio = AspectRatio.ratio16x9,
    int durationSeconds = 5,
    CameraParams camera = const CameraParams(),
    KinematicsParams kinematics = const KinematicsParams(),
    int? seed,
  }) {
    return GenerationParams(
      mode: GenerationMode.textToVideo,
      prompt: prompt,
      aspectRatio: aspectRatio,
      durationSeconds: durationSeconds,
      camera: camera,
      kinematics: kinematics,
      seed: seed,
    );
  }

  GenerationParams baseI2V({
    String prompt = 'le chat se met à danser',
    String referenceImageUrl = 'https://i.ibb.co/exemple.jpg',
    AspectRatio aspectRatio = AspectRatio.ratio16x9,
  }) {
    return GenerationParams(
      mode: GenerationMode.imageToVideo,
      prompt: prompt,
      referenceImageUrl: referenceImageUrl,
      aspectRatio: aspectRatio,
    );
  }

  group('Validation stricte', () {
    test('prompt vide -> exception', () {
      expect(() => engine.build(baseT2V(prompt: '')),
          throwsA(isA<EngineValidationException>()));
    });

    test('prompt uniquement des espaces -> exception', () {
      expect(() => engine.build(baseT2V(prompt: '   ')),
          throwsA(isA<EngineValidationException>()));
    });

    test('image-vers-vidéo sans image de référence -> exception', () {
      final params =
          GenerationParams(mode: GenerationMode.imageToVideo, prompt: 'un chat qui danse');
      expect(() => engine.build(params), throwsA(isA<EngineValidationException>()));
    });

    test('image-vers-vidéo avec URL vide -> exception', () {
      final params = GenerationParams(
        mode: GenerationMode.imageToVideo,
        prompt: 'un chat qui danse',
        referenceImageUrl: '   ',
      );
      expect(() => engine.build(params), throwsA(isA<EngineValidationException>()));
    });
  });

  group('Texte-vers-vidéo — cas nominal (réglages par défaut)', () {
    final result = engine.build(baseT2V());

    test('modèle correct', () {
      expect(result.modelIdentifier, textToVideoModel.identifier);
      expect(result.modelIdentifier, 'wan-video/wan-2.1-1.3b');
    });

    test('prompt inchangé (aucun mouvement de caméra)', () {
      expect(result.input['prompt'], 'a cat');
    });

    test('ratio 16:9 transmis tel quel', () {
      expect(result.input['aspect_ratio'], '16:9');
    });

    test('fluidity=50 -> sample_steps=30 (défaut Replicate)', () {
      expect(result.input['sample_steps'], 30);
    });

    test('gravity=50 -> sample_shift=8.0 (défaut Replicate)', () {
      expect(result.input['sample_shift'], 8.0);
    });

    test('sample_guide_scale toujours à 6.0', () {
      expect(result.input['sample_guide_scale'], 6.0);
    });

    test('resolution fixe 480p', () {
      expect(result.input['resolution'], '480p');
    });

    test('pas de seed si non fourni', () {
      expect(result.input.containsKey('seed'), isFalse);
    });

    test('seed transmis si fourni', () {
      final withSeed = engine.build(baseT2V(seed: 42));
      expect(withSeed.input['seed'], 42);
    });

    test('un seul avertissement : ajustement de durée', () {
      expect(result.warnings.length, 1);
      expect(result.warnings.first, contains('Durée ajustée'));
    });
  });

  group("Ratio d'image (texte-vers-vidéo)", () {
    final cases = <AspectRatio, String>{
      AspectRatio.ratio16x9: '16:9',
      AspectRatio.ratio9x16: '9:16',
      AspectRatio.ratio1x1: '9:16',
      AspectRatio.ratio4x5: '9:16',
      AspectRatio.ratio21x9: '16:9',
    };

    cases.forEach((input, expected) {
      test('${input.label} -> $expected', () {
        final result = engine.build(baseT2V(aspectRatio: input));
        expect(result.input['aspect_ratio'], expected);
      });
    });

    test('16:9 et 9:16 : aucun avertissement de ratio', () {
      final r1 = engine.build(baseT2V(aspectRatio: AspectRatio.ratio16x9));
      final r2 = engine.build(baseT2V(aspectRatio: AspectRatio.ratio9x16));
      expect(r1.warnings.any((w) => w.contains('Ratio')), isFalse);
      expect(r2.warnings.any((w) => w.contains('Ratio')), isFalse);
    });

    test('1:1, 4:5 et 21:9 : avertissement de ratio présent', () {
      for (final r in [AspectRatio.ratio1x1, AspectRatio.ratio4x5, AspectRatio.ratio21x9]) {
        final result = engine.build(baseT2V(aspectRatio: r));
        expect(result.warnings.any((w) => w.contains('Ratio')), isTrue);
      }
    });
  });

  group('Durée -> frame_num (texte-vers-vidéo)', () {
    final cases = <int, int>{1: 17, 2: 33, 3: 49, 4: 65, 5: 81};

    cases.forEach((duration, expectedFrames) {
      test('${duration}s -> frame_num=$expectedFrames', () {
        final result = engine.build(baseT2V(durationSeconds: duration));
        expect(result.input['frame_num'], expectedFrames);
      });
    });
  });

  group('Fluidity -> sample_steps', () {
    test('fluidity=0 -> steps=10 (minimum)', () {
      final result =
          engine.build(baseT2V(kinematics: const KinematicsParams(fluidity: 0, gravity: 50)));
      expect(result.input['sample_steps'], 10);
    });

    test('fluidity=100 -> steps=50 (maximum)', () {
      final result =
          engine.build(baseT2V(kinematics: const KinematicsParams(fluidity: 100, gravity: 50)));
      expect(result.input['sample_steps'], 50);
    });

    test('fluidity=50 -> steps=30 (défaut)', () {
      final result =
          engine.build(baseT2V(kinematics: const KinematicsParams(fluidity: 50, gravity: 50)));
      expect(result.input['sample_steps'], 30);
    });
  });

  group('Gravity -> sample_shift', () {
    test('gravity=0 -> shift=4.0 (minimum)', () {
      final result =
          engine.build(baseT2V(kinematics: const KinematicsParams(fluidity: 50, gravity: 0)));
      expect(result.input['sample_shift'], 4.0);
    });

    test('gravity=100 -> shift=12.0 (maximum)', () {
      final result =
          engine.build(baseT2V(kinematics: const KinematicsParams(fluidity: 50, gravity: 100)));
      expect(result.input['sample_shift'], 12.0);
    });
  });

  group('Caméra (pan/tilt/zoom) -> texte ajouté au prompt', () {
    test('en dessous de 25 : zone morte, aucun texte ajouté', () {
      final result =
          engine.build(baseT2V(camera: const CameraParams(pan: 24, tilt: -24, zoom: 10)));
      expect(result.input['prompt'], 'a cat');
    });

    test('pan positif "léger" (25-69) vers la droite', () {
      final result = engine.build(baseT2V(camera: const CameraParams(pan: 40)));
      expect(result.input['prompt'], contains('slightly to the right'));
    });

    test('pan négatif "fort" (>=70) vers la gauche', () {
      final result = engine.build(baseT2V(camera: const CameraParams(pan: -80)));
      expect(result.input['prompt'], contains('dramatically to the left'));
    });

    test('tilt positif -> vers le haut', () {
      final result = engine.build(baseT2V(camera: const CameraParams(tilt: 90)));
      expect(result.input['prompt'], contains('upward'));
    });

    test('zoom négatif -> zoom arrière', () {
      final result = engine.build(baseT2V(camera: const CameraParams(zoom: -50)));
      expect(result.input['prompt'], contains('zooms slightly out'));
    });

    test('pan + tilt + zoom combinés, toujours dans cet ordre', () {
      final result =
          engine.build(baseT2V(camera: const CameraParams(pan: 40, tilt: 40, zoom: 40)));
      final prompt = result.input['prompt'] as String;
      final panIndex = prompt.indexOf('pans');
      final tiltIndex = prompt.indexOf('tilts');
      final zoomIndex = prompt.indexOf('zooms');
      expect(panIndex, lessThan(tiltIndex));
      expect(tiltIndex, lessThan(zoomIndex));
    });
  });

  group('Bornes (clamping) et avertissements', () {
    test('pan hors bornes (150) ramené à 100, avertissement présent', () {
      final result = engine.build(baseT2V(camera: const CameraParams(pan: 150)));
      expect(result.warnings.any((w) => w.contains('Pan')), isTrue);
      expect(result.input['prompt'], contains('dramatically to the right'));
    });

    test('fluidity hors bornes (-20) ramenée à 0, avertissement présent', () {
      final result =
          engine.build(baseT2V(kinematics: const KinematicsParams(fluidity: -20, gravity: 50)));
      expect(result.warnings.any((w) => w.contains('Fluidity')), isTrue);
      expect(result.input['sample_steps'], 10);
    });

    test('prompt de plus de 500 caractères : tronqué exactement à 500', () {
      final longPrompt = 'a' * 600;
      final result = engine.build(baseT2V(prompt: longPrompt));
      final resultPrompt = result.input['prompt'] as String;
      expect(resultPrompt.length, 500);
      expect(result.warnings.any((w) => w.contains('tronqué')), isTrue);
    });
  });

  group('Image-vers-vidéo', () {
    test('modèle correct', () {
      final result = engine.build(baseI2V());
      expect(result.modelIdentifier, imageToVideoModel.identifier);
      expect(result.modelIdentifier, 'wavespeedai/wan-2.1-i2v-480p');
    });

    test('image transmise dans input', () {
      final result = engine.build(baseI2V(referenceImageUrl: 'https://i.ibb.co/photo.jpg'));
      expect(result.input['image'], 'https://i.ibb.co/photo.jpg');
    });

    test("aucun champ aspect_ratio envoyé (ignoré côté Replicate)", () {
      final result = engine.build(baseI2V());
      expect(result.input.containsKey('aspect_ratio'), isFalse);
    });

    test('ratio non-défaut -> avertissement "ignoré"', () {
      final result = engine.build(baseI2V(aspectRatio: AspectRatio.ratio9x16));
      expect(result.warnings.any((w) => w.contains('ignoré')), isTrue);
    });

    test('avertissement systématique : schéma non confirmé', () {
      final result = engine.build(baseI2V());
      expect(result.warnings.any((w) => w.contains('non confirmé')), isTrue);
    });
  });

  group('toReplicateRequest()', () {
    test('structure exacte {version, input}', () {
      final result = engine.build(baseT2V());
      final request = result.toReplicateRequest();
      expect(request.keys, containsAll(['version', 'input']));
      expect(request['version'], 'wan-video/wan-2.1-1.3b');
      expect(request['input'], result.input);
    });
  });

  group('Déterminisme', () {
    test('mêmes entrées -> sortie strictement identique', () {
      final params = baseT2V(
        prompt: 'une ville futuriste sous la pluie',
        aspectRatio: AspectRatio.ratio9x16,
        durationSeconds: 3,
        camera: const CameraParams(pan: 60, tilt: -30, zoom: 80),
        kinematics: const KinematicsParams(fluidity: 70, gravity: 20),
        seed: 12345,
      );

      final r1 = engine.build(params);
      final r2 = engine.build(params);

      expect(r1.toJson(), equals(r2.toJson()));
    });
  });
}
