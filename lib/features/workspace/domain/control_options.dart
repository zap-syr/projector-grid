/// Command choices the control bar offers as dropdowns and the Web API
/// accepts as actions (`web_actions.dart`), keyed by their NTCONTROL command.
/// One list for both, so the web can't offer or send something the app
/// doesn't.
library;

const Map<String, String> kInputOptions = {
  'IIS:HD1': 'HDMI 1',
  'IIS:HD2': 'HDMI 2',
  'IIS:DP1': 'DisplayPort',
  'IIS:DVI': 'DVI-D',
  'IIS:SD1': 'SDI 1',
  'IIS:SD2': 'SDI 2',
  'IIS:DL1': 'Digital Link',
  'IIS:RG1': 'Computer 1',
  'IIS:RG2': 'Computer 2',
  'IIS:VID': 'Video',
  'IIS:SVD': 'Y/C',
};

const Map<String, String> kLensCalibrationOptions = {
  'VXX:LNSI0=+00001': 'All',
  'VXX:LNSI0=+00011': 'Shift',
  'VXX:LNSI0=+00012': 'Focus',
  'VXX:LNSI0=+00013': 'Zoom',
  'VXX:LNSI0=+00021': 'Shift/Focus',
  'VXX:LNSI0=+00022': 'Shift/Zoom',
  'VXX:LNSI0=+00023': 'Focus/Zoom',
};

const Map<String, String> kLensTypeOptions = {
  'VXX:LNEI1=+00001': 'ET-D75LE6',
  'VXX:LNEI1=+00002': 'ET-D75LE10',
  'VXX:LNEI1=+00003': 'ET-D75LE20',
  'VXX:LNEI1=+00004': 'ET-D75LE30',
  'VXX:LNEI1=+00005': 'ET-D75LE40',
  'VXX:LNEI1=+00009': 'ET-D75LE50',
  'VXX:LNEI1=+00006': 'ET-D75LE8',
  'VXX:LNEI1=+00007': 'ET-D75LE95',
  'VXX:LNEI1=+00008': 'ET-D75LE90',
};
