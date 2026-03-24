const { Resvg } = require('@resvg/resvg-js');
const fs = require('fs');
const path = require('path');

const svgPath  = path.resolve(__dirname, '../../assets/launcher_icon/preview.svg');
const pngPath  = path.resolve(__dirname, '../../assets/launcher_icon/app_icon.png');
const size     = 1024;

const svg = fs.readFileSync(svgPath);
const resvg = new Resvg(svg, {
  fitTo: { mode: 'width', value: size },
  font: { loadSystemFonts: false },
});

const rendered = resvg.render();
const png = rendered.asPng();

fs.mkdirSync(path.dirname(pngPath), { recursive: true });
fs.writeFileSync(pngPath, png);
console.log(`Generated: ${pngPath} (${rendered.width}x${rendered.height})`);
