import 'package:realms/game/engine/engine.dart' show GameConfiguration;

/// An immutable stage definition belonging to Campaign mode.
///
/// A campaign level identifies a stage and composes its gameplay rules.
/// The actual tiles remain represented by integer evolution levels in
/// `GameBoard`; the campaign [number] is a different concept.
///
/// Campaign definitions contain data only. A `GameState` starts a stage using
/// its [configuration], and the application manages level selection.
final class CampaignLevel {
  /// Defines a campaign level with a positive [number] and a victory goal.
  ///
  /// A campaign level must supply [GameConfiguration.objective]. Endless
  /// games should use a [GameConfiguration] directly, without this wrapper.
  new({required this.number, required this.configuration}) {
    if (number <= 0) {
      throw ArgumentError.value(number, 'number', 'Must be greater than zero.');
    }

    if (configuration.objective == null) {
      throw ArgumentError.value(
        configuration.objective,
        'configuration.objective',
        'A campaign level requires a victory objective.',
      );
    }
  }

  /// The one-based campaign level number, independent of tile evolution.
  final int number;

  /// The immutable rules and victory objective used by this campaign level.
  final GameConfiguration configuration;
}
