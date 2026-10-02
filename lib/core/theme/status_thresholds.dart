/// Default temperature thresholds (°C) for the Intake / Exhaust alert rules,
/// which also drive the Monitoring table tint and the Web UI's
/// (`/api/config`). The live values are in `AlertSettings`, editable in
/// Preferences → Alerts.
///
/// Intake tracks the projectors' 0–45 °C operating spec — units raise a
/// temperature fault around 45 °C and shut down near 50 °C. Exhaust is
/// `QTM:1`, the internal optics / around-lamp sensor, which Panasonic never
/// gives a numeric limit for (only the qualitative TEMP indicator), so these
/// are a deliberately high heuristic to avoid false alarms — tune once there
/// is field data.
library;

typedef TempThreshold = ({double warm, double hot});

const TempThreshold kDefaultIntakeTempThreshold = (warm: 40, hot: 45);
const TempThreshold kDefaultExhaustTempThreshold = (warm: 55, hot: 65);

/// A temperature alert clears only this far below its threshold, so a value
/// hovering at the limit doesn't raise and clear on every poll.
const double kTempHysteresis = 2;
