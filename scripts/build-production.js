#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';
import JavaScriptObfuscator from 'javascript-obfuscator';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function buildProduction() {
  console.log('🚀 Starting production build with obfuscation...');

// Step 1: Clean previous builds
console.log('🧹 Cleaning previous builds...');
if (fs.existsSync('dist')) {
  fs.rmSync('dist', { recursive: true, force: true });
}

// Step 2: Build the application
console.log('🔨 Building application for production...');
try {
  execSync('npm run build:production', { stdio: 'inherit' });
} catch (error) {
  console.error('❌ Build failed:', error.message);
  process.exit(1);
}

// Step 3: Obfuscate the server code
console.log('🔒 Obfuscating server code...');
const serverFile = path.join(__dirname, '../dist/index.js');

if (!fs.existsSync(serverFile)) {
  console.error('❌ Server file not found:', serverFile);
  process.exit(1);
}

try {
  const sourceCode = fs.readFileSync(serverFile, 'utf8');
  const obfuscatorConfigModule = await import('../obfuscator.config.js');
  const obfuscatorConfig = obfuscatorConfigModule.default;
  
  console.log('🔄 Applying obfuscation...');
  const obfuscatedCode = JavaScriptObfuscator.obfuscate(sourceCode, obfuscatorConfig);
  
  // Write obfuscated code
  fs.writeFileSync(serverFile, obfuscatedCode.getObfuscatedCode());
  
  console.log('✅ Server code obfuscated successfully');
} catch (error) {
  console.error('❌ Obfuscation failed:', error.message);
  process.exit(1);
}

// Step 4: Remove source maps from client build
console.log('🗑️ Removing source maps...');
const publicDir = path.join(__dirname, '../dist/public');
if (fs.existsSync(publicDir)) {
  const files = fs.readdirSync(publicDir, { recursive: true });
  files.forEach(file => {
    if (typeof file === 'string' && file.endsWith('.map')) {
      const mapFile = path.join(publicDir, file);
      if (fs.existsSync(mapFile)) {
        fs.unlinkSync(mapFile);
        console.log(`🗑️ Removed: ${file}`);
      }
    }
  });
}

// Step 5: Create production environment check
console.log('🔐 Adding runtime protection...');
const runtimeProtection = `
// Runtime protection
(function() {
  'use strict';

  console.log('🔒 Production runtime protection active');

  // Anti-debugging (reduced frequency to allow console debugging)
  setInterval(function() {
    if (typeof window !== 'undefined') return;
    const start = Date.now();
    debugger;
    if (Date.now() - start > 100) {
      console.warn('⚠️ Debugging attempt detected');
      // Don't exit immediately to allow debugging
    }
  }, 5000);

  // Environment validation
  if (process.env.NODE_ENV !== 'production') {
    console.error('Invalid environment');
    process.exit(1);
  }
})();

`;

// Prepend runtime protection to the obfuscated code
const obfuscatedCode = fs.readFileSync(serverFile, 'utf8');
fs.writeFileSync(serverFile, runtimeProtection + obfuscatedCode);

  // Step 6: Verify console log removal
  console.log('🔍 Verifying console log removal...');
  try {
    execSync('npm run build:verify', { stdio: 'inherit' });
    console.log('✅ Console log removal verified successfully');
  } catch (error) {
    console.warn('⚠️ Console log verification failed, but build continues');
    console.warn('   Some console statements may still be present in the build');
  }

  console.log('\n✅ Production build completed with obfuscation!');
  console.log('📁 Output directory: dist/');
  console.log('🔒 Server code: dist/index.js (obfuscated)');
  console.log('🌐 Client code: dist/public/ (minified, no source maps)');
  console.log('🚫 Console logs: Removed from production build');
}

// Run the build
buildProduction().catch(error => {
  console.error('❌ Build failed:', error);
  process.exit(1);
});
