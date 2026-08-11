-- MySQL for the POS application.
-- This is the canonical MySQL schema used by the app, with compatibility aliases

CREATE DATABASE IF NOT EXISTS `pos294`;
USE `pos294`;

DROP TABLE IF EXISTS product_audit;
DROP TABLE IF EXISTS inventory_audit;
DROP TABLE IF EXISTS bill_audit;
DROP TABLE IF EXISTS app_lifecycle_logs;
DROP TABLE IF EXISTS bill_holds;
DROP TABLE IF EXISTS bulk_batches;
DROP TABLE IF EXISTS app_settings;
DROP TABLE IF EXISTS inventory_settings;
DROP TABLE IF EXISTS settings;
DROP TABLE IF EXISTS bills;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS product_embeddings;

CREATE TABLE products (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(255) NOT NULL DEFAULT 'UNCATEGORIZED',
    sku VARCHAR(255) NOT NULL UNIQUE,
    pricing_type VARCHAR(50) NOT NULL,
    rate INT NOT NULL DEFAULT 0,
    inv_track_type VARCHAR(50) DEFAULT 'none',
    inv_current_qty DECIMAL(12,3) DEFAULT 0.000,
    inv_current_weight DECIMAL(12,3) DEFAULT 0.000,
    inv_unit VARCHAR(50) DEFAULT 'piece',
    inv_min_qty DECIMAL(12,3) DEFAULT 0.000,
    inv_min_weight DECIMAL(12,3) DEFAULT 0.000,
    name_ta VARCHAR(255) NOT NULL DEFAULT '',
    brand_name VARCHAR(255) NOT NULL DEFAULT '',
    retail_price_paise INT NOT NULL DEFAULT 0,
    barcode VARCHAR(255) NULL,
    wholesale_price_paise INT NULL,
    wholesale_min_qty DECIMAL(12,3) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE product_embeddings (
    embedding_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id VARCHAR(255) NOT NULL, -- plain reference, no FK
    image_url VARCHAR(255) NOT NULL,
    embedding JSON NOT NULL, 
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bills (
    bill_id VARCHAR(255) PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    payment_mode VARCHAR(50) NOT NULL DEFAULT 'CASH',
    discount_mode VARCHAR(50) NOT NULL DEFAULT 'PERCENT',
    discount_value DOUBLE NOT NULL DEFAULT 0,
    item_count INT NOT NULL DEFAULT 0,
    subtotal_paise INT NOT NULL DEFAULT 0,
    discount_paise INT NOT NULL DEFAULT 0,
    grand_total_paise INT NOT NULL DEFAULT 0,
    bill_data JSON NOT NULL
);

CREATE TABLE app_lifecycle_logs (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    session_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    event_source VARCHAR(50) NOT NULL DEFAULT 'APP',
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE bill_audit (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    bill_id VARCHAR(255) NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    action_source VARCHAR(50) NOT NULL DEFAULT 'BILLING_UI',
    action_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    previous_payment_mode VARCHAR(50) NOT NULL,
    previous_discount_mode VARCHAR(50) NOT NULL,
    previous_discount_value DOUBLE NOT NULL,
    previous_item_count INT NOT NULL,
    previous_subtotal_paise INT NOT NULL,
    previous_discount_paise INT NOT NULL,
    previous_grand_total_paise INT NOT NULL,
    previous_items_json JSON NOT NULL,
    new_payment_mode VARCHAR(50),
    new_discount_mode VARCHAR(50),
    new_discount_value DOUBLE,
    new_item_count INT,
    new_subtotal_paise INT,
    new_discount_paise INT,
    new_grand_total_paise INT,
    new_items_json JSON
);

CREATE TABLE bulk_batches (
    batch_id VARCHAR(255) PRIMARY KEY,
    operation_type VARCHAR(50) NOT NULL,
    file_name VARCHAR(255),
    started_at TIMESTAMP NULL,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    row_count INT NOT NULL DEFAULT 0,
    processed_count INT NOT NULL DEFAULT 0,
    inserted_count INT NOT NULL DEFAULT 0,
    updated_count INT NOT NULL DEFAULT 0,
    success_count INT NOT NULL DEFAULT 0,
    failed_count INT NOT NULL DEFAULT 0,
    skipped_count INT NOT NULL DEFAULT 0,
    items_json TEXT NOT NULL,
    reverted_at TIMESTAMP NULL,
    reverted INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE bill_holds (
    hold_id VARCHAR(255) PRIMARY KEY,
    bill_id VARCHAR(255) NOT NULL,
    bill_data JSON NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE inventory_audit (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id VARCHAR(255) NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    qty_delta DECIMAL(12,3) NOT NULL DEFAULT 0.000,
    weight_delta DECIMAL(12,3) NOT NULL DEFAULT 0.000,
    prev_qty DECIMAL(12,3) NOT NULL DEFAULT 0.000,
    new_qty DECIMAL(12,3) NOT NULL DEFAULT 0.000,
    prev_weight DECIMAL(12,3) NOT NULL DEFAULT 0.000,
    new_weight DECIMAL(12,3) NOT NULL DEFAULT 0.000,
    bill_id VARCHAR(255),
    reference_id VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_audit (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    item_id VARCHAR(255) NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    previous_name VARCHAR(255),
    previous_category VARCHAR(255),
    previous_sku VARCHAR(255),
    previous_pricing_type VARCHAR(50),
    previous_rate INT,
    new_name VARCHAR(255),
    new_category VARCHAR(255),
    new_sku VARCHAR(255),
    new_pricing_type VARCHAR(50),
    new_rate INT,
    action_source VARCHAR(50) NOT NULL DEFAULT 'ITEMS_UI',
    action_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    previous_brand_name VARCHAR(255),
    previous_retail_price_paise INT,
    previous_wholesale_price_paise INT,
    previous_wholesale_min_qty DECIMAL(12,3),
    new_brand_name VARCHAR(255),
    new_retail_price_paise INT,
    new_wholesale_price_paise INT,
    new_wholesale_min_qty DECIMAL(12,3),

    -- Barcode changes
    previous_barcode VARCHAR(255),
    new_barcode VARCHAR(255)
);


CREATE TABLE settings (
    id VARCHAR(255) PRIMARY KEY,
    type ENUM('text', 'number', 'boolean', 'json') NOT NULL,
    value TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE app_settings (
    `key` VARCHAR(255) NOT NULL,
    `value` TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`key`)
);

CREATE TABLE inventory_settings (
    id TINYINT UNSIGNED PRIMARY KEY DEFAULT 1,
    inv_control_enabled TINYINT(1) NOT NULL DEFAULT 0,
    inv_low_stock_qty DECIMAL(12,3) NOT NULL DEFAULT 10.000,
    inv_low_stock_weight DECIMAL(12,3) NOT NULL DEFAULT 5.000,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO inventory_settings (id, inv_control_enabled, inv_low_stock_qty, inv_low_stock_weight)
VALUES (1, 0, 10.000, 5.000)
ON DUPLICATE KEY UPDATE
    inv_control_enabled = VALUES(inv_control_enabled),
    inv_low_stock_qty = VALUES(inv_low_stock_qty),
    inv_low_stock_weight = VALUES(inv_low_stock_weight);

-- -----------------------------------------------------------------------------
-- Application database user (read/write on app tables only, no audit tables)
-- Replace the password before using in non-local environments.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'pos_app_user'@'%' IDENTIFIED BY 'change_me_strong_password';
ALTER USER 'pos_app_user'@'%' IDENTIFIED BY 'change_me_strong_password';

SET @db_name = 'pos294';

SET @grant_products = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`products` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_products; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_bills = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`bills` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_bills; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_bill_holds = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`bill_holds` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_bill_holds; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_bulk_batches = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`bulk_batches` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_bulk_batches; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_settings = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`settings` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_settings; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_app_settings = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`app_settings` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_app_settings; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_inventory_settings = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`inventory_settings` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_inventory_settings; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_lifecycle = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`app_lifecycle_logs` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_lifecycle; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Optional grants for compatibility aliases used by older scripts.
SET @grant_held_bills = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`held_bills` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_held_bills; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_bulk_import_batch = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.`bulk_import_batch` TO ''pos_app_user''@''%'''
);
PREPARE stmt FROM @grant_bulk_import_batch; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- Analytics read-only user (read on analytics/reporting tables)
-- Replace the password before using in non-local environments.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'pos_analytics_user'@'%' IDENTIFIED BY 'change_me_analytics_password';
ALTER USER 'pos_analytics_user'@'%' IDENTIFIED BY 'change_me_analytics_password';

SET @grant_analytics_products = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`products` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_products; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_analytics_bills = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`bills` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_bills; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_analytics_bill_holds = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`bill_holds` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_bill_holds; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_analytics_bulk_batches = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`bulk_batches` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_bulk_batches; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_analytics_lifecycle = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`app_lifecycle_logs` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_lifecycle; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_analytics_bill_audit = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`bill_audit` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_bill_audit; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_analytics_inventory_audit = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`inventory_audit` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_inventory_audit; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_analytics_product_audit = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`product_audit` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_product_audit; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Optional grants for compatibility aliases used by older scripts.
SET @grant_analytics_held_bills = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`held_bills` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_held_bills; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_analytics_bulk_import_batch = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`bulk_import_batch` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_bulk_import_batch; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @grant_analytics_lifecycle_legacy = CONCAT(
  'GRANT SELECT ON `', @db_name, '`.`app_lifecycle_logs_legacy` TO ''pos_analytics_user''@''%'''
);
PREPARE stmt FROM @grant_analytics_lifecycle_legacy; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- Admin user (read/write on all tables)
-- Replace the password before using in non-local environments.
-- -----------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'pos_admin_user'@'%' IDENTIFIED BY 'change_me_admin_password';
ALTER USER 'pos_admin_user'@'%' IDENTIFIED BY 'change_me_admin_password';

SET @grant_admin_all_tables = CONCAT(
  'GRANT SELECT, INSERT, UPDATE, DELETE ON `', @db_name, '`.* TO ''pos_admin_user''@''%'''
);
PREPARE stmt FROM @grant_admin_all_tables; EXECUTE stmt; DEALLOCATE PREPARE stmt;

FLUSH PRIVILEGES;
