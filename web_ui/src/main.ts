import '@fontsource/ibm-plex-mono/latin-400.css';
import '@fontsource/ibm-plex-mono/latin-500.css';
import '@fontsource/ibm-plex-mono/latin-600.css';
import './styles/fonts.css';
import './styles/tokens.css';

import { mount } from 'svelte';

import App from './App.svelte';

const target = document.getElementById('app');
if (!target) throw new Error('#app element missing from index.html');

export default mount(App, { target });
