#!/usr/bin/env node


import { spawn } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

process.env.NODE_ENV = 'production';

console.log('🚀 Starting PowerChat Plus in production mode...');
console.log('📍 Working directory:', process.cwd());
console.log('🔧 Node.js version:', process.version);

const serverFile = path.join(__dirname, 'dist', 'index.js');
try {
  const fs = await import('fs');
  if (!fs.existsSync(serverFile)) {
    console.error('❌ Server file not found:', serverFile);
    console.error('💡 Make sure you have extracted all files properly');
    process.exit(1);
  }
  
  const stats = fs.statSync(serverFile);
  console.log(`✅ Server file found: ${Math.round(stats.size / 1024)}KB`);
} catch (error) {
  console.error('❌ Error checking server file:', error.message);
  process.exit(1);
}

const args = ['--require', 'dotenv/config', 'dist/index.js'];

console.log('🔄 Starting server...');
const child = spawn('node', args, {
  stdio: 'inherit',
  env: {
    ...process.env,
    NODE_ENV: 'production'
  }
});

child.on('error', (error) => {
  console.error('❌ Failed to start server:', error.message);
  process.exit(1);
});

child.on('exit', (code) => {
  if (code !== 0) {
    console.error(`❌ Server exited with code ${code}`);
    process.exit(code);
  }
});

process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down gracefully...');
  child.kill('SIGINT');
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Shutting down gracefully...');
  child.kill('SIGTERM');
});
