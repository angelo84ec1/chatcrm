#!/usr/bin/env node

import esbuild from 'esbuild';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get build mode from environment or command line arguments
const mode = process.env.NODE_ENV || process.argv[2] || 'development';
const isProduction = mode === 'production';

console.log(`🔨 Building backend for ${mode} mode...`);

// ESBuild configuration
const config = {
  entryPoints: [path.resolve(__dirname, '../server/index.ts')],
  bundle: true,
  platform: 'node',
  format: 'esm',
  outdir: path.resolve(__dirname, '../dist'),
  packages: 'external',
  sourcemap: !isProduction,
  minify: isProduction,
  target: 'node18',
  // Remove console logs and debugger statements in production
  drop: isProduction ? ['console', 'debugger'] : [],
  // Define environment variables
  define: {
    'process.env.NODE_ENV': JSON.stringify(mode),
  },
  // Banner to add at the top of the output file
  banner: {
    js: isProduction 
      ? '// Production build - console logs removed for performance and security'
      : '// Development build - console logs preserved for debugging'
  },
  // Log level
  logLevel: 'info',
  // Color output
  color: true,
};

// No custom plugins needed - ESBuild's built-in drop option handles console removal
config.plugins = [];

// Build function
async function build() {
  try {
    console.log('📦 ESBuild configuration:');
    console.log(`   - Mode: ${mode}`);
    console.log(`   - Minify: ${config.minify}`);
    console.log(`   - Sourcemap: ${config.sourcemap}`);
    console.log(`   - Drop console: ${isProduction}`);
    console.log(`   - Target: ${config.target}`);
    
    const result = await esbuild.build(config);
    
    if (result.errors.length > 0) {
      console.error('❌ Build errors:', result.errors);
      process.exit(1);
    }
    
    if (result.warnings.length > 0) {
      console.warn('⚠️ Build warnings:', result.warnings);
    }
    
    console.log('✅ Backend build completed successfully!');
    
    if (isProduction) {
      console.log('🔒 Console logs have been removed from production build');
    } else {
      console.log('🐛 Console logs preserved for development debugging');
    }
    
  } catch (error) {
    console.error('❌ Build failed:', error);
    process.exit(1);
  }
}

// Run the build
build();
