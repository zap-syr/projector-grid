/// Temperature tint thresholds (°C) shared by the Monitoring table and the
/// Web UI (`/api/config`).
///
/// Intake tracks the projectors' 0–45 °C operating spec — units raise a
/// temperature fault around 45 °C and shut down near 50 °C. Exhaust is
/// `QTM:1`, the internal optics / around-lamp sensor, which Panasonic never
/// gives a numeric limit for (only the qualitative TEMP indicator), so these
/// are a deliberately high heuristic to avoid false alarms — tune once there
/// is field data.
library;

typedef TempThreshold = ({double warm, double hot});

const TempThreshold kIntakeTempThreshold = (warm: 40, hot: 45);
const TempThreshold kExhaustTempThreshold = (warm: 55, hot: 65);
