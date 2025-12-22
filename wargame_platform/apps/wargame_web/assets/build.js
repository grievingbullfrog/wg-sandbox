import * as esbuild from 'esbuild';
import { solidPlugin } from 'esbuild-plugin-solid';

const watch = process.argv.includes('--watch');

const ctx = await esbuild.context({
  entryPoints: ['js/app.js'],
  bundle: true,
  outdir: '../priv/static/assets',
  format: 'esm',
  target: 'es2020',
  splitting: true,
  sourcemap: true,
  minify: !watch,
  plugins: [solidPlugin()],
  loader: {
    '.ts': 'ts',
    '.tsx': 'tsx',
  },
  external: [
    '/fonts/*',
    '/images/*',
    'phoenix',
    'phoenix_html',
    'phoenix_live_view',
    'phoenix-colocated/*',
  ],
});

if (watch) {
  await ctx.watch();
  console.log('Watching for changes...');
} else {
  await ctx.rebuild();
  await ctx.dispose();
  console.log('Build complete!');
}
