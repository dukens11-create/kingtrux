import '../models/alert_event.dart';
import 'tts_language_service.dart';

/// Provides localized spoken phrases for each [AlertType] in the three
/// languages supported for alert TTS: English, Spanish, and Haitian Creole.
///
/// These phrases are intentionally shorter than the full display message so
/// that TTS readout is concise and easy to understand while driving.
///
/// Usage:
/// ```dart
/// final text = AlertPhraseService.phrase(AlertType.sharpCurveHazard, TtsLanguage.es);
/// // → 'Curva cerrada adelante. Reduzca la velocidad.'
/// ```
class AlertPhraseService {
  AlertPhraseService._();

  /// Returns the localized spoken phrase for [type] in [lang].
  ///
  /// If [lang] has no entry for [type] the English phrase is returned.
  /// Returns `null` when [type] has no entry in the phrase map at all (callers
  /// should then fall back to the alert's display message).
  static String? phrase(AlertType type, TtsLanguage lang) {
    final map = _phrases[type];
    if (map == null) return null;
    return map[lang] ?? map[TtsLanguage.en];
  }

  // ---------------------------------------------------------------------------
  // Phrase map
  // ---------------------------------------------------------------------------

  static const Map<AlertType, Map<TtsLanguage, String>> _phrases = {
    // ---- Speed alerts -------------------------------------------------------
    AlertType.overSpeed: {
      TtsLanguage.en: 'Reduce speed. You are exceeding the speed limit.',
      TtsLanguage.es:
          'Reduzca la velocidad. Está superando el límite de velocidad.',
      TtsLanguage.ht: 'Ralanti. Ou depase limit vites la.',
    },
    AlertType.commercialOverSpeed: {
      TtsLanguage.en:
          'Reduce speed. You are exceeding the commercial speed limit.',
      TtsLanguage.es:
          'Reduzca la velocidad. Está superando el límite comercial.',
      TtsLanguage.ht: 'Ralanti. Ou depase limit vites komèsyal la.',
    },
    AlertType.underSpeed: {
      TtsLanguage.en: 'You are below the speed limit.',
      TtsLanguage.es: 'Está por debajo del límite de velocidad.',
      TtsLanguage.ht: 'Ou anba limit vites la.',
    },
    // ---- Hazard alerts ------------------------------------------------------
    AlertType.sharpCurveHazard: {
      TtsLanguage.en: 'Sharp curve ahead. Reduce speed.',
      TtsLanguage.es: 'Curva cerrada adelante. Reduzca la velocidad.',
      TtsLanguage.ht: 'Koub pikan devan. Ralanti.',
    },
    AlertType.lowBridgeHazard: {
      TtsLanguage.en: 'Low bridge ahead. Check your vehicle height.',
      TtsLanguage.es:
          'Puente bajo adelante. Verifique la altura de su vehículo.',
      TtsLanguage.ht: 'Pon ba devan. Tcheke wotè veyikil ou.',
    },
    AlertType.downgradeHillHazard: {
      TtsLanguage.en: 'Steep downgrade ahead. Use lower gear.',
      TtsLanguage.es: 'Pendiente pronunciada adelante. Use una marcha menor.',
      TtsLanguage.ht: 'Desann rèd devan. Itilize yon vitès ki pi ba.',
    },
    AlertType.workZoneHazard: {
      TtsLanguage.en:
          'Work zone ahead. Reduce speed and watch for workers.',
      TtsLanguage.es:
          'Zona de obras adelante. Reduzca la velocidad y preste atención.',
      TtsLanguage.ht:
          'Zòn travay devan. Ralanti epi fè atansyon ak travayè.',
    },
    AlertType.schoolZoneHazard: {
      TtsLanguage.en:
          'School zone ahead. Reduce speed and watch for children.',
      TtsLanguage.es:
          'Zona escolar adelante. Reduzca la velocidad y preste atención a los niños.',
      TtsLanguage.ht:
          'Zòn lekòl devan. Ralanti epi fè atansyon ak timoun.',
    },
    AlertType.railroadCrossingHazard: {
      TtsLanguage.en:
          'Railroad crossing ahead. Reduce speed and watch for trains.',
      TtsLanguage.es:
          'Cruce de ferrocarril adelante. Reduzca la velocidad y preste atención a los trenes.',
      TtsLanguage.ht:
          'Kwazman tren devan. Ralanti epi fè atansyon ak tren.',
    },
    AlertType.slipperyRoadHazard: {
      TtsLanguage.en: 'Slippery road ahead. Reduce speed.',
      TtsLanguage.es: 'Carretera resbaladiza adelante. Reduzca la velocidad.',
      TtsLanguage.ht: 'Wout glise devan. Ralanti.',
    },
    AlertType.truckRolloverHazard: {
      TtsLanguage.en:
          'Rollover warning ahead. Reduce speed on sharp turns.',
      TtsLanguage.es:
          'Advertencia de volcamiento adelante. Reduzca la velocidad en curvas.',
      TtsLanguage.ht:
          'Avètisman chavirement devan. Ralanti nan vire rapid.',
    },
    AlertType.tunnelHazard: {
      TtsLanguage.en:
          'Tunnel ahead. Check height and hazmat restrictions before entering.',
      TtsLanguage.es:
          'Túnel adelante. Verifique restricciones de altura y materiales peligrosos.',
      TtsLanguage.ht:
          'Tinel devan. Tcheke wotè ak restriksyon matye danjere.',
    },
    AlertType.narrowBridgeHazard: {
      TtsLanguage.en: 'Narrow bridge ahead. Proceed with caution.',
      TtsLanguage.es: 'Puente estrecho adelante. Proceda con precaución.',
      TtsLanguage.ht: 'Pon etwa devan. Kontinye avèk prekosyon.',
    },
    AlertType.stopSignHazard: {
      TtsLanguage.en: 'Stop sign ahead. Prepare to stop.',
      TtsLanguage.es: 'Señal de parada adelante. Prepárese para detenerse.',
      TtsLanguage.ht: 'Siy stop devan. Prepare pou kanpe.',
    },
    AlertType.truckCrossingHazard: {
      TtsLanguage.en: 'Truck crossing ahead. Watch for crossing trucks.',
      TtsLanguage.es:
          'Cruce de camiones adelante. Preste atención a los camiones.',
      TtsLanguage.ht: 'Kwazman kamyon devan. Fè atansyon ak kamyon.',
    },
    AlertType.wildAnimalCrossingHazard: {
      TtsLanguage.en:
          'Wildlife crossing ahead. Watch for animals on the road.',
      TtsLanguage.es:
          'Cruce de animales salvajes adelante. Preste atención a los animales.',
      TtsLanguage.ht:
          'Kwazman bèt sovaj devan. Fè atansyon ak bèt sou wout la.',
    },
    AlertType.mergingTrafficHazard: {
      TtsLanguage.en:
          'Merging traffic ahead. Watch for vehicles entering.',
      TtsLanguage.es:
          'Tráfico de incorporación adelante. Preste atención a los vehículos.',
      TtsLanguage.ht:
          'Trafik k ap rantre devan. Fè atansyon ak veyikil ki rantre.',
    },
    AlertType.fallingRocksHazard: {
      TtsLanguage.en:
          'Falling rocks zone ahead. Watch for debris on the road.',
      TtsLanguage.es:
          'Zona de caída de rocas adelante. Preste atención a los escombros.',
      TtsLanguage.ht:
          'Zòn wòch ki tonbe devan. Fè atansyon ak debri sou wout la.',
    },
    // ---- Route / navigation alerts ------------------------------------------
    AlertType.reroute: {
      TtsLanguage.en: 'Route updated. A new route has been calculated.',
      TtsLanguage.es: 'Ruta actualizada. Se ha calculado una nueva ruta.',
      TtsLanguage.ht: 'Wout mete ajou. Yon nouvo wout kalkile.',
    },
    AlertType.offRoute: {
      TtsLanguage.en: 'Off route. Recalculating.',
      TtsLanguage.es: 'Fuera de ruta. Recalculando.',
      TtsLanguage.ht: 'Deye wout. Kap recalcule.',
    },
  };
}
