# Partner API Database Migrations

This document describes the database migrations for the Partner API architecture implementation, which includes both 360Dialog and Meta WhatsApp Business API Partner integrations.

## Migration Files

### 007-partner-configurations.sql
**Purpose**: Creates the platform-wide partner configurations table

**Tables Created**:
- `partner_configurations` - Stores Tech Provider credentials and settings

**Key Features**:
- Supports multiple providers (360dialog, meta, twilio)
- Encrypted credential storage
- Webhook configuration
- Public profile for onboarding flows

### 008-360dialog-partner-tables.sql
**Purpose**: Creates tables for 360Dialog Partner API client and channel management

**Tables Created**:
- `dialog_360_clients` - Company client accounts managed through 360Dialog Partner API
- `dialog_360_channels` - WhatsApp channels/phone numbers under client accounts

**Key Features**:
- Client account management
- Channel provisioning and status tracking
- Quality rating and messaging limits
- Proper foreign key relationships

### 009-meta-whatsapp-partner-tables.sql
**Purpose**: Creates tables for Meta WhatsApp Business API Partner management

**Tables Created**:
- `meta_whatsapp_clients` - Company business accounts managed through Meta Tech Provider API
- `meta_whatsapp_phone_numbers` - WhatsApp phone numbers under Meta business accounts

**Key Features**:
- Business account management
- Phone number provisioning and verification
- Access token management
- Quality rating and messaging limits

## Running Migrations

### Automatic Migration (Recommended)
The migrations will be automatically executed when the application starts if they haven't been run yet.

### Manual Migration
You can also run the migrations manually using the provided script:

```bash
# Run all Partner API migrations
node scripts/run-partner-api-migrations.js up

# Rollback all Partner API migrations
node scripts/run-partner-api-migrations.js down
```

### Individual Migration Files
You can also run individual migration files using the standard migration system:

```bash
# Using the existing migration system
npm run migrate
```

## Database Schema Overview

### Relationships
```
companies (existing)
├── dialog_360_clients
│   └── dialog_360_channels
└── meta_whatsapp_clients
    └── meta_whatsapp_phone_numbers

partner_configurations (platform-wide, no company relationship)
```

### Key Indexes
All tables include optimized indexes for:
- Primary keys (automatic)
- Foreign key relationships
- Status fields for filtering
- Provider-specific identifiers

## Rollback Strategy

### Automatic Rollback
Use the migration script for safe rollback:
```bash
node scripts/run-partner-api-migrations.js down
```

### Manual Rollback
If needed, you can manually rollback by running the SQL statements in reverse order:

```sql
-- Rollback 009 (Meta WhatsApp tables)
DROP TABLE IF EXISTS meta_whatsapp_phone_numbers CASCADE;
DROP TABLE IF EXISTS meta_whatsapp_clients CASCADE;

-- Rollback 008 (360Dialog tables)  
DROP TABLE IF EXISTS dialog_360_channels CASCADE;
DROP TABLE IF EXISTS dialog_360_clients CASCADE;

-- Rollback 007 (Partner configurations)
DROP TABLE IF EXISTS partner_configurations CASCADE;
```

## Data Migration Considerations

### Existing Data
These migrations create new tables and do not modify existing data. However, you may need to:

1. **Migrate existing WhatsApp connections**: Update existing `channel_connections` to reference the new Partner API tables
2. **Configure Partner credentials**: Set up initial partner configurations through the admin interface
3. **Update webhook URLs**: Configure partner-level webhooks for proper event handling

### Production Deployment

1. **Backup Database**: Always backup your database before running migrations
2. **Test in Staging**: Run migrations in a staging environment first
3. **Monitor Performance**: The migrations include proper indexes but monitor query performance
4. **Verify Data Integrity**: Check that all foreign key relationships are properly established

## Troubleshooting

### Common Issues

**Migration Already Exists Error**:
- The migrations use conditional checks (`IF NOT EXISTS`) to prevent conflicts
- Safe to re-run if needed

**Foreign Key Constraint Errors**:
- Ensure the `companies` table exists and has the expected structure
- Check that company IDs referenced in seed data are valid

**Permission Errors**:
- Ensure the database user has CREATE TABLE and CREATE INDEX permissions
- Check that the database connection string is correct

### Verification Queries

After running migrations, verify the tables were created correctly:

```sql
-- Check all Partner API tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN (
  'partner_configurations',
  'dialog_360_clients', 
  'dialog_360_channels',
  'meta_whatsapp_clients',
  'meta_whatsapp_phone_numbers'
);

-- Check indexes were created
SELECT indexname, tablename 
FROM pg_indexes 
WHERE tablename LIKE '%360%' OR tablename LIKE '%meta_whatsapp%' OR tablename = 'partner_configurations';

-- Check foreign key constraints
SELECT conname, conrelid::regclass, confrelid::regclass
FROM pg_constraint 
WHERE contype = 'f' 
AND (conrelid::regclass::text LIKE '%360%' OR conrelid::regclass::text LIKE '%meta_whatsapp%');
```

## Support

If you encounter issues with these migrations:

1. Check the application logs for detailed error messages
2. Verify database connectivity and permissions
3. Ensure all prerequisite tables (like `companies`) exist
4. Review the migration files for any environment-specific adjustments needed

For additional support, refer to the main application documentation or contact the development team.
