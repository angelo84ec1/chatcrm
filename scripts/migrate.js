#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class MigrationRunner {
  constructor() {
    if (!process.env.DATABASE_URL) {
      throw new Error('DATABASE_URL environment variable is required');
    }
    
    this.pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.PGSSLMODE === 'disable' ? false : { rejectUnauthorized: false }
    });
  }

  async ensureMigrationsTable() {
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS migrations (
        id SERIAL PRIMARY KEY,
        filename VARCHAR(255) NOT NULL UNIQUE,
        checksum VARCHAR(64) NOT NULL,
        executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `;
    
    await this.pool.query(createTableQuery);
    console.log('✅ Migrations table ensured');
  }

  async getExecutedMigrations() {
    const result = await this.pool.query('SELECT filename FROM migrations ORDER BY id');
    return result.rows.map(row => row.filename);
  }

  async calculateChecksum(content) {
    const crypto = await import('crypto');
    return crypto.createHash('sha256').update(content).digest('hex');
  }

  async executeMigration(filename) {
    const filePath = path.join(__dirname, '../migrations', filename);
    
    if (!fs.existsSync(filePath)) {
      throw new Error(`Migration file not found: ${filename}`);
    }

    console.log(`🔄 Executing migration: ${filename}`);
    
    const content = fs.readFileSync(filePath, 'utf8');
    const checksum = await this.calculateChecksum(content);

    // Execute the migration
    await this.pool.query(content);
    
    // Record the migration
    await this.pool.query(
      'INSERT INTO migrations (filename, checksum) VALUES ($1, $2)',
      [filename, checksum]
    );
    
    console.log(`✅ Migration completed: ${filename}`);
  }

  async runMigrations() {
    try {
      console.log('🚀 Starting database migration process...');
      
      await this.ensureMigrationsTable();
      
      const migrationsDir = path.join(__dirname, '../migrations');
      const migrationFiles = fs.readdirSync(migrationsDir)
        .filter(file => file.endsWith('.sql'))
        .sort();
      
      const executedMigrations = await this.getExecutedMigrations();
      const pendingMigrations = migrationFiles.filter(file => !executedMigrations.includes(file));
      
      if (pendingMigrations.length === 0) {
        console.log('✅ No pending migrations found');
        return;
      }
      
      console.log(`📋 Found ${pendingMigrations.length} pending migrations`);
      
      for (const migration of pendingMigrations) {
        await this.executeMigration(migration);
      }
      
      console.log('🎉 All migrations completed successfully');
      
    } catch (error) {
      console.error('❌ Migration failed:', error.message);
      process.exit(1);
    } finally {
      await this.pool.end();
    }
  }

  async showStatus() {
    try {
      await this.ensureMigrationsTable();
      
      const migrationsDir = path.join(__dirname, '../migrations');
      const migrationFiles = fs.readdirSync(migrationsDir)
        .filter(file => file.endsWith('.sql'))
        .sort();
      
      const executedMigrations = await this.getExecutedMigrations();
      
      console.log('\n📊 Migration Status:');
      console.log('==================');
      
      migrationFiles.forEach(file => {
        const status = executedMigrations.includes(file) ? '✅ Executed' : '⏳ Pending';
        console.log(`${status} - ${file}`);
      });
      
      console.log(`\nTotal: ${migrationFiles.length} migrations`);
      console.log(`Executed: ${executedMigrations.length}`);
      console.log(`Pending: ${migrationFiles.length - executedMigrations.length}`);
      
    } catch (error) {
      console.error('❌ Failed to get migration status:', error.message);
      process.exit(1);
    } finally {
      await this.pool.end();
    }
  }
}

// CLI Interface
const command = process.argv[2];
const runner = new MigrationRunner();

switch (command) {
  case 'run':
    runner.runMigrations();
    break;
  case 'status':
    runner.showStatus();
    break;
  default:
    console.log('Usage: node migrate.js [run|status]');
    console.log('  run    - Execute pending migrations');
    console.log('  status - Show migration status');
    process.exit(1);
}
