SET @col_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'departments'
    AND COLUMN_NAME = 'DepartmentHeadUserID'
);

SET @sql := IF(
  @col_exists = 0,
  'ALTER TABLE departments ADD COLUMN DepartmentHeadUserID INT NULL AFTER DepartmentDeanID',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'departments'
    AND INDEX_NAME = 'uq_departments_department_head_userid'
);

SET @sql := IF(
  @idx_exists = 0,
  'ALTER TABLE departments ADD UNIQUE KEY uq_departments_department_head_userid (DepartmentHeadUserID)',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @fk_exists := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND TABLE_NAME = 'departments'
    AND CONSTRAINT_NAME = 'fk_departments_department_head_user'
    AND CONSTRAINT_TYPE = 'FOREIGN KEY'
);

SET @sql := IF(
  @fk_exists = 0,
  'ALTER TABLE departments ADD CONSTRAINT fk_departments_department_head_user FOREIGN KEY (DepartmentHeadUserID) REFERENCES useraccounts(UserID) ON DELETE SET NULL ON UPDATE CASCADE',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
