#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Verify that console logs have been removed from production builds
 */
async function verifyConsoleRemoval() {
  console.log('🔍 Verifying console log removal from production build...\n');

  const distDir = path.resolve(__dirname, '../dist');
  const publicDir = path.resolve(distDir, 'public');
  const serverFile = path.resolve(distDir, 'index.js');

  let totalFiles = 0;
  let filesWithConsole = 0;
  let consoleStatements = [];

  // Function to check a file for console statements
  function checkFile(filePath, relativePath) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      totalFiles++;

      // Patterns to match console statements
      const consolePatterns = [
        /console\.(log|info|debug|warn|trace|error)\s*\(/g,
        /console\[['"](?:log|info|debug|warn|trace|error)['"]\]\s*\(/g,
      ];

      let hasConsole = false;
      let matches = [];

      consolePatterns.forEach(pattern => {
        let match;
        while ((match = pattern.exec(content)) !== null) {
          hasConsole = true;
          const lineNumber = content.substring(0, match.index).split('\n').length;
          matches.push({
            type: match[1] || 'unknown',
            line: lineNumber,
            context: content.substring(
              Math.max(0, match.index - 50),
              Math.min(content.length, match.index + 100)
            ).replace(/\n/g, ' ').trim()
          });
        }
      });

      if (hasConsole) {
        filesWithConsole++;
        consoleStatements.push({
          file: relativePath,
          matches: matches
        });
      }

      return { hasConsole, matchCount: matches.length };
    } catch (error) {
      console.warn(`⚠️ Could not read file: ${relativePath} - ${error.message}`);
      return { hasConsole: false, matchCount: 0 };
    }
  }

  // Function to recursively scan directory
  function scanDirectory(dir, baseDir = dir) {
    const items = fs.readdirSync(dir);
    
    for (const item of items) {
      const fullPath = path.join(dir, item);
      const relativePath = path.relative(baseDir, fullPath);
      const stat = fs.statSync(fullPath);

      if (stat.isDirectory()) {
        // Skip node_modules and other irrelevant directories
        if (!['node_modules', '.git', '.vscode'].includes(item)) {
          scanDirectory(fullPath, baseDir);
        }
      } else if (stat.isFile()) {
        // Check JavaScript and TypeScript files
        if (/\.(js|ts|jsx|tsx|mjs|cjs)$/.test(item)) {
          checkFile(fullPath, relativePath);
        }
      }
    }
  }

  // Check if dist directory exists
  if (!fs.existsSync(distDir)) {
    console.error('❌ Dist directory not found. Please run a build first.');
    console.log('   Run: npm run build');
    process.exit(1);
  }

  console.log('📁 Scanning production build files...\n');

  // Scan client build (public directory)
  if (fs.existsSync(publicDir)) {
    console.log('🌐 Checking client build (frontend)...');
    scanDirectory(publicDir);
  }

  // Check server build
  if (fs.existsSync(serverFile)) {
    console.log('🖥️ Checking server build (backend)...');
    checkFile(serverFile, 'index.js');
  }

  // Report results
  console.log('\n📊 Console Log Removal Report');
  console.log('================================');
  console.log(`Total files scanned: ${totalFiles}`);
  console.log(`Files with console statements: ${filesWithConsole}`);
  
  if (filesWithConsole === 0) {
    console.log('✅ SUCCESS: No console statements found in production build!');
    console.log('🔒 Console logs have been successfully removed for production.');
  } else {
    console.log('❌ WARNING: Console statements found in production build!');
    console.log('\n📋 Detailed findings:');
    
    consoleStatements.forEach(({ file, matches }) => {
      console.log(`\n📄 File: ${file}`);
      matches.forEach(({ type, line, context }) => {
        console.log(`   Line ${line}: console.${type}() - ${context}`);
      });
    });

    console.log('\n💡 Recommendations:');
    console.log('   1. Check your build configuration');
    console.log('   2. Ensure NODE_ENV=production is set during build');
    console.log('   3. Verify Vite and ESBuild console removal settings');
    console.log('   4. Some console.error statements may be intentionally preserved');
  }

  // Summary statistics
  const totalConsoleStatements = consoleStatements.reduce(
    (sum, file) => sum + file.matches.length, 0
  );
  
  console.log(`\n📈 Statistics:`);
  console.log(`   - Total console statements: ${totalConsoleStatements}`);
  console.log(`   - Files affected: ${filesWithConsole}/${totalFiles}`);
  console.log(`   - Removal rate: ${((totalFiles - filesWithConsole) / totalFiles * 100).toFixed(1)}%`);

  // Exit with appropriate code
  if (filesWithConsole > 0) {
    // Allow console.error statements in production
    const onlyErrors = consoleStatements.every(file => 
      file.matches.every(match => match.type === 'error')
    );
    
    if (onlyErrors) {
      console.log('\n✅ Only console.error statements found - this is acceptable for production.');
      process.exit(0);
    } else {
      console.log('\n❌ Non-error console statements found in production build.');
      process.exit(1);
    }
  } else {
    process.exit(0);
  }
}

// Run verification
verifyConsoleRemoval().catch(error => {
  console.error('❌ Verification failed:', error);
  process.exit(1);
});
