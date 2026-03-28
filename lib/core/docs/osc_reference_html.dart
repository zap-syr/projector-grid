/// HTML content for the OSC reference documentation page.
/// Written to the app data directory and opened in the system browser.
const String oscReferenceHtml = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OSC Reference — Projectors Manager</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      font-size: 14px;
      line-height: 1.6;
      color: #1a1a2e;
      background: #f8f9fc;
    }

    .page {
      max-width: 860px;
      margin: 0 auto;
      padding: 48px 32px 80px;
    }

    h1 {
      font-size: 26px;
      font-weight: 700;
      color: #0d1b2a;
      margin-bottom: 6px;
    }

    .subtitle {
      color: #6b7280;
      margin-bottom: 40px;
      font-size: 13px;
    }

    h2 {
      font-size: 17px;
      font-weight: 700;
      color: #0d1b2a;
      margin: 40px 0 12px;
      padding-bottom: 6px;
      border-bottom: 2px solid #e5e7eb;
    }

    h3 {
      font-size: 13px;
      font-weight: 700;
      color: #374151;
      margin: 24px 0 8px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    p { margin-bottom: 10px; }

    code {
      font-family: "SFMono-Regular", "Cascadia Code", "Consolas", monospace;
      font-size: 12.5px;
      background: #e8edf5;
      color: #1e3a5f;
      padding: 2px 6px;
      border-radius: 4px;
    }

    .pattern-box {
      background: #1e3a5f;
      color: #e2f0fb;
      font-family: "SFMono-Regular", "Cascadia Code", "Consolas", monospace;
      font-size: 14px;
      padding: 14px 20px;
      border-radius: 8px;
      margin: 12px 0 6px;
    }

    .pattern-box .comment {
      color: #7eb8d8;
      font-size: 12px;
    }

    .example {
      font-size: 12.5px;
      color: #6b7280;
      margin-bottom: 16px;
    }

    .example code {
      background: #f0f4fa;
      color: #374151;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 8px;
      font-size: 13px;
    }

    thead th {
      text-align: left;
      background: #eef1f7;
      color: #374151;
      font-weight: 600;
      padding: 8px 12px;
      border-bottom: 1px solid #d1d5db;
    }

    tbody tr:nth-child(even) { background: #f8f9fc; }
    tbody tr:nth-child(odd)  { background: #ffffff; }

    tbody td {
      padding: 6px 12px;
      border-bottom: 1px solid #e5e7eb;
      vertical-align: top;
    }

    tbody td:first-child { width: 46%; }

    .tag {
      display: inline-block;
      font-size: 11px;
      font-weight: 600;
      background: #dbeafe;
      color: #1e40af;
      padding: 1px 7px;
      border-radius: 10px;
      margin-right: 4px;
      vertical-align: middle;
    }

    .outgoing-table tbody td:first-child { width: 38%; }
    .outgoing-table tbody td:nth-child(2) { width: 14%; }

    .note {
      background: #fffbeb;
      border-left: 3px solid #f59e0b;
      padding: 10px 14px;
      border-radius: 0 6px 6px 0;
      font-size: 13px;
      margin: 16px 0;
      color: #78350f;
    }

    nav {
      background: #ffffff;
      border: 1px solid #e5e7eb;
      border-radius: 8px;
      padding: 16px 20px;
      margin-bottom: 36px;
    }

    nav p { font-weight: 600; margin-bottom: 8px; font-size: 13px; }

    nav ul {
      list-style: none;
      display: flex;
      flex-wrap: wrap;
      gap: 4px 20px;
    }

    nav a {
      color: #1e40af;
      text-decoration: none;
      font-size: 13px;
    }

    nav a:hover { text-decoration: underline; }

    .fade-values { font-size: 12px; color: #6b7280; }
  </style>
</head>
<body>
<div class="page">

  <h1>OSC Reference</h1>
  <p class="subtitle">Projectors Manager — Open Sound Control integration guide</p>

  <nav>
    <p>Contents</p>
    <ul>
      <li><a href="#sending">Sending Commands</a></li>
      <li><a href="#power">Power</a></li>
      <li><a href="#shutter">Shutter</a></li>
      <li><a href="#osd">OSD</a></li>
      <li><a href="#input">Input</a></li>
      <li><a href="#lens">Lens Shift</a></li>
      <li><a href="#focus">Focus</a></li>
      <li><a href="#zoom">Zoom</a></li>
      <li><a href="#testpattern">Test Patterns</a></li>
      <li><a href="#picturemode">Picture Mode</a></li>
      <li><a href="#backcolor">Back Color</a></li>
      <li><a href="#startuplogo">Startup Logo</a></li>
      <li><a href="#projection">Projection Method</a></li>
      <li><a href="#quadpixel">Quad Pixel Drive</a></li>
      <li><a href="#custom">Custom Commands</a></li>
      <li><a href="#outgoing">Outgoing Status</a></li>
    </ul>
  </nav>

  <!-- ─── SENDING COMMANDS ─── -->
  <h2 id="sending">Sending Commands</h2>

  <p>All incoming commands follow one of two patterns — target all projectors, or target a named group. Append any command from the reference below to either prefix.</p>

  <h3>All projectors</h3>
  <div class="pattern-box">/prjmgr/all/<span style="color:#a8d8ff">{command}</span></div>
  <p class="example">Example: <code>/prjmgr/all/power/on</code> &nbsp;·&nbsp; <code>/prjmgr/all/shutter/open</code></p>

  <h3>Named group</h3>
  <div class="pattern-box">/prjmgr/group/<span style="color:#a8d8ff">{group-name}</span>/<span style="color:#a8d8ff">{command}</span></div>
  <p class="example">
    <code>{group-name}</code> is the OSC address set on the group — e.g. a group with OSC address <code>/group/stage</code> uses <code>stage</code> as the name.<br>
    Example: <code>/prjmgr/group/stage/shutter/open</code> &nbsp;·&nbsp; <code>/prjmgr/group/auditorium/power/off</code>
  </p>

  <div class="note">
    OSC messages do not carry arguments — the address alone determines the action.
  </div>

  <!-- ─── POWER ─── -->
  <h2 id="power">Power</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>power/on</code></td><td>Power on the projector</td></tr>
      <tr><td><code>power/off</code></td><td>Power off (standby)</td></tr>
    </tbody>
  </table>

  <!-- ─── SHUTTER ─── -->
  <h2 id="shutter">Shutter</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>shutter/open</code></td><td>Open shutter (image on)</td></tr>
      <tr><td><code>shutter/close</code></td><td>Close shutter (image off)</td></tr>
      <tr><td><code>shutter-fade-in/0</code></td><td>Set shutter fade-in duration — instant (0 s)</td></tr>
      <tr><td><code>shutter-fade-in/0.5</code></td><td>Shutter fade-in 0.5 s</td></tr>
      <tr><td><code>shutter-fade-in/1</code></td><td>Shutter fade-in 1 s</td></tr>
      <tr><td><code>shutter-fade-in/1.5</code></td><td>Shutter fade-in 1.5 s</td></tr>
      <tr><td><code>shutter-fade-in/2</code></td><td>Shutter fade-in 2 s</td></tr>
      <tr><td><code>shutter-fade-in/3</code></td><td>Shutter fade-in 3 s</td></tr>
      <tr><td><code>shutter-fade-in/5</code></td><td>Shutter fade-in 5 s</td></tr>
      <tr><td><code>shutter-fade-in/7</code></td><td>Shutter fade-in 7 s</td></tr>
      <tr><td><code>shutter-fade-in/10</code></td><td>Shutter fade-in 10 s</td></tr>
      <tr><td><code>shutter-fade-out/0</code></td><td>Set shutter fade-out duration — instant (0 s)</td></tr>
      <tr><td><code>shutter-fade-out/0.5</code></td><td>Shutter fade-out 0.5 s</td></tr>
      <tr><td><code>shutter-fade-out/1</code></td><td>Shutter fade-out 1 s</td></tr>
      <tr><td><code>shutter-fade-out/1.5</code></td><td>Shutter fade-out 1.5 s</td></tr>
      <tr><td><code>shutter-fade-out/2</code></td><td>Shutter fade-out 2 s</td></tr>
      <tr><td><code>shutter-fade-out/3</code></td><td>Shutter fade-out 3 s</td></tr>
      <tr><td><code>shutter-fade-out/5</code></td><td>Shutter fade-out 5 s</td></tr>
      <tr><td><code>shutter-fade-out/7</code></td><td>Shutter fade-out 7 s</td></tr>
      <tr><td><code>shutter-fade-out/10</code></td><td>Shutter fade-out 10 s</td></tr>
    </tbody>
  </table>

  <!-- ─── OSD ─── -->
  <h2 id="osd">OSD</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>osd/on</code></td><td>Show on-screen display</td></tr>
      <tr><td><code>osd/off</code></td><td>Hide on-screen display</td></tr>
    </tbody>
  </table>

  <!-- ─── INPUT ─── -->
  <h2 id="input">Input</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>input/hdmi1</code></td><td>Select HDMI 1</td></tr>
      <tr><td><code>input/hdmi2</code></td><td>Select HDMI 2</td></tr>
      <tr><td><code>input/sdi1</code></td><td>Select SDI 1</td></tr>
      <tr><td><code>input/sdi2</code></td><td>Select SDI 2</td></tr>
      <tr><td><code>input/digital-link</code></td><td>Select Digital Link</td></tr>
      <tr><td><code>input/dvi-d</code></td><td>Select DVI-D</td></tr>
      <tr><td><code>input/displayport</code></td><td>Select DisplayPort</td></tr>
    </tbody>
  </table>

  <!-- ─── LENS SHIFT ─── -->
  <h2 id="lens">Lens Shift</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>lens/shift/up/slow</code></td><td>Shift lens up — slow speed</td></tr>
      <tr><td><code>lens/shift/up/normal</code></td><td>Shift lens up — normal speed</td></tr>
      <tr><td><code>lens/shift/up/fast</code></td><td>Shift lens up — fast speed</td></tr>
      <tr><td><code>lens/shift/down/slow</code></td><td>Shift lens down — slow speed</td></tr>
      <tr><td><code>lens/shift/down/normal</code></td><td>Shift lens down — normal speed</td></tr>
      <tr><td><code>lens/shift/down/fast</code></td><td>Shift lens down — fast speed</td></tr>
      <tr><td><code>lens/shift/left/slow</code></td><td>Shift lens left — slow speed</td></tr>
      <tr><td><code>lens/shift/left/normal</code></td><td>Shift lens left — normal speed</td></tr>
      <tr><td><code>lens/shift/left/fast</code></td><td>Shift lens left — fast speed</td></tr>
      <tr><td><code>lens/shift/right/slow</code></td><td>Shift lens right — slow speed</td></tr>
      <tr><td><code>lens/shift/right/normal</code></td><td>Shift lens right — normal speed</td></tr>
      <tr><td><code>lens/shift/right/fast</code></td><td>Shift lens right — fast speed</td></tr>
      <tr><td><code>lens/home</code></td><td>Move lens to home position</td></tr>
      <tr><td><code>lens/calibration</code></td><td>Run lens calibration</td></tr>
    </tbody>
  </table>

  <!-- ─── FOCUS ─── -->
  <h2 id="focus">Focus</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>focus/near/slow</code></td><td>Focus near — slow speed</td></tr>
      <tr><td><code>focus/near/normal</code></td><td>Focus near — normal speed</td></tr>
      <tr><td><code>focus/near/fast</code></td><td>Focus near — fast speed</td></tr>
      <tr><td><code>focus/far/slow</code></td><td>Focus far — slow speed</td></tr>
      <tr><td><code>focus/far/normal</code></td><td>Focus far — normal speed</td></tr>
      <tr><td><code>focus/far/fast</code></td><td>Focus far — fast speed</td></tr>
    </tbody>
  </table>

  <!-- ─── ZOOM ─── -->
  <h2 id="zoom">Zoom</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>zoom/in/slow</code></td><td>Zoom in (tele) — slow speed</td></tr>
      <tr><td><code>zoom/in/normal</code></td><td>Zoom in (tele) — normal speed</td></tr>
      <tr><td><code>zoom/in/fast</code></td><td>Zoom in (tele) — fast speed</td></tr>
      <tr><td><code>zoom/out/slow</code></td><td>Zoom out (wide) — slow speed</td></tr>
      <tr><td><code>zoom/out/normal</code></td><td>Zoom out (wide) — normal speed</td></tr>
      <tr><td><code>zoom/out/fast</code></td><td>Zoom out (wide) — fast speed</td></tr>
    </tbody>
  </table>

  <!-- ─── TEST PATTERNS ─── -->
  <h2 id="testpattern">Test Patterns</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>testpattern/off</code></td><td>Disable test pattern</td></tr>
      <tr><td><code>testpattern/white</code></td><td>All white</td></tr>
      <tr><td><code>testpattern/black</code></td><td>All black</td></tr>
      <tr><td><code>testpattern/red</code></td><td>All red</td></tr>
      <tr><td><code>testpattern/green</code></td><td>All green</td></tr>
      <tr><td><code>testpattern/blue</code></td><td>All blue</td></tr>
      <tr><td><code>testpattern/cyan</code></td><td>All cyan</td></tr>
      <tr><td><code>testpattern/magenta</code></td><td>All magenta</td></tr>
      <tr><td><code>testpattern/yellow</code></td><td>All yellow</td></tr>
      <tr><td><code>testpattern/window</code></td><td>Window pattern</td></tr>
      <tr><td><code>testpattern/reversed-window</code></td><td>Reversed window pattern</td></tr>
      <tr><td><code>testpattern/color-bars-vertical</code></td><td>Vertical color bars</td></tr>
      <tr><td><code>testpattern/color-bars-horizontal</code></td><td>Horizontal color bars</td></tr>
      <tr><td><code>testpattern/focus</code></td><td>Focus pattern</td></tr>
      <tr><td><code>testpattern/aspect-frame</code></td><td>Aspect frame</td></tr>
      <tr><td><code>testpattern/cross-hatch</code></td><td>Cross-hatch (white)</td></tr>
      <tr><td><code>testpattern/cross-hatch-red</code></td><td>Cross-hatch red</td></tr>
      <tr><td><code>testpattern/cross-hatch-green</code></td><td>Cross-hatch green</td></tr>
      <tr><td><code>testpattern/cross-hatch-blue</code></td><td>Cross-hatch blue</td></tr>
      <tr><td><code>testpattern/cross-hatch-cyan</code></td><td>Cross-hatch cyan</td></tr>
      <tr><td><code>testpattern/cross-hatch-magenta</code></td><td>Cross-hatch magenta</td></tr>
      <tr><td><code>testpattern/cross-hatch-yellow</code></td><td>Cross-hatch yellow</td></tr>
      <tr><td><code>testpattern/circle</code></td><td>Circle pattern</td></tr>
    </tbody>
  </table>

  <!-- ─── PICTURE MODE ─── -->
  <h2 id="picturemode">Picture Mode</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>picture-mode/dynamic</code></td><td>Dynamic mode</td></tr>
      <tr><td><code>picture-mode/natural</code></td><td>Natural mode</td></tr>
      <tr><td><code>picture-mode/standard</code></td><td>Standard mode</td></tr>
      <tr><td><code>picture-mode/cinema</code></td><td>Cinema mode</td></tr>
      <tr><td><code>picture-mode/graphic</code></td><td>Graphic mode</td></tr>
      <tr><td><code>picture-mode/dicom-sim</code></td><td>DICOM simulation mode</td></tr>
      <tr><td><code>picture-mode/rec709</code></td><td>Rec.709 mode</td></tr>
      <tr><td><code>picture-mode/user</code></td><td>User mode</td></tr>
    </tbody>
  </table>

  <!-- ─── BACK COLOR ─── -->
  <h2 id="backcolor">Back Color</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>back-color/blue</code></td><td>Blue background when no signal</td></tr>
      <tr><td><code>back-color/black</code></td><td>Black background when no signal</td></tr>
      <tr><td><code>back-color/user-logo</code></td><td>User logo when no signal</td></tr>
      <tr><td><code>back-color/default-logo</code></td><td>Default logo when no signal</td></tr>
    </tbody>
  </table>

  <!-- ─── STARTUP LOGO ─── -->
  <h2 id="startuplogo">Startup Logo</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>startup-logo/off</code></td><td>No logo on startup</td></tr>
      <tr><td><code>startup-logo/user-logo</code></td><td>Show user logo on startup</td></tr>
      <tr><td><code>startup-logo/default-logo</code></td><td>Show default logo on startup</td></tr>
    </tbody>
  </table>

  <!-- ─── PROJECTION METHOD ─── -->
  <h2 id="projection">Projection Method</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>projection/front-desk</code></td><td>Front, desk mounted</td></tr>
      <tr><td><code>projection/rear-desk</code></td><td>Rear, desk mounted</td></tr>
      <tr><td><code>projection/front-ceiling</code></td><td>Front, ceiling mounted</td></tr>
      <tr><td><code>projection/rear-ceiling</code></td><td>Rear, ceiling mounted</td></tr>
      <tr><td><code>projection/front-auto</code></td><td>Front, auto-detect orientation</td></tr>
      <tr><td><code>projection/rear-auto</code></td><td>Rear, auto-detect orientation</td></tr>
    </tbody>
  </table>

  <!-- ─── QUAD PIXEL DRIVE ─── -->
  <h2 id="quadpixel">Quad Pixel Drive</h2>
  <table>
    <thead><tr><th>Command</th><th>Description</th></tr></thead>
    <tbody>
      <tr><td><code>quad-pixel/on</code></td><td>Enable quad pixel drive</td></tr>
      <tr><td><code>quad-pixel/off</code></td><td>Disable quad pixel drive</td></tr>
    </tbody>
  </table>

  <!-- ─── CUSTOM COMMANDS ─── -->
  <h2 id="custom">Custom Commands</h2>

  <p>Commands created in the <strong>Custom</strong> tab of the control bar can be triggered via OSC using the same all/group patterns:</p>

  <div class="pattern-box">
    /prjmgr/all/custom/<span style="color:#a8d8ff">{slug}</span><br>
    /prjmgr/group/<span style="color:#a8d8ff">{group-name}</span>/custom/<span style="color:#a8d8ff">{slug}</span>
  </div>

  <p>The <code>{slug}</code> is automatically derived from the command name: lowercase, with spaces and special characters replaced by hyphens. It is shown in the OSC address preview when creating or editing a custom command.</p>

  <p class="example">Example: a command named <em>"Warm Up Sequence"</em> gets the slug <code>warm-up-sequence</code>, so its OSC address is <code>/prjmgr/all/custom/warm-up-sequence</code>.</p>

  <!-- ─── OUTGOING STATUS ─── -->
  <h2 id="outgoing">Outgoing Status Messages</h2>

  <p>The app sends status updates over UDP whenever projector counts change. Your system receives these on the configured send IP and send port.</p>

  <table class="outgoing-table">
    <thead>
      <tr><th>Address</th><th>Value type</th><th>Sent when</th></tr>
    </thead>
    <tbody>
      <tr>
        <td><code>/prjmgr/status/online</code></td>
        <td>int</td>
        <td>Number of connected projectors changes</td>
      </tr>
      <tr>
        <td><code>/prjmgr/status/offline</code></td>
        <td>int</td>
        <td>Number of offline projectors changes</td>
      </tr>
      <tr>
        <td><code>/prjmgr/status/warning</code></td>
        <td>int</td>
        <td>Number of projectors with errors or unauthorized status changes</td>
      </tr>
    </tbody>
  </table>

  <p>Send <code>/prjmgr/status</code> (no arguments) to request all three values immediately, bypassing change detection.</p>

</div>
</body>
</html>
''';
